package com.harmonymall.common;

import lombok.Data;

import java.io.Serializable;

/**
 * 统一响应体：{@code {code, message, data}}
 * code = 0 表示成功，其余见 {@link ResultCode}
 */
@Data
public class Result<T> implements Serializable {

    private Integer code;
    private String message;
    private T data;

    private Result(Integer code, String message, T data) {
        this.code = code;
        this.message = message;
        this.data = data;
    }

    public static <T> Result<T> ok() {
        return new Result<>(ResultCode.SUCCESS, "success", null);
    }

    public static <T> Result<T> ok(T data) {
        return new Result<>(ResultCode.SUCCESS, "success", data);
    }

    public static <T> Result<T> fail(String message) {
        return new Result<>(ResultCode.SYSTEM_ERROR, message, null);
    }

    public static <T> Result<T> fail(Integer code, String message) {
        return new Result<>(code, message, null);
    }
}
