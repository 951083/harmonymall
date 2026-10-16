package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.common.JsonUtils;
import com.harmonymall.common.PageResult;
import com.harmonymall.dto.OrderCreateRequest;
import com.harmonymall.dto.OrderVO;
import com.harmonymall.entity.Address;
import com.harmonymall.entity.CartItem;
import com.harmonymall.entity.Order;
import com.harmonymall.entity.OrderItem;
import com.harmonymall.entity.Product;
import com.harmonymall.entity.ProductSku;
import com.harmonymall.entity.Review;
import com.harmonymall.entity.UserCoupon;
import com.harmonymall.mapper.AddressMapper;
import com.harmonymall.mapper.CartItemMapper;
import com.harmonymall.mapper.OrderItemMapper;
import com.harmonymall.mapper.OrderMapper;
import com.harmonymall.mapper.ProductMapper;
import com.harmonymall.mapper.ProductSkuMapper;
import com.harmonymall.mapper.ReviewMapper;
import com.harmonymall.mapper.UserCouponMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.text.SimpleDateFormat;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

/**
 * 订单服务：下单（事务 + 幂等 + 库存扣减 + 优惠券抵扣）/ 支付 / 取消 / 发货 / 确认收货 / 退款 / 查询
 */
@Service
public class OrderService {

    /** 幂等令牌在 Redis 中的存活时间（分钟） */
    private static final long TOKEN_TTL_MINUTES = 30;

    @Autowired
    private OrderMapper orderMapper;

    @Autowired
    private OrderItemMapper orderItemMapper;

    @Autowired
    private CartItemMapper cartItemMapper;

    @Autowired
    private ProductSkuMapper productSkuMapper;

    @Autowired
    private ProductMapper productMapper;

    @Autowired
    private AddressMapper addressMapper;

    @Autowired
    private UserCouponMapper userCouponMapper;

