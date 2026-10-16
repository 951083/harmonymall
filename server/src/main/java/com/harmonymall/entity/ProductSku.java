package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_product_sku
 */
@Data
@TableName("t_product_sku")
public class ProductSku {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** SPU ID */
    private Long productId;

    /** 规格 JSON */
    private String specs;

    /** 售价（分） */
    private Integer price;

    /** 库存 */
    private Integer stock;

    /** SKU 图 */
    private String image;

    /** 逻辑删除 */
    private Integer deleted;

}