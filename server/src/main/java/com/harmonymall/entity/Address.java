package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_address
 */
@Data
@TableName("t_address")
public class Address {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 用户 ID */
    private Long userId;

    /** 收货人 */
    private String receiver;

    /** 手机号 */
    private String phone;

    /** 省 */
    private String province;

    /** 市 */
    private String city;

    /** 区/县 */
    private String district;

    /** 详细地址 */
    private String detail;

    /** 是否默认 0/1 */
    private Integer isDefault;

    /** 逻辑删除 */
    private Integer deleted;

    /**  */
    private LocalDateTime createdAt;

    /**  */
    private LocalDateTime updatedAt;

}