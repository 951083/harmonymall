package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_coupon 优惠券模板（领券中心的「券」本身）
 */
@Data
@TableName("t_coupon")
public class Coupon {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 券名称 */
    private String name;

    /** 面额（分） */
    private Integer amount;

    /** 使用门槛（分），0 表示无门槛 */
    private Integer threshold;

    /** 发行总量，0 表示不限量 */
    private Integer total;

    /** 已领取数量 */
    private Integer claimed;

    /** 领取后有效天数 */
    private Integer validDays;

    /** 使用说明 */
    private String description;

    /** 1 上架 0 下架 */
    private Integer enabled;

    /** 排序（越小越靠前） */
    private Integer sort;

    private LocalDateTime createdAt;
}
