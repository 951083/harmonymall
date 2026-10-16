package com.harmonymall.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.harmonymall.entity.ProductSku;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface ProductSkuMapper extends BaseMapper<ProductSku> {

    /**
     * 条件扣减库存：把「校验库存足够」和「扣减」合并进同一条 SQL 原子完成。
     * 返回受影响行数——1 表示扣减成功，0 表示库存不足（并发抢购时被其它订单先扣完）。
     * 相比「先 select 判断再 update」的读-改-写，彻底消除超卖窗口。
     */
    @Update("UPDATE t_product_sku SET stock = stock - #{qty} " +
            "WHERE id = #{id} AND stock >= #{qty} AND deleted = 0")
    int deductStock(@Param("id") Long id, @Param("qty") int qty);

    /**
     * 原子回滚库存（取消 / 退款时调用）：stock = stock + qty 在数据库端自增，
     * 避免两笔并发回滚「读-改-写」互相覆盖导致库存少加
     */
    @Update("UPDATE t_product_sku SET stock = stock + #{qty} " +
            "WHERE id = #{id} AND deleted = 0")
    int restoreStock(@Param("id") Long id, @Param("qty") int qty);
}
