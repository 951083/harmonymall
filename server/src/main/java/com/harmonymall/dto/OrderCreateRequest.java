package com.harmonymall.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * 创建订单请求
 */
public class OrderCreateRequest {

    @NotEmpty(message = "请选择要结算的商品")
    private List<Long> cartIds;

    @NotNull(message = "请选择收货地址")
    private Long addressId;

    /** 使用的优惠券 ID（t_user_coupon.id），不使用时为 null */
    private Long couponId;

    /**
     * 客户端幂等令牌：端上每次进入确认订单页生成一个随机串，
     * 服务端用它做重复提交拦截（同一令牌只允许成功下单一次）
     */
    private String clientToken;

    private String remark;

    public List<Long> getCartIds() {
        return cartIds;
    }

    public void setCartIds(List<Long> cartIds) {
        this.cartIds = cartIds;
    }

    public Long getAddressId() {
        return addressId;
    }

    public void setAddressId(Long addressId) {
        this.addressId = addressId;
    }

    public Long getCouponId() {
        return couponId;
    }

    public void setCouponId(Long couponId) {
        this.couponId = couponId;
    }

    public String getClientToken() {
        return clientToken;
    }

    public void setClientToken(String clientToken) {
        this.clientToken = clientToken;
    }

    public String getRemark() {
        return remark;
    }

    public void setRemark(String remark) {
        this.remark = remark;
    }
}
