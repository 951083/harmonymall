package com.harmonymall.controller;

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
@RequestMapping("/api/address")
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
