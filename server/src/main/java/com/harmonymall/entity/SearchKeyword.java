package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_search_keyword 搜索热词统计（用户每次搜索累加计数，用于「热门搜索」）
 */
@Data
@TableName("t_search_keyword")
public class SearchKeyword {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 关键词 */
    private String keyword;

    /** 搜索次数 */
    private Integer count;

    private LocalDateTime updatedAt;
}
