package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.common.Result;
import com.harmonymall.common.ResultCode;
import com.harmonymall.dto.ReviewRequest;
import com.harmonymall.entity.Order;
import com.harmonymall.entity.OrderItem;
import com.harmonymall.entity.Review;
import com.harmonymall.mapper.OrderItemMapper;
import com.harmonymall.mapper.OrderMapper;
import com.harmonymall.mapper.ReviewMapper;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * 评价：发表（需登录，且必须是本人已完成的订单明细，且不能重复评价）
 */
@RestController
@RequestMapping("/api/reviews")
public class ReviewController {

    @Autowired
    private ReviewMapper reviewMapper;

    @Autowired
    private OrderItemMapper orderItemMapper;

    @Autowired
    private OrderMapper orderMapper;

    @PostMapping
    public Result<Void> create(@RequestAttribute(value = "userId", required = false) Long userId,
                               @Valid @RequestBody ReviewRequest request) {
        if (userId == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "请先登录");
        }

        Long orderItemId = request.getOrderItemId();
        if (orderItemId != null) {
            // 走订单评价入口：校验归属 → 校验订单已完成 → 校验未重复评价
            OrderItem item = orderItemMapper.selectById(orderItemId);
            if (item == null) {
                throw new BizException("订单商品不存在");
            }
            Order order = orderMapper.selectById(item.getOrderId());
            if (order == null || !order.getUserId().equals(userId)) {
                throw new BizException("无权评价该商品");
            }
            if (!Integer.valueOf(3).equals(order.getStatus())) {
                throw new BizException("订单完成后才能评价");
            }
            Long exist = reviewMapper.selectCount(new LambdaQueryWrapper<Review>()
                    .eq(Review::getOrderItemId, orderItemId));
            if (exist != null && exist > 0) {
                throw new BizException("该商品已评价过");
            }
            // 以订单明细里的 skuId 为准，避免端上传错
            request.setSkuId(item.getSkuId());
        }

        Review review = new Review();
        review.setOrderItemId(orderItemId);
        review.setUserId(userId);
        review.setSkuId(request.getSkuId());
        review.setRating(request.getRating());
        review.setContent(request.getContent());
        reviewMapper.insert(review);
        return Result.ok();
    }
}
