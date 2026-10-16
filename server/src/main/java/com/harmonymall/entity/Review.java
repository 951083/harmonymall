package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_review
 */
@Data
@TableName("t_review")
public class Review {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 订单明细 ID */
    private Long orderItemId;

    /** 用户 ID */
    private Long userId;

    /** SKU ID */
    private Long skuId;

    /** 评分 1-5 */
    private Integer rating;

    /** 评价内容 */
    private String content;

    /** 图片 JSON */
    private String images;

    /**  */
    private LocalDateTime createdAt;

}