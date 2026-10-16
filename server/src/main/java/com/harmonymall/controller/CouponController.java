package com.harmonymall.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.harmonymall.common.BizException;
import com.harmonymall.common.Result;
import com.harmonymall.common.ResultCode;
import com.harmonymall.dto.CouponVO;
import com.harmonymall.entity.Coupon;
import com.harmonymall.entity.UserCoupon;
import com.harmonymall.mapper.CouponMapper;
import com.harmonymall.mapper.UserCouponMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 优惠券：领券中心 / 领取 / 我的优惠券 / 下单可用券
 *
 * 状态约定（CouponVO.status）：
 *   null 领券中心未领取
 *   0 未使用   1 已使用   2 已过期
 */
@RestController
@RequestMapping("/api/coupons")
public class CouponController {

    @Autowired
    private CouponMapper couponMapper;

    @Autowired
    private UserCouponMapper userCouponMapper;

    /** 领券中心：上架中的券模板 + 当前用户是否已领取 */
    @GetMapping
    public Result<List<CouponVO>> center(@RequestAttribute(value = "userId", required = false) Long userId) {
        List<Coupon> coupons = couponMapper.selectList(new LambdaQueryWrapper<Coupon>()
                .eq(Coupon::getEnabled, 1)
                .orderByAsc(Coupon::getSort)
                .orderByDesc(Coupon::getAmount));

        // 已领取的模板 ID（同一用户每张券模板只允许领一次）
        List<Long> claimedIds = new ArrayList<>();
        if (userId != null) {
            List<UserCoupon> mine = userCouponMapper.selectList(new LambdaQueryWrapper<UserCoupon>()
                    .eq(UserCoupon::getUserId, userId)
                    .isNotNull(UserCoupon::getCouponId));
            for (UserCoupon uc : mine) {
                claimedIds.add(uc.getCouponId());
            }
        }

        List<CouponVO> result = new ArrayList<>();
        for (Coupon coupon : coupons) {
            CouponVO vo = new CouponVO();
            vo.setCouponId(coupon.getId());
            vo.setName(coupon.getName());
            vo.setAmount(coupon.getAmount());
            vo.setThreshold(coupon.getThreshold());
            vo.setValidDays(coupon.getValidDays());
            vo.setDescription(coupon.getDescription());
            int total = coupon.getTotal() == null ? 0 : coupon.getTotal();
            int claimed = coupon.getClaimed() == null ? 0 : coupon.getClaimed();
            vo.setRemain(total <= 0 ? -1 : Math.max(total - claimed, 0));
            vo.setClaimed(claimedIds.contains(coupon.getId()));
            result.add(vo);
        }
        return Result.ok(result);
    }

    /** 领取优惠券 */
    @PostMapping("/{id}/claim")
    public Result<Void> claim(@RequestAttribute(value = "userId", required = false) Long userId,
                              @PathVariable Long id) {
        if (userId == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "请先登录");
        }
        Coupon coupon = couponMapper.selectById(id);
        if (coupon == null || !Integer.valueOf(1).equals(coupon.getEnabled())) {
            throw new BizException("优惠券不存在或已下架");
        }
        Long exist = userCouponMapper.selectCount(new LambdaQueryWrapper<UserCoupon>()
                .eq(UserCoupon::getUserId, userId)
                .eq(UserCoupon::getCouponId, id));
        if (exist != null && exist > 0) {
            throw new BizException("该优惠券每人限领一张");
        }
        int total = coupon.getTotal() == null ? 0 : coupon.getTotal();
        int claimed = coupon.getClaimed() == null ? 0 : coupon.getClaimed();
        if (total > 0 && claimed >= total) {
            throw new BizException("优惠券已被领完");
        }

        UserCoupon uc = new UserCoupon();
        uc.setUserId(userId);
        uc.setCouponId(coupon.getId());
        uc.setName(coupon.getName());
        uc.setAmount(coupon.getAmount());
        uc.setThreshold(coupon.getThreshold());
        uc.setStatus(1);
        int days = coupon.getValidDays() == null ? 30 : coupon.getValidDays();
        uc.setExpireTime(LocalDateTime.now().plusDays(days));
        uc.setDeleted(0);
        userCouponMapper.insert(uc);

        coupon.setClaimed(claimed + 1);
        couponMapper.updateById(coupon);
        return Result.ok();
    }

    /** 我的优惠券（status 不传返回全部，0 未使用 1 已使用 2 已过期） */
    @GetMapping("/mine")
    public Result<List<CouponVO>> mine(@RequestAttribute(value = "userId", required = false) Long userId,
                                       @RequestParam(required = false) Integer status) {
        if (userId == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "请先登录");
        }
        List<UserCoupon> mine = userCouponMapper.selectList(new LambdaQueryWrapper<UserCoupon>()
                .eq(UserCoupon::getUserId, userId)
                .orderByAsc(UserCoupon::getStatus)
                .orderByDesc(UserCoupon::getAmount));
        List<CouponVO> result = new ArrayList<>();
        for (UserCoupon uc : mine) {
            CouponVO vo = toVO(uc);
            if (status != null && !status.equals(vo.getStatus())) {
                continue;
            }
            result.add(vo);
        }
        return Result.ok(result);
    }

    /** 下单可用券：未使用 + 未过期 + 满足门槛，amount 为订单金额（分） */
    @GetMapping("/usable")
    public Result<List<CouponVO>> usable(@RequestAttribute(value = "userId", required = false) Long userId,
                                         @RequestParam Integer amount) {
        if (userId == null) {
            throw new BizException(ResultCode.UNAUTHORIZED, "请先登录");
        }
        List<UserCoupon> mine = userCouponMapper.selectList(new LambdaQueryWrapper<UserCoupon>()
                .eq(UserCoupon::getUserId, userId)
                .eq(UserCoupon::getStatus, 1)
                .orderByDesc(UserCoupon::getAmount));
        int orderAmount = amount == null ? 0 : amount;
        List<CouponVO> result = new ArrayList<>();
        for (UserCoupon uc : mine) {
            CouponVO vo = toVO(uc);
            // 只用「未使用且未过期且达到门槛」的券
            if (!Integer.valueOf(0).equals(vo.getStatus())) {
                continue;
            }
            int threshold = uc.getThreshold() == null ? 0 : uc.getThreshold();
            if (orderAmount < threshold) {
                continue;
            }
            result.add(vo);
        }
        return Result.ok(result);
    }

    private CouponVO toVO(UserCoupon uc) {
        CouponVO vo = new CouponVO();
        vo.setId(uc.getId());
        vo.setCouponId(uc.getCouponId());
        vo.setName(uc.getName());
        vo.setAmount(uc.getAmount());
        vo.setThreshold(uc.getThreshold());
        vo.setExpireTime(uc.getExpireTime());
        if (!Integer.valueOf(1).equals(uc.getStatus())) {
            vo.setStatus(1);
        } else if (uc.getExpireTime() != null && uc.getExpireTime().isBefore(LocalDateTime.now())) {
            vo.setStatus(2);
        } else {
            vo.setStatus(0);
        }
        return vo;
    }
}
