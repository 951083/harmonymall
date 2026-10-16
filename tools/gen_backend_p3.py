# -*- coding: utf-8 -*-
"""HarmonyMall 后端脚手架生成脚本 · 第 3 部分
生成 Service 层、Controller 层、补充实体（Category.children / Message）与工具类
"""
import os

ROOT = r"C:\Users\95108\IdeaProjects\harmonymall-server"
JAVA_BASE = "src/main/java/com/harmonymall"


def w(rel, content):
    path = os.path.join(ROOT, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print("  +", rel)


JSON_UTILS = '''package com.harmonymall.common;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * JSON 工具（订单快照 / Redis 缓存序列化）
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

    public static <T> T parse(String json, Class<T> clazz) {
        try {
            return MAPPER.readValue(json, clazz);
        } catch (Exception e) {
            return null;
        }
    }
}
'''

CATEGORY = '''package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.util.List;

/**
 * t_category
 */
@Data
@TableName("t_category")
public class Category {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 上级分类，0 为一级 */
    private Long parentId;

    /** 分类名称 */
    private String name;

    /** 层级 1/2 */
    private Integer level;

    /** 图标 */
    private String icon;

    /** 排序 */
    private Integer sort;

    /** 逻辑删除 */
    private Integer deleted;

    /** 子分类（非数据库字段） */
    @TableField(exist = false)
    private List<Category> children;
}
'''

MESSAGE = '''package com.harmonymall.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * t_message
 */
@Data
@TableName("t_message")
public class Message {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private String title;

    private String content;

    private String type;

    private Integer isRead;

    private LocalDateTime createdAt;
}
'''

MESSAGE_MAPPER = '''package com.harmonymall.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.harmonymall.entity.Message;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface MessageMapper extends BaseMapper<Message> {
}
'''

USER_SERVICE = '''package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.dto.RegisterRequest;
import com.harmonymall.entity.User;
import com.harmonymall.mapper.UserMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * 用户服务：登录 / 注册 / 查询
 */
@Service
public class UserService {

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    public User login(String username, String password) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username));
        if (user == null || !passwordEncoder.matches(password, user.getPassword())) {
            throw new BizException("账号或密码错误");
        }
        if (Integer.valueOf(0).equals(user.getStatus())) {
            throw new BizException("账号已被禁用");
        }
        return user;
    }

    public void register(RegisterRequest request) {
        Long count = userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, request.getUsername()));
        if (count != null && count > 0) {
            throw new BizException("账号已存在");
        }
        User user = new User();
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setPhone(request.getPhone());
        user.setNickname(StringUtils.hasText(request.getUsername()) ? "用户" + request.getUsername() : "新用户");
        user.setStatus(1);
        userMapper.insert(user);
    }

    public User getById(Long id) {
        User user = userMapper.selectById(id);
        if (user == null) {
            throw new BizException("用户不存在");
        }
        return user;
    }
}
'''

PRODUCT_SERVICE = '''package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.common.JsonUtils;
import com.harmonymall.common.PageResult;
import com.harmonymall.entity.Category;
import com.harmonymall.entity.Product;
import com.harmonymall.entity.ProductSku;
import com.harmonymall.mapper.CategoryMapper;
import com.harmonymall.mapper.ProductMapper;
import com.harmonymall.mapper.ProductSkuMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * 商品服务：搜索 / 详情 / SKU / 推荐
 */
@Service
public class ProductService {

    private static final String DETAIL_CACHE_PREFIX = "product:detail:";

    @Autowired
    private ProductMapper productMapper;

    @Autowired
    private ProductSkuMapper productSkuMapper;

    @Autowired
    private CategoryMapper categoryMapper;

    /** Redis 不可用时自动降级为直连数据库 */
    @Autowired(required = false)
    private StringRedisTemplate stringRedisTemplate;

    public PageResult<Product> search(String keyword, Long categoryId, String sort, Integer page, Integer size) {
        com.baomidou.mybatisplus.extension.plugins.pagination.Page<Product> p =
                new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(page, size);
        LambdaQueryWrapper<Product> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Product::getStatus, 1);
        if (StringUtils.hasText(keyword)) {
            wrapper.like(Product::getName, keyword);
        }
        if (categoryId != null) {
            List<Long> ids = new ArrayList<>();
            ids.add(categoryId);
            List<Category> children = categoryMapper.selectList(new LambdaQueryWrapper<Category>()
                    .eq(Category::getParentId, categoryId));
            children.forEach(c -> ids.add(c.getId()));
            wrapper.in(Product::getCategoryId, ids);
        }
        if ("price_asc".equals(sort)) {
            wrapper.orderByAsc(Product::getPrice);
        } else if ("price_desc".equals(sort)) {
            wrapper.orderByDesc(Product::getPrice);
        } else if ("sales".equals(sort)) {
            wrapper.orderByDesc(Product::getSales);
        } else {
            wrapper.orderByDesc(Product::getId);
        }
        com.baomidou.mybatisplus.extension.plugins.pagination.Page<Product> result =
                productMapper.selectPage(p, wrapper);
        return new PageResult<>(result.getRecords(), result.getTotal(), result.getCurrent(), result.getSize());
    }

    public Product getBase(Long id) {
        String key = DETAIL_CACHE_PREFIX + id;
        try {
            String cached = stringRedisTemplate.opsForValue().get(key);
            if (StringUtils.hasText(cached)) {
                Product cachedProduct = JsonUtils.parse(cached, Product.class);
                if (cachedProduct != null) {
                    return cachedProduct;
                }
            }
        } catch (Exception ignored) {
            // Redis 未启动时降级
        }
        Product product = productMapper.selectById(id);
        if (product == null || Integer.valueOf(0).equals(product.getStatus())) {
            throw new BizException("商品不存在或已下架");
        }
        try {
            stringRedisTemplate.opsForValue().set(key, JsonUtils.toJson(product), 30, TimeUnit.MINUTES);
        } catch (Exception ignored) {
            // Redis 未启动时降级
        }
        return product;
    }

    public List<ProductSku> skus(Long productId) {
        return productSkuMapper.selectList(new LambdaQueryWrapper<ProductSku>()
                .eq(ProductSku::getProductId, productId));
    }

    public List<Product> recommend(int limit) {
        return productMapper.selectList(new LambdaQueryWrapper<Product>()
                .eq(Product::getStatus, 1)
                .orderByDesc(Product::getSales)
                .last("limit " + limit));
    }
}
'''

CART_SERVICE = '''package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.dto.CartAddRequest;
import com.harmonymall.dto.CartUpdateRequest;
import com.harmonymall.dto.CartVO;
import com.harmonymall.entity.CartItem;
import com.harmonymall.entity.Product;
import com.harmonymall.entity.ProductSku;
import com.harmonymall.mapper.CartItemMapper;
import com.harmonymall.mapper.ProductMapper;
import com.harmonymall.mapper.ProductSkuMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 购物车服务
 */
@Service
public class CartService {

    @Autowired
    private CartItemMapper cartItemMapper;

    @Autowired
    private ProductSkuMapper productSkuMapper;

    @Autowired
    private ProductMapper productMapper;

    public void add(Long userId, CartAddRequest request) {
        ProductSku sku = productSkuMapper.selectById(request.getSkuId());
        if (sku == null) {
            throw new BizException("商品不存在");
        }
        CartItem exist = cartItemMapper.selectOne(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .eq(CartItem::getSkuId, request.getSkuId()));
        if (exist != null) {
            exist.setQuantity(exist.getQuantity() + request.getQuantity());
            cartItemMapper.updateById(exist);
        } else {
            CartItem item = new CartItem();
            item.setUserId(userId);
            item.setSkuId(request.getSkuId());
            item.setQuantity(request.getQuantity());
            item.setSelected(1);
            cartItemMapper.insert(item);
        }
    }

    public void update(Long userId, Long id, CartUpdateRequest request) {
        CartItem item = cartItemMapper.selectById(id);
        if (item == null || !item.getUserId().equals(userId)) {
            throw new BizException("购物车商品不存在");
        }
        if (request.getQuantity() != null) {
            if (request.getQuantity() < 1) {
                throw new BizException("数量至少为 1");
            }
            item.setQuantity(request.getQuantity());
        }
        if (request.getSelected() != null) {
            item.setSelected(request.getSelected());
        }
        cartItemMapper.updateById(item);
    }

    public void remove(Long userId, Long id) {
        CartItem item = cartItemMapper.selectById(id);
        if (item != null && item.getUserId().equals(userId)) {
            cartItemMapper.deleteById(id);
        }
    }

    public List<CartVO> list(Long userId) {
        List<CartItem> items = cartItemMapper.selectList(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .orderByDesc(CartItem::getId));
        if (items.isEmpty()) {
            return new ArrayList<>();
        }
        List<Long> skuIds = items.stream().map(CartItem::getSkuId).toList();
        List<ProductSku> skus = productSkuMapper.selectBatchIds(skuIds);
        Map<Long, ProductSku> skuMap = skus.stream()
                .collect(Collectors.toMap(ProductSku::getId, s -> s));
        List<Long> productIds = skus.stream().map(ProductSku::getProductId).distinct().toList();
        List<Product> products = productMapper.selectBatchIds(productIds);
        Map<Long, Product> productMap = products.stream()
                .collect(Collectors.toMap(Product::getId, p -> p));

        List<CartVO> vos = new ArrayList<>();
        for (CartItem item : items) {
            ProductSku sku = skuMap.get(item.getSkuId());
            if (sku == null) {
                continue;
            }
            Product product = productMap.get(sku.getProductId());
            CartVO vo = new CartVO();
            vo.setId(item.getId());
            vo.setSkuId(sku.getId());
            vo.setProductId(sku.getProductId());
            vo.setProductName(product == null ? "已下架商品" : product.getName());
            vo.setImage(sku.getImage() != null ? sku.getImage()
                    : (product == null ? null : product.getMainImage()));
            vo.setSpecs(sku.getSpecs());
            vo.setPrice(sku.getPrice());
            vo.setQuantity(item.getQuantity());
            vo.setSelected(item.getSelected());
            vos.add(vo);
        }
        return vos;
    }

    public List<CartItem> listByIds(Long userId, List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return new ArrayList<>();
        }
        return cartItemMapper.selectList(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .in(CartItem::getId, ids));
    }
}
'''

ADDRESS_SERVICE = '''package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.entity.Address;
import com.harmonymall.mapper.AddressMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 收货地址服务
 */
@Service
public class AddressService {

    @Autowired
    private AddressMapper addressMapper;

    public List<Address> listByUser(Long userId) {
        return addressMapper.selectList(new LambdaQueryWrapper<Address>()
                .eq(Address::getUserId, userId)
                .orderByDesc(Address::getIsDefault)
                .orderByDesc(Address::getId));
    }

    public Address getById(Long userId, Long id) {
        Address address = addressMapper.selectById(id);
        if (address == null || !address.getUserId().equals(userId)) {
            throw new BizException("地址不存在");
        }
        return address;
    }

    @Transactional
    public void save(Long userId, Address address) {
        address.setUserId(userId);
        if (address.getId() == null) {
            if (Integer.valueOf(1).equals(address.getIsDefault())) {
                clearDefault(userId);
            }
            addressMapper.insert(address);
            return;
        }
        Address exist = addressMapper.selectById(address.getId());
        if (exist == null || !exist.getUserId().equals(userId)) {
            throw new BizException("地址不存在");
        }
        if (Integer.valueOf(1).equals(address.getIsDefault())) {
            clearDefault(userId);
        }
        addressMapper.updateById(address);
    }

    public void remove(Long userId, Long id) {
        Address address = addressMapper.selectById(id);
        if (address != null && address.getUserId().equals(userId)) {
            addressMapper.deleteById(id);
        }
    }

    @Transactional
    public void setDefault(Long userId, Long id) {
        Address address = addressMapper.selectById(id);
        if (address == null || !address.getUserId().equals(userId)) {
            throw new BizException("地址不存在");
        }
        clearDefault(userId);
        address.setIsDefault(1);
        addressMapper.updateById(address);
    }

    private void clearDefault(Long userId) {
        LambdaUpdateWrapper<Address> wrapper = new LambdaUpdateWrapper<>();
        wrapper.eq(Address::getUserId, userId).set(Address::getIsDefault, 0);
        addressMapper.update(null, wrapper);
    }
}
'''

ORDER_SERVICE = '''package com.harmonymall.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
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
import com.harmonymall.mapper.AddressMapper;
import com.harmonymall.mapper.CartItemMapper;
import com.harmonymall.mapper.OrderItemMapper;
import com.harmonymall.mapper.OrderMapper;
import com.harmonymall.mapper.ProductMapper;
import com.harmonymall.mapper.ProductSkuMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.SimpleDateFormat;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 订单服务：下单（事务）/ 支付 / 取消 / 确认收货 / 退款 / 查询
 */
@Service
public class OrderService {

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

    @Transactional
    public Order create(Long userId, OrderCreateRequest request) {
        List<CartItem> items = cartItemMapper.selectList(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .in(CartItem::getId, request.getCartIds()));
        if (items.isEmpty()) {
            throw new BizException("请选择要结算的商品");
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
        for (CartItem item : items) {
            ProductSku sku = skuMap.get(item.getSkuId());
            if (sku == null) {
                throw new BizException("商品已下架");
            }
            Product product = productMap.get(sku.getProductId());
            String productName = product == null ? "已下架商品" : product.getName();
            if (sku.getStock() < item.getQuantity()) {
                throw new BizException("「" + productName + "」库存不足");
            }
            total += sku.getPrice() * item.getQuantity();
            OrderItem orderItem = new OrderItem();
            orderItem.setSkuId(sku.getId());
            orderItem.setProductId(sku.getProductId());
            orderItem.setPrice(sku.getPrice());
            orderItem.setQuantity(item.getQuantity());
            orderItem.setProductSnapshot(JsonUtils.toJson(buildSnapshot(product, sku)));
            orderItems.add(orderItem);
            sku.setStock(sku.getStock() - item.getQuantity());
            productSkuMapper.updateById(sku);
        }

        Order order = new Order();
        order.setOrderNo(generateOrderNo());
        order.setUserId(userId);
        order.setTotalAmount(total);
        order.setPayAmount(total);
        order.setAddressSnapshot(JsonUtils.toJson(buildAddressSnapshot(address)));
        order.setRemark(request.getRemark());
        order.setStatus(0);
        orderMapper.insert(order);

        for (OrderItem orderItem : orderItems) {
            orderItem.setOrderId(order.getId());
            orderItemMapper.insert(orderItem);
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

    public void pay(Long userId, Long orderId) {
        Order order = getOwnOrder(userId, orderId);
        if (!Integer.valueOf(0).equals(order.getStatus())) {
            throw new BizException("订单状态不支持支付");
        }
        order.setStatus(1);
        order.setPayTime(LocalDateTime.now());
        orderMapper.updateById(order);
    }

    public void cancel(Long userId, Long orderId) {
        Order order = getOwnOrder(userId, orderId);
        if (!Integer.valueOf(0).equals(order.getStatus())) {
            throw new BizException("仅待付款订单可取消");
        }
        order.setStatus(4);
        orderMapper.updateById(order);
    }

    public void confirm(Long userId, Long orderId) {
        Order order = getOwnOrder(userId, orderId);
        if (!Integer.valueOf(2).equals(order.getStatus())) {
            throw new BizException("仅待收货订单可确认收货");
        }
        order.setStatus(3);
        order.setFinishTime(LocalDateTime.now());
        orderMapper.updateById(order);
    }

    public void refund(Long userId, Long orderId) {
        Order order = getOwnOrder(userId, orderId);
        if (!Integer.valueOf(1).equals(order.getStatus()) && !Integer.valueOf(2).equals(order.getStatus())) {
            throw new BizException("当前状态不支持退款");
        }
        order.setStatus(5);
        orderMapper.updateById(order);
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
        OrderVO vo = new OrderVO();
        vo.setId(order.getId());
        vo.setOrderNo(order.getOrderNo());
        vo.setUserId(order.getUserId());
        vo.setTotalAmount(order.getTotalAmount());
        vo.setPayAmount(order.getPayAmount());
        vo.setAddressSnapshot(order.getAddressSnapshot());
        vo.setRemark(order.getRemark());
        vo.setStatus(order.getStatus());
        vo.setPayTime(order.getPayTime());
        vo.setCreatedAt(order.getCreatedAt());
        vo.setItems(items);
        return vo;
    }
}
'''

AUTH_CONTROLLER = '''package com.harmonymall.controller;

import com.harmonymall.common.Result;
import com.harmonymall.dto.LoginRequest;
import com.harmonymall.dto.RegisterRequest;
import com.harmonymall.entity.User;
import com.harmonymall.security.JwtUtil;
import com.harmonymall.service.UserService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * 认证：登录 / 注册 / 验证码
 */
@RestController
@RequestMapping("/auth")
public class AuthController {

    @Autowired
    private UserService userService;

    @Autowired
    private JwtUtil jwtUtil;

    @PostMapping("/login")
    public Result<Map<String, Object>> login(@Valid @RequestBody LoginRequest request) {
        User user = userService.login(request.getUsername(), request.getPassword());
        String token = jwtUtil.createToken(user.getId(), user.getUsername());
        user.setPassword(null);
        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("user", user);
        return Result.ok(data);
    }

    @PostMapping("/register")
    public Result<Void> register(@Valid @RequestBody RegisterRequest request) {
        userService.register(request);
        return Result.ok();
    }

    @PostMapping("/sms/code")
    public Result<String> smsCode(@RequestParam String phone) {
        // 学习项目不接入真实短信服务，直接返回 6 位验证码便于联调
        String code = String.valueOf((int) ((Math.random() * 9 + 1) * 100000));
        return Result.ok(code);
    }
}
'''

HOME_CONTROLLER = '''package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.Result;
import com.harmonymall.entity.Banner;
import com.harmonymall.entity.Category;
import com.harmonymall.entity.Product;
import com.harmonymall.mapper.BannerMapper;
import com.harmonymall.mapper.CategoryMapper;
import com.harmonymall.service.ProductService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 首页聚合数据：轮播图 + 分类树 + 推荐商品
 */
@RestController
public class HomeController {

    @Autowired
    private BannerMapper bannerMapper;

    @Autowired
    private CategoryMapper categoryMapper;

    @Autowired
    private ProductService productService;

    @GetMapping("/home")
    public Result<Map<String, Object>> home() {
        List<Banner> banners = bannerMapper.selectList(new LambdaQueryWrapper<Banner>()
                .orderByAsc(Banner::getSort));
        List<Category> roots = categoryMapper.selectList(new LambdaQueryWrapper<Category>()
                .eq(Category::getLevel, 1)
                .orderByAsc(Category::getSort));
        List<Category> children = roots.isEmpty() ? new ArrayList<>()
                : categoryMapper.selectList(new LambdaQueryWrapper<Category>()
                .in(Category::getParentId, roots.stream().map(Category::getId).toList())
                .orderByAsc(Category::getSort));
        Map<Long, List<Category>> childrenMap = children.stream()
                .collect(Collectors.groupingBy(Category::getParentId));
        roots.forEach(root -> root.setChildren(childrenMap.get(root.getId())));
        List<Product> recommend = productService.recommend(10);

        Map<String, Object> data = new HashMap<>();
        data.put("banners", banners);
        data.put("categories", roots);
        data.put("recommend", recommend);
        return Result.ok(data);
    }
}
'''

CATEGORY_CONTROLLER = '''package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.Result;
import com.harmonymall.entity.Category;
import com.harmonymall.mapper.CategoryMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 分类树
 */
@RestController
@RequestMapping("/categories")
public class CategoryController {

    @Autowired
    private CategoryMapper categoryMapper;

    @GetMapping
    public Result<List<Category>> tree() {
        List<Category> roots = categoryMapper.selectList(new LambdaQueryWrapper<Category>()
                .eq(Category::getLevel, 1)
                .orderByAsc(Category::getSort));
        List<Category> children = roots.isEmpty() ? new ArrayList<>()
                : categoryMapper.selectList(new LambdaQueryWrapper<Category>()
                .in(Category::getParentId, roots.stream().map(Category::getId).toList())
                .orderByAsc(Category::getSort));
        Map<Long, List<Category>> childrenMap = children.stream()
                .collect(Collectors.groupingBy(Category::getParentId));
        roots.forEach(root -> root.setChildren(childrenMap.get(root.getId())));
        return Result.ok(roots);
    }
}
'''

PRODUCT_CONTROLLER = '''package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.PageResult;
import com.harmonymall.common.Result;
import com.harmonymall.entity.Product;
import com.harmonymall.entity.ProductSku;
import com.harmonymall.entity.Review;
import com.harmonymall.mapper.ProductSkuMapper;
import com.harmonymall.mapper.ReviewMapper;
import com.harmonymall.service.ProductService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 商品：搜索列表 / 详情 / 评价列表
 */
@RestController
@RequestMapping("/products")
public class ProductController {

    @Autowired
    private ProductService productService;

    @Autowired
    private ProductSkuMapper productSkuMapper;

    @Autowired
    private ReviewMapper reviewMapper;

    @GetMapping
    public Result<PageResult<Product>> list(@RequestParam(required = false) String keyword,
                                            @RequestParam(required = false) Long categoryId,
                                            @RequestParam(required = false) String sort,
                                            @RequestParam(defaultValue = "1") Integer page,
                                            @RequestParam(defaultValue = "10") Integer size) {
        return Result.ok(productService.search(keyword, categoryId, sort, page, size));
    }

    @GetMapping("/{id}")
    public Result<Map<String, Object>> detail(@PathVariable Long id) {
        Product product = productService.getBase(id);
        List<ProductSku> skus = productService.skus(id);
        Map<String, Object> data = new HashMap<>();
        data.put("product", product);
        data.put("skus", skus);
        return Result.ok(data);
    }

    @GetMapping("/{id}/reviews")
    public Result<List<Review>> reviews(@PathVariable Long id) {
        List<ProductSku> skus = productSkuMapper.selectList(new LambdaQueryWrapper<ProductSku>()
                .eq(ProductSku::getProductId, id)
                .select(ProductSku::getId));
        if (skus.isEmpty()) {
            return Result.ok(new ArrayList<>());
        }
        List<Long> skuIds = skus.stream().map(ProductSku::getId).toList();
        List<Review> reviews = reviewMapper.selectList(new LambdaQueryWrapper<Review>()
                .in(Review::getSkuId, skuIds)
                .orderByDesc(Review::getId));
        return Result.ok(reviews);
    }
}
'''

REVIEW_CONTROLLER = '''package com.harmonymall.controller;

import com.harmonymall.common.BizException;
import com.harmonymall.common.Result;
import com.harmonymall.common.ResultCode;
import com.harmonymall.dto.ReviewRequest;
import com.harmonymall.entity.Review;
import com.harmonymall.mapper.ReviewMapper;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * 评价：发表（需登录）
 */
@RestController
@RequestMapping("/reviews")
public class ReviewController {

    @Autowired
    private ReviewMapper reviewMapper;

    @PostMapping
    public Result<Void> create(@RequestAttribute(value = "userId", required = false) Long userId,
                               @Valid @RequestBody ReviewRequest request) {
        if (userId == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "请先登录");
        }
        Review review = new Review();
        review.setUserId(userId);
        review.setSkuId(request.getSkuId());
        review.setRating(request.getRating());
        review.setContent(request.getContent());
        reviewMapper.insert(review);
        return Result.ok();
    }
}
'''

CART_CONTROLLER = '''package com.harmonymall.controller;

import com.harmonymall.common.Result;
import com.harmonymall.dto.CartAddRequest;
import com.harmonymall.dto.CartUpdateRequest;
import com.harmonymall.dto.CartVO;
import com.harmonymall.service.CartService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 购物车
 */
@RestController
@RequestMapping("/cart")
public class CartController {

    @Autowired
    private CartService cartService;

    @GetMapping
    public Result<List<CartVO>> list(@RequestAttribute("userId") Long userId) {
        return Result.ok(cartService.list(userId));
    }

    @PostMapping
    public Result<Void> add(@RequestAttribute("userId") Long userId,
                            @Valid @RequestBody CartAddRequest request) {
        cartService.add(userId, request);
        return Result.ok();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@RequestAttribute("userId") Long userId,
                               @PathVariable Long id,
                               @RequestBody CartUpdateRequest request) {
        cartService.update(userId, id, request);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@RequestAttribute("userId") Long userId,
                               @PathVariable Long id) {
        cartService.remove(userId, id);
        return Result.ok();
    }
}
'''

ORDER_CONTROLLER = '''package com.harmonymall.controller;

import com.harmonymall.common.PageResult;
import com.harmonymall.common.Result;
import com.harmonymall.dto.OrderCreateRequest;
import com.harmonymall.dto.OrderVO;
import com.harmonymall.entity.Order;
import com.harmonymall.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * 订单：创建 / 列表 / 详情 / 支付 / 取消 / 确认收货 / 退款
 */
@RestController
@RequestMapping("/orders")
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

    @PostMapping("/{id}/cancel")
    public Result<Void> cancel(@RequestAttribute("userId") Long userId, @PathVariable Long id) {
        orderService.cancel(userId, id);
        return Result.ok();
    }

    @PostMapping("/{id}/confirm")
    public Result<Void> confirm(@RequestAttribute("userId") Long userId, @PathVariable Long id) {
        orderService.confirm(userId, id);
        return Result.ok();
    }

    @PostMapping("/{id}/refund")
    public Result<Void> refund(@RequestAttribute("userId") Long userId, @PathVariable Long id) {
        orderService.refund(userId, id);
        return Result.ok();
    }
}
'''

ADDRESS_CONTROLLER = '''package com.harmonymall.controller;

import com.harmonymall.common.Result;
import com.harmonymall.entity.Address;
import com.harmonymall.service.AddressService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 收货地址
 */
@RestController
@RequestMapping("/address")
public class AddressController {

    @Autowired
    private AddressService addressService;

    @GetMapping
    public Result<List<Address>> list(@RequestAttribute("userId") Long userId) {
        return Result.ok(addressService.listByUser(userId));
    }

    @PostMapping
    public Result<Void> save(@RequestAttribute("userId") Long userId,
                             @RequestBody Address address) {
        addressService.save(userId, address);
        return Result.ok();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@RequestAttribute("userId") Long userId,
                               @PathVariable Long id,
                               @RequestBody Address address) {
        address.setId(id);
        addressService.save(userId, address);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> remove(@RequestAttribute("userId") Long userId,
                               @PathVariable Long id) {
        addressService.remove(userId, id);
        return Result.ok();
    }

    @PutMapping("/{id}/default")
    public Result<Void> setDefault(@RequestAttribute("userId") Long userId,
                                   @PathVariable Long id) {
        addressService.setDefault(userId, id);
        return Result.ok();
    }
}
'''

USER_CONTROLLER = '''package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.common.Result;
import com.harmonymall.dto.ProfileRequest;
import com.harmonymall.entity.Favorite;
import com.harmonymall.entity.Footprint;
import com.harmonymall.entity.Message;
import com.harmonymall.entity.Product;
import com.harmonymall.entity.ProductSku;
import com.harmonymall.entity.User;
import com.harmonymall.mapper.FavoriteMapper;
import com.harmonymall.mapper.FootprintMapper;
import com.harmonymall.mapper.MessageMapper;
import com.harmonymall.mapper.ProductMapper;
import com.harmonymall.mapper.ProductSkuMapper;
import com.harmonymall.mapper.UserMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 用户中心：资料 / 收藏 / 足迹 / 站内消息
 */
@RestController
@RequestMapping("/user")
public class UserController {

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private FavoriteMapper favoriteMapper;

    @Autowired
    private FootprintMapper footprintMapper;

    @Autowired
    private MessageMapper messageMapper;

    @Autowired
    private ProductSkuMapper productSkuMapper;

    @Autowired
    private ProductMapper productMapper;

    @GetMapping("/profile")
    public Result<User> profile(@RequestAttribute("userId") Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException("用户不存在");
        }
        user.setPassword(null);
        return Result.ok(user);
    }

    @PutMapping("/profile")
    public Result<Void> updateProfile(@RequestAttribute("userId") Long userId,
                                      @RequestBody ProfileRequest request) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException("用户不存在");
        }
        if (request.getNickname() != null) {
            user.setNickname(request.getNickname());
        }
        if (request.getAvatar() != null) {
            user.setAvatar(request.getAvatar());
        }
        if (request.getPhone() != null) {
            user.setPhone(request.getPhone());
        }
        userMapper.updateById(user);
        return Result.ok();
    }

    @GetMapping("/favorites")
    public Result<List<Map<String, Object>>> favorites(@RequestAttribute("userId") Long userId) {
        List<Favorite> favorites = favoriteMapper.selectList(new LambdaQueryWrapper<Favorite>()
                .eq(Favorite::getUserId, userId)
                .orderByDesc(Favorite::getId));
        return Result.ok(buildSkuList(favorites.stream()
                .map(Favorite::getSkuId).toList()));
    }

    @PostMapping("/favorites")
    public Result<Void> addFavorite(@RequestAttribute("userId") Long userId,
                                    @RequestParam Long skuId) {
        Long count = favoriteMapper.selectCount(new LambdaQueryWrapper<Favorite>()
                .eq(Favorite::getUserId, userId)
                .eq(Favorite::getSkuId, skuId));
        if (count == null || count == 0) {
            Favorite favorite = new Favorite();
            favorite.setUserId(userId);
            favorite.setSkuId(skuId);
            favoriteMapper.insert(favorite);
        }
        return Result.ok();
    }

    @DeleteMapping("/favorites/{skuId}")
    public Result<Void> removeFavorite(@RequestAttribute("userId") Long userId,
                                       @PathVariable Long skuId) {
        favoriteMapper.delete(new LambdaQueryWrapper<Favorite>()
                .eq(Favorite::getUserId, userId)
                .eq(Favorite::getSkuId, skuId));
        return Result.ok();
    }

    @GetMapping("/footprints")
    public Result<List<Map<String, Object>>> footprints(@RequestAttribute("userId") Long userId) {
        List<Footprint> footprints = footprintMapper.selectList(new LambdaQueryWrapper<Footprint>()
                .eq(Footprint::getUserId, userId)
                .orderByDesc(Footprint::getId));
        return Result.ok(buildSkuList(footprints.stream()
                .map(Footprint::getSkuId).toList()));
    }

    @PostMapping("/footprints")
    public Result<Void> addFootprint(@RequestAttribute("userId") Long userId,
                                     @RequestParam Long skuId) {
        Footprint exist = footprintMapper.selectOne(new LambdaQueryWrapper<Footprint>()
                .eq(Footprint::getUserId, userId)
                .eq(Footprint::getSkuId, skuId)
                .orderByDesc(Footprint::getId)
                .last("limit 1"));
        if (exist != null) {
            exist.setViewedAt(LocalDateTime.now());
            footprintMapper.updateById(exist);
        } else {
            Footprint footprint = new Footprint();
            footprint.setUserId(userId);
            footprint.setSkuId(skuId);
            footprintMapper.insert(footprint);
        }
        return Result.ok();
    }

    @GetMapping("/messages")
    public Result<List<Message>> messages(@RequestAttribute("userId") Long userId) {
        return Result.ok(messageMapper.selectList(new LambdaQueryWrapper<Message>()
                .eq(Message::getUserId, userId)
                .orderByDesc(Message::getId)));
    }

    @PutMapping("/messages/{id}/read")
    public Result<Void> readMessage(@RequestAttribute("userId") Long userId,
                                    @PathVariable Long id) {
        Message message = messageMapper.selectById(id);
        if (message != null && message.getUserId().equals(userId)) {
            message.setIsRead(1);
            messageMapper.updateById(message);
        }
        return Result.ok();
    }

    /** 批量组装 SKU 简信息（收藏 / 足迹共用） */
    private List<Map<String, Object>> buildSkuList(List<Long> skuIds) {
        if (skuIds.isEmpty()) {
            return new ArrayList<>();
        }
        List<ProductSku> skus = productSkuMapper.selectBatchIds(skuIds);
        List<Long> productIds = skus.stream().map(ProductSku::getProductId).distinct().toList();
        Map<Long, Product> productMap = productMapper.selectBatchIds(productIds).stream()
                .collect(Collectors.toMap(Product::getId, p -> p));
        List<Map<String, Object>> result = new ArrayList<>();
        for (ProductSku sku : skus) {
            Product product = productMap.get(sku.getProductId());
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("skuId", sku.getId());
            item.put("productId", sku.getProductId());
            item.put("name", product == null ? "已下架商品" : product.getName());
            item.put("image", sku.getImage() != null ? sku.getImage()
                    : (product == null ? "" : product.getMainImage()));
            item.put("price", sku.getPrice());
            result.add(item);
        }
        return result;
    }
}
'''


def main():
    print("[part3] writing services and controllers ...")
    w("src/main/java/com/harmonymall/common/JsonUtils.java", JSON_UTILS)
    w("src/main/java/com/harmonymall/entity/Category.java", CATEGORY)
    w("src/main/java/com/harmonymall/entity/Message.java", MESSAGE)
    w("src/main/java/com/harmonymall/mapper/MessageMapper.java", MESSAGE_MAPPER)
    w("src/main/java/com/harmonymall/service/UserService.java", USER_SERVICE)
    w("src/main/java/com/harmonymall/service/ProductService.java", PRODUCT_SERVICE)
    w("src/main/java/com/harmonymall/service/CartService.java", CART_SERVICE)
    w("src/main/java/com/harmonymall/service/AddressService.java", ADDRESS_SERVICE)
    w("src/main/java/com/harmonymall/service/OrderService.java", ORDER_SERVICE)
    w("src/main/java/com/harmonymall/controller/AuthController.java", AUTH_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/HomeController.java", HOME_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/CategoryController.java", CATEGORY_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/ProductController.java", PRODUCT_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/ReviewController.java", REVIEW_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/CartController.java", CART_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/OrderController.java", ORDER_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/AddressController.java", ADDRESS_CONTROLLER)
    w("src/main/java/com/harmonymall/controller/UserController.java", USER_CONTROLLER)
    print("[part3] done")


if __name__ == "__main__":
    main()
