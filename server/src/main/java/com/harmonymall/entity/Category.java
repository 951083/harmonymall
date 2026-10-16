package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.util.List;

/**
 * t_category
 */
@Data
@TableName("t_category")
public class Category {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 上级分类，0 为一级 */
    private Long parentId;

    /** 分类名称 */
    private String name;

    /** 层级 1/2 */
    private Integer level;

    /** 图标 */
    private String icon;

    /** 排序 */
    private Integer sort;

    /** 逻辑删除 */
    private Integer deleted;

    /** 子分类（非数据库字段） */
    @TableField(exist = false)
    private List<Category> children;
}
