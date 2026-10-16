package com.harmonymall.dto;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * 评价视图对象：在评价实体基础上补充评价人昵称 / 头像，
 * 避免端上展示「匿名用户」或再发一次请求查用户
 */
@Data
public class ReviewVO {

    private Long id;
    private Long orderItemId;
    private Long userId;
    private Long skuId;

    /** 评价人昵称（脱敏：没设置昵称时用 用户名 首位 + ***） */
    private String nickname;

    private String avatar;

    private Integer rating;
    private String content;
    private LocalDateTime createdAt;
}
