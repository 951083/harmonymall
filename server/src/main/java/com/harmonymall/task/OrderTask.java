package com.harmonymall.task;

import com.harmonymall.service.OrderService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * 订单相关定时任务（模拟商家的「后台运营」动作）：
 * ① 超时未支付 → 自动取消关单并释放库存（默认 30 分钟）
 * ② 退款申请 → 模拟商家审核通过 → 退款完成 + 回滚库存
 * ③ 发货超期未确认收货 → 自动确认（默认 7 天）
 */
@Component
public class OrderTask {

    private static final Logger log = LoggerFactory.getLogger(OrderTask.class);

    /** 未支付订单超时分钟数（演示时可调小） */
    @Value("${harmonymall.order.timeout-minutes:30}")
    private int timeoutMinutes;

    /** 发货后自动确认收货的天数 */
    @Value("${harmonymall.order.auto-confirm-days:7}")
    private int autoConfirmDays;

    @Autowired
    private OrderService orderService;

    /**
     * 超时关单 + 退款审核，20 秒一轮。
     * 用 fixedDelay 而不是 fixedRate：上一轮没跑完不会再叠一轮，避免任务堆积。
     * 20 秒的频率是为了让「退款中 → 已退款」在演示时能快速看到流转
     */
    @Scheduled(fixedDelay = 20_000, initialDelay = 20_000)
    public void runOrderJobs() {
        cancelTimeoutOrders();
        processRefunds();
    }

    /** 未支付超时 → 自动取消并释放库存 */
    private void cancelTimeoutOrders() {
        try {
            LocalDateTime deadline = LocalDateTime.now().minusMinutes(timeoutMinutes);
            int count = orderService.autoCancelTimeout(deadline);
            if (count > 0) {
                log.info("订单超时自动取消：本轮关闭 {} 笔（超过 {} 分钟未支付）", count, timeoutMinutes);
            }
        } catch (Exception e) {
            // 定时任务异常不能往外抛，否则后续任务不会执行
            log.error("订单超时自动取消失败", e);
        }
    }

    /** 模拟商家审核退款：退款中 → 已退款 + 回滚库存 */
    private void processRefunds() {
        try {
            int count = orderService.autoProcessRefund();
            if (count > 0) {
                log.info("模拟商家审核退款：本轮完成 {} 笔", count);
            }
        } catch (Exception e) {
            log.error("退款自动处理失败", e);
        }
    }

    /** 发货超过 N 天仍未确认收货 → 自动确认，防止订单永远停在「待收货」 */
    @Scheduled(fixedDelay = 3_600_000, initialDelay = 120_000)
    public void autoConfirmOrders() {
        try {
            LocalDateTime deadline = LocalDateTime.now().minusDays(autoConfirmDays);
            int count = orderService.autoConfirm(deadline);
            if (count > 0) {
                log.info("发货超期自动确认收货：本轮处理 {} 笔", count);
            }
        } catch (Exception e) {
            log.error("自动确认收货失败", e);
        }
    }
}
