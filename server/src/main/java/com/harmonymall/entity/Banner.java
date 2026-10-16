package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_banner
 */
@Data
@TableName("t_banner")
public class Banner {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 轮播图 */
    private String image;

    /** 跳转类型 */
    private String linkType;

    /** 跳转目标 */
    private String linkValue;

    /** 排序 */
    private Integer sort;

}