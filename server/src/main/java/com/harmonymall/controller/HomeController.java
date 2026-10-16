package com.harmonymall.controller;

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
import org.springframework.web.bind.annotation.RequestMapping;
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
@RequestMapping("/api")
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
