package com.harmonymall.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * 发表评价请求
 */
public class ReviewRequest {

    /**
     * 订单明细 ID：从订单详情进入评价时必填，
     * 服务端据此校验「这单确实是本人下的、且已完成、且未评价过」
     */
    private Long orderItemId;

    @NotNull(message = "skuId 不能为空")
    private Long skuId;

    @NotNull(message = "评分不能为空")
    @Min(value = 1, message = "评分最低 1 星")
    @Max(value = 5, message = "评分最高 5 星")
    private Integer rating;

    @NotNull(message = "评价内容不能为空")
    private String content;

    public Long getOrderItemId() {
        return orderItemId;
    }

    public void setOrderItemId(Long orderItemId) {
        this.orderItemId = orderItemId;
    }

    public Long getSkuId() {
        return skuId;
    }

    public void setSkuId(Long skuId) {
        this.skuId = skuId;
    }

    public Integer getRating() {
        return rating;
    }

    public void setRating(Integer rating) {
        this.rating = rating;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }
}