    @Autowired
    private ReviewMapper reviewMapper;

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    @Transactional
    public Order create(Long userId, OrderCreateRequest request) {
        // ---------- 幂等：同一 clientToken 只允许成功下单一次 ----------
        // 端上重复点击 / 网络重试时，第二次请求会命中同一个 token 直接拒绝，
        // 避免生成两笔内容完全相同的订单
        String tokenKey = null;
        if (StringUtils.hasText(request.getClientToken())) {
            tokenKey = "order:token:" + userId + ":" + request.getClientToken();
            try {
                Boolean first = stringRedisTemplate.opsForValue().setIfAbsent(tokenKey, "1",
                        TOKEN_TTL_MINUTES, TimeUnit.MINUTES);
                if (Boolean.FALSE.equals(first)) {
                    throw new BizException("订单已提交，请勿重复操作");
                }
            } catch (BizException e) {
                throw e;
            } catch (Exception ignored) {
                // Redis 不可用时降级：靠「购物车项已删除」这层兜底
                tokenKey = null;
            }
        }

        List<CartItem> items = cartItemMapper.selectList(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .in(CartItem::getId, request.getCartIds()));
        if (items.isEmpty()) {
            throw new BizException("请选择要结算的商品");
        }
        // 传了 N 个购物车项但只查到 M 个（M<N），说明有项已被下单/删除，属于异常提交
        if (request.getCartIds().size() != items.size()) {
            throw new BizException("部分商品已失效，请返回购物车重新结算");
        }

        List<Long> skuIds = items.stream().map(CartItem::getSkuId).toList();
        List<ProductSku> skus = productSkuMapper.selectBatchIds(skuIds);
        Map<Long, ProductSku> skuMap = skus.stream()
                .collect(Collectors.toMap(ProductSku::getId, s -> s));
        List<Long> productIds = skus.stream().map(ProductSku::getProductId).distinct().toList();
        Map<Long, Product> productMap = productMapper.selectBatchIds(productIds).stream()
                .collect(Collectors.toMap(Product::getId, p -> p));

        Address address = addressMapper.selectById(request.getAddressId());
        if (address == null || !address.getUserId().equals(userId)) {
            throw new BizException("请选择收货地址");
        }

        int total = 0;
        List<OrderItem> orderItems = new ArrayList<>();
        // 同一商品多规格时按 SPU 累计购买件数，最后一次性回写销量
        Map<Long, Integer> salesDelta = new LinkedHashMap<>();
        for (CartItem item : items) {
            ProductSku sku = skuMap.get(item.getSkuId());
            if (sku == null) {
                throw new BizException("商品已下架");
            }
            Product product = productMap.get(sku.getProductId());
            String productName = product == null ? "已下架商品" : product.getName();
            total += sku.getPrice() * item.getQuantity();
            OrderItem orderItem = new OrderItem();
            orderItem.setSkuId(sku.getId());
            orderItem.setProductId(sku.getProductId());
            orderItem.setPrice(sku.getPrice());
            orderItem.setQuantity(item.getQuantity());
            orderItem.setProductSnapshot(JsonUtils.toJson(buildSnapshot(product, sku)));
            orderItems.add(orderItem);

            // 原子扣库存：把「校验库存充足」和「扣减」合并成一条条件 SQL。
            // 并发抢购时只有扣减成功的请求能走到最后，其余拿到 0 行立即失败（事务回滚），杜绝超卖
            if (productSkuMapper.deductStock(sku.getId(), item.getQuantity()) == 0) {
                throw new BizException("「" + productName + "」库存不足");
            }

            // 累计销量（循环内先按 SPU 记账，出循环后统一原子回写）
            int delta = salesDelta.getOrDefault(sku.getProductId(), 0) + item.getQuantity();
            salesDelta.put(sku.getProductId(), delta);
        }

        // ---------- 优惠券抵扣 ----------
        int discount = 0;
        Long usedCouponId = null;
        if (request.getCouponId() != null) {
            UserCoupon coupon = userCouponMapper.selectById(request.getCouponId());
            if (coupon == null || !coupon.getUserId().equals(userId)) {
                throw new BizException("优惠券不存在");
            }
            if (!Integer.valueOf(1).equals(coupon.getStatus())) {
                throw new BizException("优惠券已使用");
            }
            if (coupon.getExpireTime() != null && coupon.getExpireTime().isBefore(LocalDateTime.now())) {
                throw new BizException("优惠券已过期");
            }
            int threshold = coupon.getThreshold() == null ? 0 : coupon.getThreshold();
            if (total < threshold) {
                throw new BizException("订单金额未达到优惠券使用门槛");
            }
            discount = Math.min(coupon.getAmount() == null ? 0 : coupon.getAmount(), total);
            // 一券一单：用条件更新把「未使用 → 已锁定」一步完成。
            // 并发下单用同一张券时只有一笔能锁定成功，另一笔拿 0 行直接失败，防止券被双花
            int locked = userCouponMapper.update(null, new LambdaUpdateWrapper<UserCoupon>()
                    .eq(UserCoupon::getId, coupon.getId())
                    .eq(UserCoupon::getStatus, 1)
                    .set(UserCoupon::getStatus, 0)
                    .set(UserCoupon::getUsedAt, LocalDateTime.now()));
            if (locked == 0) {
                throw new BizException("优惠券已被使用");
            }
            usedCouponId = coupon.getId();
        }

        Order order = new Order();
        order.setOrderNo(generateOrderNo());
        order.setUserId(userId);
        order.setTotalAmount(total);
        order.setDiscountAmount(discount);
        order.setCouponId(usedCouponId);
        order.setPayAmount(Math.max(total - discount, 0));
        order.setAddressSnapshot(JsonUtils.toJson(buildAddressSnapshot(address)));
        order.setRemark(request.getRemark());
        order.setStatus(0);
        // 逻辑删除字段显式写 0：实体无默认值时 insert 可能落 NULL，
        // 而 NULL 不满足 deleted=0，会被 MP 的查询条件漏掉
        order.setDeleted(0);
        orderMapper.insert(order);

        for (OrderItem orderItem : orderItems) {
            orderItem.setOrderId(order.getId());
            orderItemMapper.insert(orderItem);
        }

        // 回写商品销量（SPU 维度）：数据库端原子自增，避免并发下单互相覆盖
        for (Map.Entry<Long, Integer> entry : salesDelta.entrySet()) {
            productMapper.increaseSales(entry.getKey(), entry.getValue());
        }

        cartItemMapper.deleteBatchIds(request.getCartIds());
        return order;
    }

    private Map<String, Object> buildSnapshot(Product product, ProductSku sku) {
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("name", product == null ? "已下架商品" : product.getName());
        snapshot.put("image", sku.getImage() != null ? sku.getImage()
                : (product == null ? "" : product.getMainImage()));
        snapshot.put("specs", sku.getSpecs());
        snapshot.put("price", sku.getPrice());
        return snapshot;
    }

    private Map<String, Object> buildAddressSnapshot(Address address) {
        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("receiver", address.getReceiver());
        snapshot.put("phone", address.getPhone());
        snapshot.put("region", (address.getProvince() == null ? "" : address.getProvince())
                + (address.getCity() == null ? "" : address.getCity())
                + (address.getDistrict() == null ? "" : address.getDistrict()));
        snapshot.put("detail", address.getDetail());
        return snapshot;
    }

