package com.harmonymall.common;

import lombok.Getter;

/**
 * 业务异常，由全局异常处理器转换为统一响应
 */
@Getter
public class BizException extends RuntimeException {

    private final Integer code;

    public BizException(String message) {
        super(message);
        this.code = ResultCode.SYSTEM_ERROR;
    }

    public BizException(Integer code, String message) {
        super(message);
        this.code = code;
    }
}
