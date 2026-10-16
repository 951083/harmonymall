-- =============================================================
-- HarmonyMall 鸿蒙商城 · 功能增强迁移脚本（P0 优化 + 新增商城功能）
-- 用途：在已有库上增量执行（不要 DROP，保留既有数据）
-- 内容：
--   1. 优惠券模板表 t_coupon（领券中心）
--   2. t_user_coupon 补充 coupon_id / used_at
--   3. t_order 补充 discount_amount / coupon_id（优惠券抵扣）
--   4. 搜索热词统计表 t_search_keyword（热门搜索）
-- =============================================================
USE harmonymall;
SET NAMES utf8mb4;

-- ---------- 1. 优惠券模板 ----------
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

INSERT INTO t_coupon (id, name, amount, threshold, total, claimed, valid_days, description, enabled, sort) VALUES
(1, '新人专享券',   1000,  5000,  1000, 1, 60, '满 50 元可用，全品类通用',      1, 1),
(2, '数码品类券',   3000, 20000,   500, 1, 30, '满 200 元可用，限数码类商品',   1, 2),
(3, '无门槛立减券',  500,     0,  2000, 0, 15, '无门槛，全品类可用',            1, 3),
(4, '满减福利券',   2000, 10000,   800, 0, 30, '满 100 元减 20 元，全品类通用', 1, 4);

-- ---------- 2. 用户券补充字段 ----------
ALTER TABLE t_user_coupon
  ADD COLUMN coupon_id BIGINT DEFAULT NULL COMMENT '来源券模板 ID' AFTER user_id,
  ADD COLUMN used_at   DATETIME DEFAULT NULL COMMENT '使用时间' AFTER expire_time;

-- 既有历史数据回填：按面额+门槛匹配到模板，便于「我的优惠券」统一展示
UPDATE t_user_coupon SET coupon_id = 1 WHERE coupon_id IS NULL AND amount = 1000 AND threshold = 5000;
UPDATE t_user_coupon SET coupon_id = 2 WHERE coupon_id IS NULL AND amount = 3000 AND threshold = 20000;

-- ---------- 3. 订单补充优惠字段 ----------
ALTER TABLE t_order
  ADD COLUMN discount_amount INT DEFAULT 0 COMMENT '优惠金额（分）' AFTER total_amount,
  ADD COLUMN coupon_id       BIGINT DEFAULT NULL COMMENT '使用的优惠券 ID（t_user_coupon.id）' AFTER discount_amount;

-- ---------- 4. 搜索热词统计 ----------
DROP TABLE IF EXISTS t_search_keyword;
CREATE TABLE t_search_keyword (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  keyword    VARCHAR(64) NOT NULL COMMENT '关键词',
  count      INT         DEFAULT 0 COMMENT '搜索次数',
  updated_at DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_keyword (keyword)
) COMMENT '搜索热词统计表';

INSERT INTO t_search_keyword (keyword, count, updated_at) VALUES
('耳机',   36, NOW()),
('蓝牙',   29, NOW()),
('手表',   24, NOW()),
('充电宝', 21, NOW()),
('鼠标',   17, NOW()),
('键盘',   13, NOW()),
('音箱',   11, NOW()),
('小米',    9, NOW());
