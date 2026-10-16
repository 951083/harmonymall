package com.harmonymall.dto;

/**
 * 修改购物车请求（数量 / 选中态）
 */
public class CartUpdateRequest {

    private Integer quantity;
    private Integer selected;

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public Integer getSelected() {
        return selected;
    }

    public void setSelected(Integer selected) {
        this.selected = selected;
    }
}
