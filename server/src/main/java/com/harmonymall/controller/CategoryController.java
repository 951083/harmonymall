package com.harmonymall.controller;

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
@RequestMapping("/api/categories")
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