    private String generateOrderNo() {
        return "HM" + new SimpleDateFormat("yyyyMMddHHmmss").format(new Date())
                + (int) ((Math.random() * 9 + 1) * 1000);
    }

    private Order getOwnOrder(Long userId, Long orderId) {
        Order order = orderMapper.selectById(orderId);
        if (order == null || !order.getUserId().equals(userId)) {
            throw new BizException("订单不存在");
        }
        return order;
    }

    /**
     * 回滚订单占用的库存（取消 / 退款时调用），并把下单时累加的销量扣回去。
     * 库存与销量都用数据库端原子自增减，避免并发回滚「读-改-写」互相覆盖。
     * 本方法只在「状态条件更新成功」后被调用，天然保证一笔订单只回滚一次
     */
    private void restoreStock(Long orderId) {
        List<OrderItem> items = orderItemMapper.selectList(new LambdaQueryWrapper<OrderItem>()
                .eq(OrderItem::getOrderId, orderId));
        Map<Long, Integer> salesDelta = new LinkedHashMap<>();
        for (OrderItem item : items) {
            productSkuMapper.restoreStock(item.getSkuId(), item.getQuantity());
            int delta = salesDelta.getOrDefault(item.getProductId(), 0) + item.getQuantity();
            salesDelta.put(item.getProductId(), delta);
        }
        for (Map.Entry<Long, Integer> entry : salesDelta.entrySet()) {
            productMapper.decreaseSales(entry.getKey(), entry.getValue());
        }
        // 优惠券随订单取消一并退回，用户可以重新使用
        Order order = orderMapper.selectById(orderId);
        if (order != null && order.getCouponId() != null) {
            UserCoupon coupon = userCouponMapper.selectById(order.getCouponId());
            if (coupon != null && Integer.valueOf(0).equals(coupon.getStatus())
                    && coupon.getExpireTime() != null
                    && coupon.getExpireTime().isAfter(LocalDateTime.now())) {
                // 用 UpdateWrapper 把 used_at 显式置空：
                // updateById 默认忽略 null 字段（NOT_NULL 策略），setUsedAt(null) 不会生效
                userCouponMapper.update(null, new LambdaUpdateWrapper<UserCoupon>()
                        .eq(UserCoupon::getId, coupon.getId())
                        .set(UserCoupon::getStatus, 1)
                        .set(UserCoupon::getUsedAt, null));
            }
        }
    }

    /**
     * 模拟支付。
     * 先校验订单归属（保证「订单不存在」的报错语义），再用条件更新把
     * 「待付款 → 待发货」一步推进；返回 0 行说明状态已变化（比如重复支付、
     * 或订单刚好被超时任务取消），直接拒绝
     */
    public void pay(Long userId, Long orderId) {
        getOwnOrder(userId, orderId);
        if (orderMapper.markPaid(orderId, userId, LocalDateTime.now()) == 0) {
            throw new BizException("订单状态已变化，请刷新后重试");
        }
    }

    /**
     * 发货（把待发货推进到待收货）。
     * 真实商城由商家后台触发，本工程没有管理端，因此做成「演示用」接口，
     * 端上在「待发货」订单详情里给一个模拟发货按钮，用于打通 收货 → 评价 链路
     */
    public void ship(Long userId, Long orderId) {
        getOwnOrder(userId, orderId);
        if (orderMapper.markShipped(orderId, LocalDateTime.now()) == 0) {
            throw new BizException("仅待发货订单可发货");
        }
    }

    /**
     * 取消订单（仅待付款），可带取消原因。
     * 状态推进成功后才回滚库存；与超时自动取消并发时只有一方能更新成功，
     * 库存不会被重复回滚
     */
    @Transactional
    public void cancel(Long userId, Long orderId, String reason) {
        getOwnOrder(userId, orderId);
        if (orderMapper.markCancelled(orderId, userId, defaultReason(reason, "用户取消")) == 0) {
            throw new BizException("仅待付款订单可取消");
        }
        restoreStock(orderId);
    }

    /**
     * 确认收货（无库存 / 优惠券副作用，条件更新即可）。
     * 重复点击时第二次返回 0 行，直接拒绝
     */
    public void confirm(Long userId, Long orderId) {
        getOwnOrder(userId, orderId);
        if (orderMapper.markConfirmed(orderId, LocalDateTime.now()) == 0) {
            throw new BizException("仅待收货订单可确认收货");
        }
    }

    /**
     * 申请退款：「待发货 / 待收货 → 退款中」，记录退款原因。
     * 退款分两步是为了贴近真实流程——申请后进入「退款中」，
     * 由 OrderTask 模拟商家审核（约 30 秒内）自动完成退款并回滚库存
     */
    public void refund(Long userId, Long orderId, String reason) {
        getOwnOrder(userId, orderId);
        if (orderMapper.markRefunding(orderId, userId, defaultReason(reason, "用户申请退款")) == 0) {
            throw new BizException("当前状态不支持退款（仅待发货 / 待收货订单）");
        }
    }

