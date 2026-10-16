package com.harmonymall.security;

import com.harmonymall.common.BizException;
import com.harmonymall.common.ResultCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * JWT 拦截器：解析 token 写入 userId；受保护路径未登录直接 40100
 */
public class JwtInterceptor implements HandlerInterceptor {

    private final JwtUtil jwtUtil;

    public JwtInterceptor(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String uri = request.getRequestURI().substring(request.getContextPath().length());
        // 接口统一带 /api 前缀（由 Controller 的 @RequestMapping 声明），这里剥掉以便统一判断
        if (uri.startsWith("/api")) {
            uri = uri.substring(4);
        }
        String token = request.getHeader("Authorization");
        Long userId = jwtUtil.parseUserId(token);
        if (userId != null) {
            request.setAttribute("userId", userId);
        }

        boolean needAuth = uri.startsWith("/cart")
                || uri.startsWith("/orders")
                || uri.startsWith("/address")
                || uri.startsWith("/user")
                || ("POST".equalsIgnoreCase(request.getMethod()) && uri.startsWith("/reviews"));

        if (needAuth && userId == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "请先登录");
        }
        return true;
    }
}
