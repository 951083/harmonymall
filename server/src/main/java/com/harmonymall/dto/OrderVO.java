package com.harmonymall.dto;

import com.harmonymall.entity.OrderItem;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 订单详情视图对象（含明细）
 */
@Data
public class OrderVO {

    private Long id;
    private String orderNo;
    private Long userId;
    private Integer totalAmount;

    /** 优惠金额（分） */
    private Integer discountAmount;

    private Integer payAmount;
    private String addressSnapshot;
    private String remark;
    private Integer status;
    private LocalDateTime payTime;
    private LocalDateTime shipTime;
    private LocalDateTime finishTime;
    private LocalDateTime createdAt;

    /** 取消原因（status=4 展示） */
    private String cancelReason;

    /** 退款原因（status=5/6 展示） */
    private String refundReason;

    /** 退款完成时间（status=6 展示） */
    private LocalDateTime refundTime;

    /**
     * 明细；每条明细带 reviewed 标记（是否已评价），
     * 端上据此决定是否展示「评价」入口
     */
    private List<OrderItem> items;
}
