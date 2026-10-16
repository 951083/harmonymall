package com.harmonymall.common;

/**
 * 业务状态码
 */
public final class ResultCode {

    public static final int SUCCESS = 0;
    public static final int PARAM_ERROR = 20000;
    public static final int UNAUTHORIZED = 40100;
    public static final int NOT_FOUND = 40400;
    public static final int METHOD_NOT_ALLOWED = 40500;
    public static final int SYSTEM_ERROR = 50000;

    private ResultCode() {
    }
}