    /** 原因文本兜底：端上未选择时给默认值，避免详情页展示空白 */
    private String defaultReason(String reason, String fallback) {
        return StringUtils.hasText(reason) ? reason.trim() : fallback;
    }

    /**
     * 超时未支付自动取消（由定时任务调用）。
     * 只处理「待付款」且创建时间早于 deadline 的订单；
     * 逐单条件更新，与用户手动取消 / 支付并发时只有一方能成功，避免重复回滚库存
     */
    @Transactional
    public int autoCancelTimeout(LocalDateTime deadline) {
        List<Order> orders = orderMapper.selectList(new LambdaQueryWrapper<Order>()
                .eq(Order::getStatus, 0)
                .lt(Order::getCreatedAt, deadline));
        int count = 0;
        for (Order order : orders) {
            if (orderMapper.markCancelled(order.getId(), order.getUserId(),
                    "超时未支付，系统自动取消") > 0) {
                restoreStock(order.getId());
                count++;
            }
        }
        return count;
    }

    /**
     * 模拟商家审核退款：把「退款中(5)」推进到「已退款(6)」并回滚库存。
     * 条件更新保证同一笔退款只会被处理一次（多实例部署也安全）
     */
    @Transactional
    public int autoProcessRefund() {
        List<Order> orders = orderMapper.selectList(new LambdaQueryWrapper<Order>()
                .eq(Order::getStatus, 5));
        int count = 0;
        for (Order order : orders) {
            if (orderMapper.markRefunded(order.getId()) > 0) {
                restoreStock(order.getId());
                count++;
            }
        }
        return count;
    }

    /**
     * 发货超期自动确认收货（无副作用，批量 SQL 一次完成），
     * 防止订单永远停留在「待收货」
     */
    public int autoConfirm(LocalDateTime deadline) {
        return orderMapper.autoConfirm(deadline);
    }

    public PageResult<Order> list(Long userId, Integer status, Integer page, Integer size) {
        com.baomidou.mybatisplus.extension.plugins.pagination.Page<Order> p =
                new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(page, size);
        LambdaQueryWrapper<Order> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Order::getUserId, userId);
        if (status != null) {
            wrapper.eq(Order::getStatus, status);
        }
        wrapper.orderByDesc(Order::getId);
        com.baomidou.mybatisplus.extension.plugins.pagination.Page<Order> result =
                orderMapper.selectPage(p, wrapper);
        return new PageResult<>(result.getRecords(), result.getTotal(), result.getCurrent(), result.getSize());
    }

    public OrderVO detail(Long userId, Long orderId) {
        Order order = getOwnOrder(userId, orderId);
        List<OrderItem> items = orderItemMapper.selectList(new LambdaQueryWrapper<OrderItem>()
                .eq(OrderItem::getOrderId, orderId));

        // 回填「是否已评价」：一次性查出本单所有已评价的明细 ID，避免 N+1
        if (!items.isEmpty()) {
            List<Long> itemIds = items.stream().map(OrderItem::getId).toList();
            List<Review> reviews = reviewMapper.selectList(new LambdaQueryWrapper<Review>()
                    .in(Review::getOrderItemId, itemIds)
                    .select(Review::getOrderItemId));
            Set<Long> reviewedIds = reviews.stream()
                    .map(Review::getOrderItemId)
                    .filter(java.util.Objects::nonNull)
                    .collect(Collectors.toSet());
            for (OrderItem item : items) {
                item.setReviewed(reviewedIds.contains(item.getId()));
            }
        }

        OrderVO vo = new OrderVO();
        vo.setId(order.getId());
        vo.setOrderNo(order.getOrderNo());
        vo.setUserId(order.getUserId());
        vo.setTotalAmount(order.getTotalAmount());
        vo.setDiscountAmount(order.getDiscountAmount() == null ? 0 : order.getDiscountAmount());
        vo.setPayAmount(order.getPayAmount());
        vo.setAddressSnapshot(order.getAddressSnapshot());
        vo.setRemark(order.getRemark());
        vo.setStatus(order.getStatus());
        vo.setPayTime(order.getPayTime());
        vo.setShipTime(order.getShipTime());
        vo.setFinishTime(order.getFinishTime());
        vo.setRefundTime(order.getRefundTime());
        vo.setCancelReason(order.getCancelReason());
        vo.setRefundReason(order.getRefundReason());
        vo.setCreatedAt(order.getCreatedAt());
        vo.setItems(items);
        return vo;
    }
}
