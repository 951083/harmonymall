package com.harmonymall.dto;

import lombok.Data;

/**
 * 购物车视图对象（含商品信息）
 */
@Data
public class CartVO {

    private Long id;
    private Long skuId;
    private Long productId;
    private String productName;
    private String image;
    private String specs;
    private Integer price;
    private Integer quantity;
    private Integer selected;

    /** 当前 SKU 库存：端上用于置灰「已售罄」、限制加量 */
    private Integer stock;
}
