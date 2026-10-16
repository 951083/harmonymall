package com.harmonymall.dto;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * 优惠券视图对象：
 * - 领券中心：来自 t_coupon 模板，附带「当前用户是否已领取/已使用」
 * - 我的优惠券：来自 t_user_coupon，附带可用状态
 */
@Data
public class CouponVO {

    /** 我的券 ID（t_user_coupon.id），领券中心未领取时为 null */
    private Long id;

    /** 券模板 ID */
    private Long couponId;

    private String name;

    /** 面额（分） */
    private Integer amount;

    /** 门槛（分），0 无门槛 */
    private Integer threshold;

    /** 领取后有效天数 */
    private Integer validDays;

    private String description;

    /** 可领数量剩余，-1 表示不限量 */
    private Integer remain;

    /** 当前用户是否已领取（领券中心用） */
    private Boolean claimed;

    /** 过期时间（我的券用） */
    private LocalDateTime expireTime;

    /**
     * 0 未使用 1 已使用 2 已过期
     * （领券中心未领取时为 null）
     */
    private Integer status;
}
