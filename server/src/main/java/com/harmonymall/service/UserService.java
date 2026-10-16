package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.dto.RegisterRequest;
import com.harmonymall.entity.User;
import com.harmonymall.mapper.UserMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * 用户服务：登录 / 注册 / 查询
 */
@Service
public class UserService {

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    public User login(String username, String password) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username));
        if (user == null || !passwordEncoder.matches(password, user.getPassword())) {
            throw new BizException("账号或密码错误");
        }
        if (Integer.valueOf(0).equals(user.getStatus())) {
            throw new BizException("账号已被禁用");
        }
        return user;
    }

    public void register(RegisterRequest request) {
        Long count = userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, request.getUsername()));
        if (count != null && count > 0) {
            throw new BizException("账号已存在");
        }
        User user = new User();
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setPhone(request.getPhone());
        user.setNickname(StringUtils.hasText(request.getUsername()) ? "用户" + request.getUsername() : "新用户");
        user.setStatus(1);
        userMapper.insert(user);
    }

    public User getById(Long id) {
        User user = userMapper.selectById(id);
        if (user == null) {
            throw new BizException("用户不存在");
        }
        return user;
    }
}
