package com.harmonymall.controller;

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
@RequestMapping("/api/user")
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
        // 按浏览时间倒序：同商品重复浏览只更新时间，用 viewedAt 排才符合「最近看过」的直觉
        List<Footprint> footprints = footprintMapper.selectList(new LambdaQueryWrapper<Footprint>()
                .eq(Footprint::getUserId, userId)
                .orderByDesc(Footprint::getViewedAt));
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

    /**
     * 批量组装 SKU 简信息（收藏 / 足迹共用）
     * 注意：必须按传入 skuIds 的顺序输出——selectBatchIds 的返回顺序由数据库决定，
     * 直接遍历会把「最近浏览 / 最近收藏」的顺序打乱
     */
    private List<Map<String, Object>> buildSkuList(List<Long> skuIds) {
        if (skuIds.isEmpty()) {
            return new ArrayList<>();
        }
        List<ProductSku> skus = productSkuMapper.selectBatchIds(skuIds);
        Map<Long, ProductSku> skuMap = skus.stream()
                .collect(Collectors.toMap(ProductSku::getId, s -> s));
        List<Long> productIds = skus.stream().map(ProductSku::getProductId).distinct().toList();
        Map<Long, Product> productMap = productMapper.selectBatchIds(productIds).stream()
                .collect(Collectors.toMap(Product::getId, p -> p));
        List<Map<String, Object>> result = new ArrayList<>();
        for (Long skuId : skuIds) {
            ProductSku sku = skuMap.get(skuId);
            if (sku == null) {
                continue;
            }
            Product product = productMap.get(sku.getProductId());
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("skuId", sku.getId());
            item.put("productId", sku.getProductId());
            item.put("name", product == null ? "已下架商品" : product.getName());
            item.put("image", sku.getImage() != null ? sku.getImage()
                    : (product == null ? "" : product.getMainImage()));
            item.put("price", sku.getPrice());
            // 规格与库存：端上用于展示规格文案、售罄置灰
            item.put("specs", sku.getSpecs());
            item.put("stock", sku.getStock());
            result.add(item);
        }
        return result;
    }
}
