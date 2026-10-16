package com.harmonymall.controller;

import com.harmonymall.common.Result;
import com.harmonymall.dto.LoginRequest;
import com.harmonymall.dto.RegisterRequest;
import com.harmonymall.entity.User;
import com.harmonymall.security.JwtUtil;
import com.harmonymall.service.UserService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 认证：登录 / 注册 / 验证码
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Autowired
    private UserService userService;

    @Autowired
    private JwtUtil jwtUtil;

    @PostMapping("/login")
    public Result<Map<String, Object>> login(@Valid @RequestBody LoginRequest request) {
        User user = userService.login(request.getUsername(), request.getPassword());
        String token = jwtUtil.createToken(user.getId(), user.getUsername());
        user.setPassword(null);
        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("user", user);
        return Result.ok(data);
    }

    @PostMapping("/register")
    public Result<Void> register(@Valid @RequestBody RegisterRequest request) {
        userService.register(request);
        return Result.ok();
    }

    @PostMapping("/sms/code")
    public Result<String> smsCode(@RequestParam String phone) {
        // 学习项目不接入真实短信服务，直接返回 6 位验证码便于联调
        String code = String.valueOf((int) ((Math.random() * 9 + 1) * 100000));
        return Result.ok(code);
    }
}
