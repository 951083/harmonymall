package com.harmonymall.service;

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
            String json = JsonUtils.toJson(product);
            // 防御：序列化失败时 JsonUtils 返回 "{}"，绝不能把空对象写进缓存，
            // 否则该商品详情在 TTL 内一直返回空（端上表现为名称丢失、"已售 undefined"）
            if (StringUtils.hasText(json) && !"{}".equals(json)) {
                stringRedisTemplate.opsForValue().set(key, json, 30, TimeUnit.MINUTES);
            }
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
