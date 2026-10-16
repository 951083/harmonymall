package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_product
 */
@Data
@TableName("t_product")
public class Product {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 二级分类 ID */
    private Long categoryId;

    /** 商品名称 */
    private String name;

    /** 副标题 */
    private String subtitle;

    /** 主图 */
    private String mainImage;

    /** 最低价（分） */
    private Integer price;

    /** 原价（分） */
    private Integer originalPrice;

    /** 销量 */
    private Integer sales;

    /** 商品详情富文本 */
    private String detail;

    /** 1 上架 0 下架 */
    private Integer status;

    /** 逻辑删除 */
    private Integer deleted;

    /**  */
    private LocalDateTime createdAt;

    /**  */
    private LocalDateTime updatedAt;

}