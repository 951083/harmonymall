# -*- coding: utf-8 -*-
"""HarmonyMall 后端脚手架生成脚本 · 第 1 部分
生成 pom.xml、application.yml、SQL（schema + data）、启动类、common、config、security
"""
import os
import subprocess
import sys

ROOT = r"C:\Users\95108\IdeaProjects\harmonymall-server"


def w(rel, content):
    path = os.path.join(ROOT, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print("  +", rel)


def bcrypt_hash(pwd="123456"):
    try:
        import bcrypt
    except ImportError:
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "bcrypt"], check=False)
        try:
            import bcrypt
        except ImportError:
            return None
    return bcrypt.hashpw(pwd.encode("utf-8"), bcrypt.gensalt()).decode()


POM = '''<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.5.4</version>
        <relativePath/>
    </parent>

    <groupId>com.harmonymall</groupId>
    <artifactId>harmonymall-server</artifactId>
    <version>1.0.0</version>
    <name>harmonymall-server</name>
    <description>鸿蒙商城毕业设计 · 服务端</description>

    <properties>
        <java.version>17</java.version>
        <mybatis-plus.version>3.5.7</mybatis-plus.version>
        <jjwt.version>0.12.6</jjwt.version>
        <springdoc.version>2.6.0</springdoc.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>

        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
            <version>${mybatis-plus.version}</version>
        </dependency>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>${jjwt.version}</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>${jjwt.version}</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>${jjwt.version}</version>
            <scope>runtime</scope>
        </dependency>

        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
            <version>${springdoc.version}</version>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <configuration>
                    <excludes>
                        <exclude>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </exclude>
                    </excludes>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
'''

YML = '''server:
  port: 8080
  servlet:
    context-path: /api

spring:
  application:
    name: harmonymall-server
  datasource:
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql:<SECRET_794ce811>     username: root
    password: 123456
  data:
    redis:
      host: 127.0.0.1
      port: 6379
      database: 0
      timeout: 3000
  jackson:
    default-property-inclusion: non_null

mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
  global-config:
    db-config:
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0

harmonymall:
  jwt:
    # 生产环境请更换为随机长字符串，并通过环境变量注入
    secret: harmonymall-graduation-design-secret-key-2026
    expire-hours: 24

# 首次如未手动执行 SQL，可放开下面配置自动初始化库表（默认注释）
#  sql:
#    init:
#      mode: always
#      schema-locations: classpath:db/schema.sql
#      data-locations: classpath:db/data.sql
'''

