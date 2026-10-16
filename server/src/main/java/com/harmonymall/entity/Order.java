package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_order
 */
@Data
@TableName("t_order")
public class Order {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 订单编号 */
    private String orderNo;

    /** 用户 ID */
    private Long userId;

    /** 商品总额（分） */
    private Integer totalAmount;

    /** 优惠金额（分） */
    private Integer discountAmount;

    /** 使用的优惠券 ID（t_user_coupon.id） */
    private Long couponId;

    /** 实付金额（分） */
    private Integer payAmount;

    /** 地址快照 JSON */
    private String addressSnapshot;

    /** 订单备注 */
    private String remark;

    /** 0 待付款 1 待发货 2 待收货 3 已完成 4 已取消 5 退款中 6 已退款 */
    private Integer status;

    /** 支付时间 */
    private LocalDateTime payTime;

    /** 发货时间 */
    private LocalDateTime shipTime;

    /** 完成时间 */
    private LocalDateTime finishTime;

    /** 取消原因（用户取消 / 超时未支付自动取消） */
    private String cancelReason;

    /** 退款原因 */
    private String refundReason;

    /** 退款完成时间 */
    private LocalDateTime refundTime;

    /** 逻辑删除 */
    private Integer deleted;

    /**  */
    private LocalDateTime createdAt;

    /**  */
    private LocalDateTime updatedAt;

}