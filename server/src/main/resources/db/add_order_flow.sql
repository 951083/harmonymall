-- =====================================================================
-- 订单业务流增强迁移脚本（2026-10-16）
-- 为「取消原因 / 退款原因 / 退款时间」补充字段，支撑：
--   ① 取消订单时记录原因（用户取消 / 超时未支付自动取消）
--   ② 退款两步流程：退款中(5) → 已退款(6)，记录原因与完成时间
--
-- 说明：本脚本只需在【未执行过】的环境跑一次；
--       列已存在时重复执行会报 1060 Duplicate column
--       （MySQL 不支持 ALTER TABLE ... DROP COLUMN IF EXISTS 语法）
-- =====================================================================

ALTER TABLE t_order
    ADD COLUMN cancel_reason VARCHAR(200) NULL COMMENT '取消原因' AFTER remark,
    ADD COLUMN refund_reason VARCHAR(200) NULL COMMENT '退款原因' AFTER cancel_reason,
    ADD COLUMN refund_time DATETIME NULL COMMENT '退款完成时间' AFTER finish_time;
