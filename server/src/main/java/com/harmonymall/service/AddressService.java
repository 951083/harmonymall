package com.harmonymall.service;

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