SCHEMA = '''-- =============================================================
-- HarmonyMall 鸿蒙商城 · 数据库结构（MySQL 8.0 / utf8mb4）
-- 金额单位：分（INT），避免浮点误差
-- 使用方法：先执行本文件，再执行 data.sql
-- =============================================================
CREATE DATABASE IF NOT EXISTS harmonymall DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE harmonymall;

DROP TABLE IF EXISTS t_user;
CREATE TABLE t_user (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
  username   VARCHAR(50)  NOT NULL COMMENT '登录账号',
  password   VARCHAR(100) NOT NULL COMMENT 'BCrypt 密码',
  phone      VARCHAR(20)  DEFAULT NULL COMMENT '手机号',
  nickname   VARCHAR(50)  DEFAULT NULL COMMENT '昵称',
  avatar     VARCHAR(255) DEFAULT NULL COMMENT '头像',
  status     TINYINT      DEFAULT 1 COMMENT '1 正常 0 禁用',
  deleted    TINYINT      DEFAULT 0 COMMENT '逻辑删除 0/1',
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_username (username)
) COMMENT '用户表';

DROP TABLE IF EXISTS t_address;
CREATE TABLE t_address (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT       NOT NULL COMMENT '用户 ID',
  receiver   VARCHAR(50)  NOT NULL COMMENT '收货人',
  phone      VARCHAR(20)  NOT NULL COMMENT '手机号',
  province   VARCHAR(50)  DEFAULT NULL COMMENT '省',
  city       VARCHAR(50)  DEFAULT NULL COMMENT '市',
  district   VARCHAR(50)  DEFAULT NULL COMMENT '区/县',
  detail     VARCHAR(255) DEFAULT NULL COMMENT '详细地址',
  is_default TINYINT      DEFAULT 0 COMMENT '是否默认 0/1',
  deleted    TINYINT      DEFAULT 0,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) COMMENT '收货地址表';

DROP TABLE IF EXISTS t_category;
CREATE TABLE t_category (
  id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  parent_id BIGINT      DEFAULT 0 COMMENT '上级分类，0 为一级',
  name      VARCHAR(50) NOT NULL COMMENT '分类名称',
  level     TINYINT     DEFAULT 1 COMMENT '层级 1/2',
  icon      VARCHAR(255) DEFAULT NULL COMMENT '图标',
  sort      INT         DEFAULT 0 COMMENT '排序',
  deleted   TINYINT     DEFAULT 0
) COMMENT '商品分类表';

DROP TABLE IF EXISTS t_product;
CREATE TABLE t_product (
  id             BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id    BIGINT       NOT NULL COMMENT '二级分类 ID',
  name           VARCHAR(100) NOT NULL COMMENT '商品名称',
  subtitle       VARCHAR(255) DEFAULT NULL COMMENT '副标题',
  main_image     VARCHAR(255) DEFAULT NULL COMMENT '主图',
  price          INT          NOT NULL COMMENT '最低价（分）',
  original_price INT          DEFAULT NULL COMMENT '原价（分）',
  sales          INT          DEFAULT 0 COMMENT '销量',
  detail         TEXT COMMENT '商品详情富文本',
  status         TINYINT      DEFAULT 1 COMMENT '1 上架 0 下架',
  deleted        TINYINT      DEFAULT 0,
  created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_category (category_id)
) COMMENT '商品 SPU 表';

DROP TABLE IF EXISTS t_product_sku;
CREATE TABLE t_product_sku (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT       NOT NULL COMMENT 'SPU ID',
  specs      VARCHAR(255) DEFAULT NULL COMMENT '规格 JSON，如 {"颜色":"白","尺码":"M"}',
  price      INT          NOT NULL COMMENT '售价（分）',
  stock      INT          DEFAULT 0 COMMENT '库存',
  image      VARCHAR(255) DEFAULT NULL COMMENT 'SKU 图',
  deleted    TINYINT      DEFAULT 0
) COMMENT '商品 SKU 表';

DROP TABLE IF EXISTS t_cart_item;
CREATE TABLE t_cart_item (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT   NOT NULL,
  sku_id     BIGINT   NOT NULL,
  quantity   INT      DEFAULT 1 COMMENT '数量',
  selected   TINYINT  DEFAULT 1 COMMENT '是否选中 0/1',
  deleted    TINYINT  DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_user (user_id)
) COMMENT '购物车表';

DROP TABLE IF EXISTS t_order;
CREATE TABLE t_order (
  id               BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no         VARCHAR(64)  NOT NULL COMMENT '订单编号',
  user_id          BIGINT       NOT NULL,
  total_amount     INT          NOT NULL COMMENT '商品总额（分）',
  pay_amount       INT          NOT NULL COMMENT '实付金额（分）',
  address_snapshot TEXT COMMENT '地址快照 JSON',
  remark           VARCHAR(255) DEFAULT NULL COMMENT '订单备注',
  status           TINYINT      DEFAULT 0 COMMENT '0 待付款 1 待发货 2 待收货 3 已完成 4 已取消 5 退款中 6 已退款',
  pay_time         DATETIME     DEFAULT NULL,
  ship_time        DATETIME     DEFAULT NULL,
  finish_time      DATETIME     DEFAULT NULL,
  deleted          TINYINT      DEFAULT 0,
  created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_order_no (order_no),
  KEY idx_user (user_id)
) COMMENT '订单主表';

DROP TABLE IF EXISTS t_order_item;
CREATE TABLE t_order_item (
  id               BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id         BIGINT NOT NULL,
  sku_id           BIGINT NOT NULL,
  product_id       BIGINT NOT NULL,
  price            INT    NOT NULL COMMENT '成交价（分）',
  quantity         INT    NOT NULL,
  product_snapshot TEXT COMMENT '商品快照 JSON'
) COMMENT '订单明细表';

DROP TABLE IF EXISTS t_user_coupon;
CREATE TABLE t_user_coupon (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT       NOT NULL,
  name        VARCHAR(100) NOT NULL COMMENT '券名称',
  amount      INT          NOT NULL COMMENT '面额（分）',
  threshold   INT          DEFAULT 0 COMMENT '使用门槛（分）',
  status      TINYINT      DEFAULT 1 COMMENT '1 未使用 0 已使用',
  expire_time DATETIME     DEFAULT NULL,
  deleted     TINYINT      DEFAULT 0
) COMMENT '用户优惠券表';

DROP TABLE IF EXISTS t_favorite;
CREATE TABLE t_favorite (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT   NOT NULL,
  sku_id     BIGINT   NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT '收藏表';

DROP TABLE IF EXISTS t_footprint;
CREATE TABLE t_footprint (
  id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id   BIGINT   NOT NULL,
  sku_id    BIGINT   NOT NULL,
  viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT '浏览足迹表';

DROP TABLE IF EXISTS t_review;
CREATE TABLE t_review (
  id           BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_item_id BIGINT DEFAULT NULL COMMENT '订单明细 ID',
  user_id      BIGINT NOT NULL,
  sku_id       BIGINT NOT NULL,
  rating       TINYINT DEFAULT 5 COMMENT '评分 1-5',
  content      VARCHAR(1000) DEFAULT NULL COMMENT '评价内容',
  images       VARCHAR(1000) DEFAULT NULL COMMENT '图片 JSON',
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT '评价表';

DROP TABLE IF EXISTS t_banner;
CREATE TABLE t_banner (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  image      VARCHAR(255) NOT NULL COMMENT '轮播图',
  link_type  VARCHAR(20)  DEFAULT NULL COMMENT '跳转类型 product/category/none',
  link_value VARCHAR(50)  DEFAULT NULL COMMENT '跳转目标',
  sort       INT          DEFAULT 0
) COMMENT '首页轮播图表';

DROP TABLE IF EXISTS t_message;
CREATE TABLE t_message (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT       NOT NULL,
  title      VARCHAR(100) NOT NULL,
  content    VARCHAR(1000) DEFAULT NULL,
  type       VARCHAR(20)  DEFAULT 'system' COMMENT 'system/order/coupon',
  is_read    TINYINT      DEFAULT 0,
  created_at DATETIME     DEFAULT CURRENT_TIMESTAMP
) COMMENT '站内消息表';
'''

