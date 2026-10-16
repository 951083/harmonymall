package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_cart_item
 */
@Data
@TableName("t_cart_item")
public class CartItem {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 用户 ID */
    private Long userId;

    /** SKU ID */
    private Long skuId;

    /** 数量 */
    private Integer quantity;

    /** 是否选中 0/1 */
    private Integer selected;

    /** 逻辑删除 */
    private Integer deleted;

    /**  */
    private LocalDateTime createdAt;

    /**  */
    private LocalDateTime updatedAt;

}