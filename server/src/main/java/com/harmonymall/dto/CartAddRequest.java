package com.harmonymall.dto;

import jakarta.validation.constraints.NotNull;

/**
 * 加入购物车请求
 */
public class CartAddRequest {

    @NotNull(message = "skuId 不能为空")
    private Long skuId;

    @NotNull(message = "数量不能为空")
    private Integer quantity;

    public Long getSkuId() {
        return skuId;
    }

    public void setSkuId(Long skuId) {
        this.skuId = skuId;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }
}
