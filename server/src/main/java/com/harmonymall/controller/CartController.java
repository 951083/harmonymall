package com.harmonymall.controller;

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
@RequestMapping("/api/cart")
public class CartController {

    @Autowired
    private CartService cartService;

    @GetMapping
    public Result<List<CartVO>> list(@RequestAttribute("userId") Long userId) {
        return Result.ok(cartService.list(userId));
    }

    @PostMapping
    public Result<Long> add(@RequestAttribute("userId") Long userId,
                            @Valid @RequestBody CartAddRequest request) {
        return Result.ok(cartService.add(userId, request));
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
