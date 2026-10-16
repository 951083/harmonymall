package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.PageResult;
import com.harmonymall.common.Result;
import com.harmonymall.dto.ReviewVO;
import com.harmonymall.entity.Product;
import com.harmonymall.entity.ProductSku;
import com.harmonymall.entity.Review;
import com.harmonymall.entity.SearchKeyword;
import com.harmonymall.entity.User;
import com.harmonymall.mapper.ProductSkuMapper;
import com.harmonymall.mapper.ReviewMapper;
import com.harmonymall.mapper.SearchKeywordMapper;
import com.harmonymall.mapper.UserMapper;
import com.harmonymall.service.ProductService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 商品：搜索列表 / 详情 / 评价列表 / 热门搜索词
 */
@RestController
@RequestMapping("/api/products")
public class ProductController {

    /** 热门搜索词返回条数 */
    private static final int HOT_KEYWORD_LIMIT = 8;

    @Autowired
    private ProductService productService;

    @Autowired
    private ProductSkuMapper productSkuMapper;

    @Autowired
    private ReviewMapper reviewMapper;

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private SearchKeywordMapper searchKeywordMapper;

    @GetMapping
    public Result<PageResult<Product>> list(@RequestParam(required = false) String keyword,
                                            @RequestParam(required = false) Long categoryId,
                                            @RequestParam(required = false) String sort,
                                            @RequestParam(defaultValue = "1") Integer page,
                                            @RequestParam(defaultValue = "10") Integer size) {
        // 只有「带关键词」的搜索才计入热词统计，翻页 / 选分类不重复计数
        if (StringUtils.hasText(keyword) && page != null && page == 1) {
            recordKeyword(keyword.trim());
        }
        return Result.ok(productService.search(keyword, categoryId, sort, page, size));
    }

    /**
     * 搜索热词统计：存在则 +1，不存在则插入。
     * 统计失败不能影响搜索本身，因此整段 try-catch 兜底。
     */
    private void recordKeyword(String keyword) {
        if (keyword.isEmpty() || keyword.length() > 32) {
            return;
        }
        try {
            SearchKeyword exist = searchKeywordMapper.selectOne(new LambdaQueryWrapper<SearchKeyword>()
                    .eq(SearchKeyword::getKeyword, keyword));
            if (exist == null) {
                SearchKeyword item = new SearchKeyword();
                item.setKeyword(keyword);
                item.setCount(1);
                item.setUpdatedAt(LocalDateTime.now());
                searchKeywordMapper.insert(item);
            } else {
                exist.setCount((exist.getCount() == null ? 0 : exist.getCount()) + 1);
                exist.setUpdatedAt(LocalDateTime.now());
                searchKeywordMapper.updateById(exist);
            }
        } catch (Exception ignored) {
            // 统计是旁路逻辑，失败不影响搜索
        }
    }

    /** 热门搜索词：按搜索次数倒序 */
    @GetMapping("/hot-keywords")
    public Result<List<String>> hotKeywords() {
        List<SearchKeyword> list = searchKeywordMapper.selectList(new LambdaQueryWrapper<SearchKeyword>()
                .orderByDesc(SearchKeyword::getCount)
                .orderByDesc(SearchKeyword::getUpdatedAt)
                .last("LIMIT " + HOT_KEYWORD_LIMIT));
        List<String> result = new ArrayList<>();
        for (SearchKeyword item : list) {
            result.add(item.getKeyword());
        }
        return Result.ok(result);
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

    /** 商品评价：带评价人昵称（未设置昵称时按 用户名首字 + *** 脱敏） */
    @GetMapping("/{id}/reviews")
    public Result<List<ReviewVO>> reviews(@PathVariable Long id) {
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

        List<Long> userIds = reviews.stream().map(Review::getUserId).distinct().toList();
        Map<Long, User> userMap = userIds.isEmpty() ? new HashMap<>()
                : userMapper.selectBatchIds(userIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        List<ReviewVO> result = new ArrayList<>();
        for (Review review : reviews) {
            ReviewVO vo = new ReviewVO();
            vo.setId(review.getId());
            vo.setOrderItemId(review.getOrderItemId());
            vo.setUserId(review.getUserId());
            vo.setSkuId(review.getSkuId());
            vo.setRating(review.getRating());
            vo.setContent(review.getContent());
            vo.setCreatedAt(review.getCreatedAt());
            User user = userMap.get(review.getUserId());
            vo.setNickname(displayName(user));
            vo.setAvatar(user == null ? null : user.getAvatar());
            result.add(vo);
        }
        return Result.ok(result);
    }

    /** 昵称脱敏：有昵称用昵称，否则用 用户名首位 + *** */
    private String displayName(User user) {
        if (user == null) {
            return "已注销用户";
        }
        if (StringUtils.hasText(user.getNickname())) {
            return user.getNickname();
        }
        String username = user.getUsername();
        if (!StringUtils.hasText(username)) {
            return "匿名用户";
        }
        return username.substring(0, 1) + "***";
    }
}