APP = '''package com.harmonymall;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class HarmonyMallApplication {

    public static void main(String[] args) {
        SpringApplication.run(HarmonyMallApplication.class, args);
        System.out.println("HarmonyMall server started: http://localhost:8080/api");
    }
}
'''

RESULT = '''package com.harmonymall.common;

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
'''

RESULT_CODE = '''package com.harmonymall.common;

/**
 * 业务状态码
 */
public final class ResultCode {

    public static final int SUCCESS = 0;
    public static final int PARAM_ERROR = 20000;
    public static final int UNAUTHORIZED = 40100;
    public static final int SYSTEM_ERROR = 50000;

    private ResultCode() {
    }
}
'''

PAGE_RESULT = '''package com.harmonymall.common;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.io.Serializable;
import java.util.List;

/**
 * 分页结果
 */
@Data
@AllArgsConstructor
public class PageResult<T> implements Serializable {

    private List<T> list;
    private Long total;
    private Long page;
    private Long size;
}
'''

BIZ_EXCEPTION = '''package com.harmonymall.common;

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
'''

GLOBAL_EXCEPTION_HANDLER = '''package com.harmonymall.common;

import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.bind.MethodArgumentNotValidException;

/**
 * 全局异常处理
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BizException.class)
    public Result<Void> handleBiz(BizException e) {
        return Result.fail(e.getCode(), e.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValid(MethodArgumentNotValidException e) {
        String message = "参数错误";
        if (e.getBindingResult().getFieldError() != null) {
            message = e.getBindingResult().getFieldError().getDefaultMessage();
        }
        return Result.fail(ResultCode.PARAM_ERROR, message);
    }

    @ExceptionHandler(Exception.class)
    public Result<Void> handleOther(Exception e) {
        log.error("system error", e);
        return Result.fail("系统繁忙，请稍后重试");
    }
}
'''

JSON_UTILS = '''package com.harmonymall.common;

import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * JSON 工具（用于订单快照等场景）
 */
public final class JsonUtils {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private JsonUtils() {
    }

    public static String toJson(Object obj) {
        try {
            return MAPPER.writeValueAsString(obj);
        } catch (Exception e) {
            return "{}";
        }
    }
}
'''

