package com.harmonymall.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.harmonymall.entity.Product;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface ProductMapper extends BaseMapper<Product> {

    /**
     * 原子累加商品销量（下单时调用）。
     * 销量在多规格商品上按 SPU 汇总，用数据库端自增避免并发「读-改-写」丢更新
     */
    @Update("UPDATE t_product SET sales = IFNULL(sales, 0) + #{delta} WHERE id = #{id}")
    int increaseSales(@Param("id") Long id, @Param("delta") int delta);

    /**
     * 原子扣减商品销量（取消 / 退款时调用）。
     * 带 sales >= delta 条件防止扣成负数（历史数据销量小于订单量时兜底）
     */
    @Update("UPDATE t_product SET sales = sales - #{delta} " +
            "WHERE id = #{id} AND IFNULL(sales, 0) >= #{delta}")
    int decreaseSales(@Param("id") Long id, @Param("delta") int delta);
}
