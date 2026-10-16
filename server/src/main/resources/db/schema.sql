-- =============================================================
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
  discount_amount  INT          DEFAULT 0 COMMENT '优惠金额（分）',
  coupon_id        BIGINT       DEFAULT NULL COMMENT '使用的优惠券 ID（t_user_coupon.id）',
  pay_amount       INT          NOT NULL COMMENT '实付金额（分）',
  address_snapshot TEXT COMMENT '地址快照 JSON',
  remark           VARCHAR(255) DEFAULT NULL COMMENT '订单备注',
  cancel_reason    VARCHAR(200) DEFAULT NULL COMMENT '取消原因',
  refund_reason    VARCHAR(200) DEFAULT NULL COMMENT '退款原因',
  status           TINYINT      DEFAULT 0 COMMENT '0 待付款 1 待发货 2 待收货 3 已完成 4 已取消 5 退款中 6 已退款',
  pay_time         DATETIME     DEFAULT NULL,
  ship_time        DATETIME     DEFAULT NULL,
  finish_time      DATETIME     DEFAULT NULL,
  refund_time      DATETIME     DEFAULT NULL COMMENT '退款完成时间',
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

DROP TABLE IF EXISTS t_coupon;
CREATE TABLE t_coupon (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  name        VARCHAR(100) NOT NULL COMMENT '券名称',
  amount      INT          NOT NULL COMMENT '面额（分）',
  threshold   INT          DEFAULT 0 COMMENT '使用门槛（分），0 无门槛',
  total       INT          DEFAULT 0 COMMENT '发行总量，0 不限量',
  claimed     INT          DEFAULT 0 COMMENT '已领取数量',
  valid_days  INT          DEFAULT 30 COMMENT '领取后有效天数',
  description VARCHAR(255) DEFAULT NULL COMMENT '使用说明',
  enabled     TINYINT      DEFAULT 1 COMMENT '1 上架 0 下架',
  sort        INT          DEFAULT 0 COMMENT '排序（小在前）',
  created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP
) COMMENT '优惠券模板表';

DROP TABLE IF EXISTS t_user_coupon;
CREATE TABLE t_user_coupon (
  id          BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT       NOT NULL,
  coupon_id   BIGINT       DEFAULT NULL COMMENT '来源券模板 ID（t_coupon.id）',
  name        VARCHAR(100) NOT NULL COMMENT '券名称',
  amount      INT          NOT NULL COMMENT '面额（分）',
  threshold   INT          DEFAULT 0 COMMENT '使用门槛（分）',
  status      TINYINT      DEFAULT 1 COMMENT '1 未使用 0 已使用',
  expire_time DATETIME     DEFAULT NULL,
  used_at     DATETIME     DEFAULT NULL COMMENT '使用时间',
  deleted     TINYINT      DEFAULT 0
) COMMENT '用户优惠券表';

DROP TABLE IF EXISTS t_search_keyword;
CREATE TABLE t_search_keyword (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  keyword    VARCHAR(64) NOT NULL COMMENT '关键词',
  count      INT         DEFAULT 0 COMMENT '搜索次数',
  updated_at DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_keyword (keyword)
) COMMENT '搜索热词统计表';

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