MYBATIS_PLUS_CONFIG = '''package com.harmonymall.config;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * MyBatis-Plus 配置：分页插件
 */
@Configuration
public class MyBatisPlusConfig {

    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
'''

WEB_CONFIG = '''package com.harmonymall.config;

import com.harmonymall.security.JwtInterceptor;
import com.harmonymall.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web 配置：JWT 拦截器 + 跨域
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Autowired
    private JwtUtil jwtUtil;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new JwtInterceptor(jwtUtil))
                .addPathPatterns("/**")
                .excludePathPatterns(
                        "/auth/**",
                        "/home",
                        "/banners/**",
                        "/categories/**",
                        "/products/**",
                        "/swagger-ui/**",
                        "/v3/api-docs/**"
                );
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")
                .allowedMethods("*")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}
'''

JWT_UTIL = '''package com.harmonymall.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 工具：生成与解析 token
 */
@Component
public class JwtUtil {

    @Value("${harmonymall.jwt.secret}")
    private String secret;

    @Value("${harmonymall.jwt.expire-hours:24}")
    private long expireHours;

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String createToken(Long userId, String username) {
        return Jwts.builder()
                .claim("userId", userId)
                .claim("username", username)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expireHours * 3600 * 1000))
                .signWith(key())
                .compact();
    }

    public Claims parseToken(String token) {
        if (token == null || !token.startsWith("Bearer ")) {
            return null;
        }
        try {
            return Jwts.parser().verifyWith(key()).build()
                    .parseSignedClaims(token.substring(7)).getPayload();
        } catch (Exception e) {
            return null;
        }
    }

    public Long parseUserId(String token) {
        Claims claims = parseToken(token);
        if (claims == null) {
            return null;
        }
        Object userId = claims.get("userId");
        return userId == null ? null : Long.valueOf(userId.toString());
    }
}
'''

JWT_INTERCEPTOR = '''package com.harmonymall.security;

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
'''

SECURITY_CONFIG = '''package com.harmonymall.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

import static org.springframework.security.config.Customizer.withDefaults;

/**
 * Spring Security 配置：本项目使用自定义 JWT 拦截器鉴权，
 * Security 仅负责关闭默认表单登录与 CSRF，全部放行由拦截器控制。
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .httpBasic(basic -> basic.disable())
                .formLogin(form -> form.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
'''


def main():
    os.makedirs(os.path.join(ROOT, "src/main/resources/static/img/products"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "src/main/resources/static/img/banner"), exist_ok=True)

    print("[part1] writing project files ...")
    w("pom.xml", POM)
    w("src/main/resources/application.yml", YML)
    w("src/main/resources/db/schema.sql", SCHEMA)
    w("src/main/java/com/harmonymall/HarmonyMallApplication.java", APP)
    w("src/main/java/com/harmonymall/common/Result.java", RESULT)
    w("src/main/java/com/harmonymall/common/ResultCode.java", RESULT_CODE)
    w("src/main/java/com/harmonymall/common/PageResult.java", PAGE_RESULT)
    w("src/main/java/com/harmonymall/common/BizException.java", BIZ_EXCEPTION)
    w("src/main/java/com/harmonymall/common/GlobalExceptionHandler.java", GLOBAL_EXCEPTION_HANDLER)
    w("src/main/java/com/harmonymall/common/JsonUtils.java", JSON_UTILS)
    w("src/main/java/com/harmonymall/config/MyBatisPlusConfig.java", MYBATIS_PLUS_CONFIG)
    w("src/main/java/com/harmonymall/config/WebConfig.java", WEB_CONFIG)
    w("src/main/java/com/harmonymall/security/JwtUtil.java", JWT_UTIL)
    w("src/main/java/com/harmonymall/security/JwtInterceptor.java", JWT_INTERCEPTOR)
    w("src/main/java/com/harmonymall/security/SecurityConfig.java", SECURITY_CONFIG)

    print("[part1] computing bcrypt hash for demo user ...")
    hash_value = bcrypt_hash()
    if hash_value:
        print("  bcrypt hash ok")
    else:
        print("  bcrypt unavailable, demo user will be skipped")

    print("[part1] done")


if __name__ == "__main__":
    main()
