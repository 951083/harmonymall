package com.harmonymall.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.harmonymall.entity.Order;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

import java.time.LocalDateTime;

/**
 * 订单 Mapper。
 *
 * 所有状态流转统一采用「条件更新」：把期望的旧状态写进 WHERE 子句，
 * 用返回的受影响行数判断这次流转是否真正生效。
 * 并发场景（用户重复点击、定时任务与用户操作撞车、多实例部署）下
 * 只有第一个请求能更新成功，其余返回 0 行，从根上避免
 * 「状态被覆盖 / 库存被重复回滚 / 一笔订单退两次款」这类问题。
 */
@Mapper
public interface OrderMapper extends BaseMapper<Order> {

    /** 支付成功：待付款(0) → 待发货(1)，记录支付时间 */
    @Update("UPDATE t_order SET status = 1, pay_time = #{payTime} " +
            "WHERE id = #{id} AND user_id = #{userId} AND status = 0 AND deleted = 0")
    int markPaid(@Param("id") Long id, @Param("userId") Long userId,
                 @Param("payTime") LocalDateTime payTime);

    /** 取消订单：待付款(0) → 已取消(4)，记录取消原因（用户手动取消与系统超时关单共用） */
    @Update("UPDATE t_order SET status = 4, cancel_reason = #{reason} " +
            "WHERE id = #{id} AND user_id = #{userId} AND status = 0 AND deleted = 0")
    int markCancelled(@Param("id") Long id, @Param("userId") Long userId,
                      @Param("reason") String reason);

    /** 发货：待发货(1) → 待收货(2) */
    @Update("UPDATE t_order SET status = 2, ship_time = #{shipTime} " +
            "WHERE id = #{id} AND status = 1 AND deleted = 0")
    int markShipped(@Param("id") Long id, @Param("shipTime") LocalDateTime shipTime);

    /** 确认收货：待收货(2) → 已完成(3) */
    @Update("UPDATE t_order SET status = 3, finish_time = #{finishTime} " +
            "WHERE id = #{id} AND status = 2 AND deleted = 0")
    int markConfirmed(@Param("id") Long id, @Param("finishTime") LocalDateTime finishTime);

    /**
     * 自动确认收货（批量）：发货超过 deadline 仍未手动确认的订单直接完成。
     * 确认收货无库存 / 优惠券等副作用，可用一条 SQL 批量推进
     */
    @Update("UPDATE t_order SET status = 3, finish_time = NOW() " +
            "WHERE status = 2 AND ship_time < #{deadline} AND deleted = 0")
    int autoConfirm(@Param("deadline") LocalDateTime deadline);

    /** 申请退款：待发货(1) / 待收货(2) → 退款中(5)，记录退款原因 */
    @Update("UPDATE t_order SET status = 5, refund_reason = #{reason} " +
            "WHERE id = #{id} AND user_id = #{userId} AND status IN (1, 2) AND deleted = 0")
    int markRefunding(@Param("id") Long id, @Param("userId") Long userId,
                      @Param("reason") String reason);

    /** 退款完成：退款中(5) → 已退款(6)。由定时任务模拟商家审核通过后调用 */
    @Update("UPDATE t_order SET status = 6, refund_time = NOW() " +
            "WHERE id = #{id} AND status = 5 AND deleted = 0")
    int markRefunded(@Param("id") Long id);
}
