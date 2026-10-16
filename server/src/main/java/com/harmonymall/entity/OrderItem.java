package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_order_item
 */
@Data
@TableName("t_order_item")
public class OrderItem {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 订单 ID */
    private Long orderId;

    /** SKU ID */
    private Long skuId;

    /** SPU ID */
    private Long productId;

    /** 成交价（分） */
    private Integer price;

    /** 数量 */
    private Integer quantity;

    /** 商品快照 JSON */
    private String productSnapshot;

    /**
     * 是否已评价（非数据库字段，查询订单详情时回填，
     * 用于端上决定「评价」入口是否展示）
     */
    @TableField(exist = false)
    private Boolean reviewed;

}