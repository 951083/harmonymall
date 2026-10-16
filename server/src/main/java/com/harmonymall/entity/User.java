package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_user
 */
@Data
@TableName("t_user")
public class User {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 登录账号 */
    private String username;

    /** BCrypt 密码 */
    private String password;

    /** 手机号 */
    private String phone;

    /** 昵称 */
    private String nickname;

    /** 头像 */
    private String avatar;

    /** 1 正常 0 禁用 */
    private Integer status;

    /** 逻辑删除 */
    private Integer deleted;

    /**  */
    private LocalDateTime createdAt;

    /**  */
    private LocalDateTime updatedAt;

}