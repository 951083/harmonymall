package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_footprint
 */
@Data
@TableName("t_footprint")
public class Footprint {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 用户 ID */
    private Long userId;

    /** SKU ID */
    private Long skuId;

    /** 浏览时间 */
    private LocalDateTime viewedAt;

}