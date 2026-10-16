package com.harmonymall.service;

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

    /**
     * 加入购物车，返回购物车项 id（供"立即购买"直接下单使用）
     */
    public Long add(Long userId, CartAddRequest request) {
        ProductSku sku = productSkuMapper.selectById(request.getSkuId());
        if (sku == null) {
            throw new BizException("商品不存在");
        }
        int quantity = request.getQuantity() == null ? 1 : request.getQuantity();
        if (quantity < 1) {
            throw new BizException("数量至少为 1");
        }
        int stock = sku.getStock() == null ? 0 : sku.getStock();
        if (stock <= 0) {
            throw new BizException("该规格已售罄");
        }
        CartItem exist = cartItemMapper.selectOne(new LambdaQueryWrapper<CartItem>()
                .eq(CartItem::getUserId, userId)
                .eq(CartItem::getSkuId, request.getSkuId()));
        if (exist != null) {
            int target = exist.getQuantity() + quantity;
            // 加购时先挡一道库存，避免购物车里堆出永远下不了单的数量
            if (target > stock) {
                throw new BizException("库存不足，当前仅剩 " + stock + " 件");
            }
            exist.setQuantity(target);
            cartItemMapper.updateById(exist);
            return exist.getId();
        }
        if (quantity > stock) {
            throw new BizException("库存不足，当前仅剩 " + stock + " 件");
        }
        CartItem item = new CartItem();
        item.setUserId(userId);
        item.setSkuId(request.getSkuId());
        item.setQuantity(quantity);
        item.setSelected(1);
        cartItemMapper.insert(item);
        return item.getId();
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
            ProductSku sku = productSkuMapper.selectById(item.getSkuId());
            if (sku != null) {
                int stock = sku.getStock() == null ? 0 : sku.getStock();
                if (request.getQuantity() > stock) {
                    throw new BizException("库存不足，当前仅剩 " + stock + " 件");
                }
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
            vo.setStock(sku.getStock());
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
