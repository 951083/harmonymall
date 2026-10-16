package com.harmonymall.controller;

import com.harmonymall.common.PageResult;
import com.harmonymall.common.Result;
import com.harmonymall.dto.OrderActionRequest;
import com.harmonymall.dto.OrderCreateRequest;
import com.harmonymall.dto.OrderVO;
import com.harmonymall.entity.Order;
import com.harmonymall.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * 订单：创建 / 列表 / 详情 / 支付 / 取消 / 发货（演示） / 确认收货 / 退款
 */
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @Autowired
    private OrderService orderService;

    @PostMapping
    public Result<Order> create(@RequestAttribute("userId") Long userId,
                                @Valid @RequestBody OrderCreateRequest request) {
        return Result.ok(orderService.create(userId, request));
    }

    @GetMapping
    public Result<PageResult<Order>> list(@RequestAttribute("userId") Long userId,
                                          @RequestParam(required = false) Integer status,
                                          @RequestParam(defaultValue = "1") Integer page,
                                          @RequestParam(defaultValue = "10") Integer size) {
        return Result.ok(orderService.list(userId, status, page, size));
    }

    @GetMapping("/{id}")
    public Result<OrderVO> detail(@RequestAttribute("userId") Long userId,
                                  @PathVariable Long id) {
        return Result.ok(orderService.detail(userId, id));
    }

    @PostMapping("/{id}/pay")
    public Result<Void> pay(@RequestAttribute("userId") Long userId, @PathVariable Long id) {
        orderService.pay(userId, id);
        return Result.ok();
    }

    /** 取消订单：可携带取消原因（可选，body 形如 {"reason":"不想要了"}） */
    @PostMapping("/{id}/cancel")
    public Result<Void> cancel(@RequestAttribute("userId") Long userId, @PathVariable Long id,
                               @RequestBody(required = false) OrderActionRequest request) {
        orderService.cancel(userId, id, request == null ? null : request.getReason());
        return Result.ok();
    }

    /**
     * 模拟商家发货：真实商城由商家后台操作，本工程无管理端，
     * 提供该接口以便端上打通「待发货 → 待收货 → 已完成 → 评价」链路
     */
    @PostMapping("/{id}/ship")
    public Result<Void> ship(@RequestAttribute("userId") Long userId, @PathVariable Long id) {
        orderService.ship(userId, id);
        return Result.ok();
    }

    @PostMapping("/{id}/confirm")
    public Result<Void> confirm(@RequestAttribute("userId") Long userId, @PathVariable Long id) {
        orderService.confirm(userId, id);
        return Result.ok();
    }

    /** 申请退款：进入「退款中」，由定时任务模拟商家审核后自动完成；可携带退款原因 */
    @PostMapping("/{id}/refund")
    public Result<Void> refund(@RequestAttribute("userId") Long userId, @PathVariable Long id,
                               @RequestBody(required = false) OrderActionRequest request) {
        orderService.refund(userId, id, request == null ? null : request.getReason());
        return Result.ok();
    }
}
