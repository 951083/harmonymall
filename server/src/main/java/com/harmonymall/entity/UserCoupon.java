package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_user_coupon 用户已领取的优惠券
 */
@Data
@TableName("t_user_coupon")
public class UserCoupon {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 用户 ID */
    private Long userId;

    /** 来源券模板 ID（t_coupon.id，NULL 表示系统直接发放） */
    private Long couponId;

    /** 券名称 */
    private String name;

    /** 面额（分） */
    private Integer amount;

    /** 使用门槛（分） */
    private Integer threshold;

    /** 1 未使用 0 已使用 */
    private Integer status;

    /** 过期时间 */
    private LocalDateTime expireTime;

    /** 使用时间 */
    private LocalDateTime usedAt;

    /** 逻辑删除 */
    private Integer deleted;
}
