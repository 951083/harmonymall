package com.harmonymall.dto;

import lombok.Data;

/**
 * 订单操作附加参数：取消订单 / 申请退款时携带的原因文本。
 * 端上不填时允许为空，后端会落默认原因
 */
@Data
public class OrderActionRequest {

    /** 原因文本（如「不想要了」「信息填写错误」） */
    private String reason;
}
