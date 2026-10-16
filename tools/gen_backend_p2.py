# -*- coding: utf-8 -*-
"""HarmonyMall 后端脚手架生成脚本 · 第 2 部分
生成 12 个实体、12 个 Mapper、DTO 与 data.sql（种子数据）
"""
import os
import subprocess
import sys

ROOT = r"C:\Users\95108\IdeaProjects\harmonymall-server"
JAVA_BASE = "src/main/java/com/harmonymall"


def w(rel, content):
    path = os.path.join(ROOT, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print("  +", rel)


def bcrypt_hash(pwd="123456"):
    try:
        import bcrypt
    except ImportError:
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "bcrypt"], check=False)
        try:
            import bcrypt
        except ImportError:
            return None
    return bcrypt.hashpw(pwd.encode("utf-8"), bcrypt.gensalt()).decode()


def entity(name, table, fields):
    """fields: [(field, type, comment)]"""
    lines = [
        "package com.harmonymall.entity;",
        "",
        "import com.baomidou.mybatisplus.annotation.IdType;",
        "import com.baomidou.mybatisplus.annotation.TableId;",
        "import com.baomidou.mybatisplus.annotation.TableName;",
        "import lombok.Data;",
        "",
        "import java.time.LocalDateTime;",
        "",
        "/**",
        " * " + table,
        " */",
        "@Data",
        '@TableName("' + table + '")',
        "public class " + name + " {",
        "",
        '    @TableId(type = IdType.AUTO)',
        "    private Long id;",
        "",
    ]
    for field, ftype, comment in fields:
        lines.append("    /** " + comment + " */")
        lines.append("    private " + ftype + " " + field + ";")
        lines.append("")
    lines.append("}")
    return "\n".join(lines)


def mapper(name, entity_name):
    return (
        "package com.harmonymall.mapper;\n\n"
        "import com.baomidou.mybatisplus.core.mapper.BaseMapper;\n"
        "import com.harmonymall.entity." + entity_name + ";\n"
        "import org.apache.ibatis.annotations.Mapper;\n\n"
        "@Mapper\n"
        "public interface " + name + " extends BaseMapper<" + entity_name + "> {\n"
        "}\n"
    )


ENTITIES = {
    "User": ("t_user", [
        ("username", "String", "登录账号"),
        ("password", "String", "BCrypt 密码"),
        ("phone", "String", "手机号"),
        ("nickname", "String", "昵称"),
        ("avatar", "String", "头像"),
        ("status", "Integer", "1 正常 0 禁用"),
        ("deleted", "Integer", "逻辑删除"),
        ("createdAt", "LocalDateTime", ""),
        ("updatedAt", "LocalDateTime", ""),
    ]),
    "Address": ("t_address", [
        ("userId", "Long", "用户 ID"),
        ("receiver", "String", "收货人"),
        ("phone", "String", "手机号"),
        ("province", "String", "省"),
        ("city", "String", "市"),
        ("district", "String", "区/县"),
        ("detail", "String", "详细地址"),
        ("isDefault", "Integer", "是否默认 0/1"),
        ("deleted", "Integer", "逻辑删除"),
        ("createdAt", "LocalDateTime", ""),
        ("updatedAt", "LocalDateTime", ""),
    ]),
    "Category": ("t_category", [
        ("parentId", "Long", "上级分类，0 为一级"),
        ("name", "String", "分类名称"),
        ("level", "Integer", "层级 1/2"),
        ("icon", "String", "图标"),
        ("sort", "Integer", "排序"),
        ("deleted", "Integer", "逻辑删除"),
    ]),
    "Product": ("t_product", [
        ("categoryId", "Long", "二级分类 ID"),
        ("name", "String", "商品名称"),
        ("subtitle", "String", "副标题"),
        ("mainImage", "String", "主图"),
        ("price", "Integer", "最低价（分）"),
        ("originalPrice", "Integer", "原价（分）"),
        ("sales", "Integer", "销量"),
        ("detail", "String", "商品详情富文本"),
        ("status", "Integer", "1 上架 0 下架"),
        ("deleted", "Integer", "逻辑删除"),
        ("createdAt", "LocalDateTime", ""),
        ("updatedAt", "LocalDateTime", ""),
    ]),
    "ProductSku": ("t_product_sku", [
        ("productId", "Long", "SPU ID"),
        ("specs", "String", "规格 JSON"),
        ("price", "Integer", "售价（分）"),
        ("stock", "Integer", "库存"),
        ("image", "String", "SKU 图"),
        ("deleted", "Integer", "逻辑删除"),
    ]),
    "CartItem": ("t_cart_item", [
        ("userId", "Long", "用户 ID"),
        ("skuId", "Long", "SKU ID"),
        ("quantity", "Integer", "数量"),
        ("selected", "Integer", "是否选中 0/1"),
        ("deleted", "Integer", "逻辑删除"),
        ("createdAt", "LocalDateTime", ""),
        ("updatedAt", "LocalDateTime", ""),
    ]),
    "Order": ("t_order", [
        ("orderNo", "String", "订单编号"),
        ("userId", "Long", "用户 ID"),
        ("totalAmount", "Integer", "商品总额（分）"),
        ("payAmount", "Integer", "实付金额（分）"),
        ("addressSnapshot", "String", "地址快照 JSON"),
        ("remark", "String", "订单备注"),
        ("status", "Integer", "0 待付款 1 待发货 2 待收货 3 已完成 4 已取消 5 退款中 6 已退款"),
        ("payTime", "LocalDateTime", "支付时间"),
        ("shipTime", "LocalDateTime", "发货时间"),
        ("finishTime", "LocalDateTime", "完成时间"),
        ("deleted", "Integer", "逻辑删除"),
        ("createdAt", "LocalDateTime", ""),
        ("updatedAt", "LocalDateTime", ""),
    ]),
    "OrderItem": ("t_order_item", [
        ("orderId", "Long", "订单 ID"),
        ("skuId", "Long", "SKU ID"),
        ("productId", "Long", "SPU ID"),
        ("price", "Integer", "成交价（分）"),
        ("quantity", "Integer", "数量"),
        ("productSnapshot", "String", "商品快照 JSON"),
    ]),
    "Banner": ("t_banner", [
        ("image", "String", "轮播图"),
        ("linkType", "String", "跳转类型"),
        ("linkValue", "String", "跳转目标"),
        ("sort", "Integer", "排序"),
    ]),
    "Review": ("t_review", [
        ("orderItemId", "Long", "订单明细 ID"),
        ("userId", "Long", "用户 ID"),
        ("skuId", "Long", "SKU ID"),
        ("rating", "Integer", "评分 1-5"),
        ("content", "String", "评价内容"),
        ("images", "String", "图片 JSON"),
        ("createdAt", "LocalDateTime", ""),
    ]),
    "Favorite": ("t_favorite", [
        ("userId", "Long", "用户 ID"),
        ("skuId", "Long", "SKU ID"),
        ("createdAt", "LocalDateTime", ""),
    ]),
    "Footprint": ("t_footprint", [
        ("userId", "Long", "用户 ID"),
        ("skuId", "Long", "SKU ID"),
        ("viewedAt", "LocalDateTime", "浏览时间"),
    ]),
}

LOGIN_REQUEST = '''package com.harmonymall.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 登录请求
 */
public class LoginRequest {

    @NotBlank(message = "账号不能为空")
    private String username;

    @NotBlank(message = "密码不能为空")
    private String password;

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
'''

REGISTER_REQUEST = '''package com.harmonymall.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 注册请求
 */
public class RegisterRequest {

    @NotBlank(message = "账号不能为空")
    private String username;

    @NotBlank(message = "密码不能为空")
    private String password;

    @NotBlank(message = "手机号不能为空")
    private String phone;

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }
}
'''

CART_ADD_REQUEST = '''package com.harmonymall.dto;

import jakarta.validation.constraints.NotNull;

/**
 * 加入购物车请求
 */
public class CartAddRequest {

    @NotNull(message = "skuId 不能为空")
    private Long skuId;

    @NotNull(message = "数量不能为空")
    private Integer quantity;

    public Long getSkuId() {
        return skuId;
    }

    public void setSkuId(Long skuId) {
        this.skuId = skuId;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }
}
'''

CART_UPDATE_REQUEST = '''package com.harmonymall.dto;

/**
 * 修改购物车请求（数量 / 选中态）
 */
public class CartUpdateRequest {

    private Integer quantity;
    private Integer selected;

    public Integer getQuantity() {
        return quantity;
    }

    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }

    public Integer getSelected() {
        return selected;
    }

    public void setSelected(Integer selected) {
        this.selected = selected;
    }
}
'''

ORDER_CREATE_REQUEST = '''package com.harmonymall.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/**
 * 创建订单请求
 */
public class OrderCreateRequest {

    @NotEmpty(message = "请选择要结算的商品")
    private List<Long> cartIds;

    @NotNull(message = "请选择收货地址")
    private Long addressId;

    private String remark;

    public List<Long> getCartIds() {
        return cartIds;
    }

    public void setCartIds(List<Long> cartIds) {
        this.cartIds = cartIds;
    }

    public Long getAddressId() {
        return addressId;
    }

    public void setAddressId(Long addressId) {
        this.addressId = addressId;
    }

    public String getRemark() {
        return remark;
    }

    public void setRemark(String remark) {
        this.remark = remark;
    }
}
'''

REVIEW_REQUEST = '''package com.harmonymall.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * 发表评价请求
 */
public class ReviewRequest {

    @NotNull(message = "skuId 不能为空")
    private Long skuId;

    @NotNull(message = "评分不能为空")
    @Min(value = 1, message = "评分最低 1 星")
    @Max(value = 5, message = "评分最高 5 星")
    private Integer rating;

    @NotNull(message = "评价内容不能为空")
    private String content;

    public Long getSkuId() {
        return skuId;
    }

    public void setSkuId(Long skuId) {
        this.skuId = skuId;
    }

    public Integer getRating() {
        return rating;
    }

    public void setRating(Integer rating) {
        this.rating = rating;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }
}
'''

CART_VO = '''package com.harmonymall.dto;

import lombok.Data;

/**
 * 购物车视图对象（含商品信息）
 */
@Data
public class CartVO {

    private Long id;
    private Long skuId;
    private Long productId;
    private String productName;
    private String image;
    private String specs;
    private Integer price;
    private Integer quantity;
    private Integer selected;
}
'''

ORDER_VO = '''package com.harmonymall.dto;

import com.harmonymall.entity.OrderItem;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 订单详情视图对象（含明细）
 */
@Data
public class OrderVO {

    private Long id;
    private String orderNo;
    private Long userId;
    private Integer totalAmount;
    private Integer payAmount;
    private String addressSnapshot;
    private String remark;
    private Integer status;
    private LocalDateTime payTime;
    private LocalDateTime createdAt;
    private List<OrderItem> items;
}
'''

PROFILE_REQUEST = '''package com.harmonymall.dto;

/**
 * 修改个人信息请求
 */
public class ProfileRequest {

    private String nickname;
    private String avatar;
    private String phone;

    public String getNickname() {
        return nickname;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public String getAvatar() {
        return avatar;
    }

    public void setAvatar(String avatar) {
        this.avatar = avatar;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }
}
'''

DATA_SQL = '''-- =============================================================
-- HarmonyMall 鸿蒙商城 · 种子数据（演示账号 zhangsan / 123456）
-- =============================================================
USE harmonymall;
SET NAMES utf8mb4;

-- 演示用户
INSERT INTO t_user (id, username, password, phone, nickname, avatar) VALUES
(1, 'zhangsan', '__BCRYPT__', '13800000000', '小张', '/img/avatar.png');

-- 商品分类（一级 4 个 + 二级 10 个）
INSERT INTO t_category (id, parent_id, name, level, icon, sort) VALUES
(1, 0, '数码', 1, '', 1),
(2, 0, '服饰', 1, '', 2),
(3, 0, '家居', 1, '', 3),
(4, 0, '文创', 1, '', 4),
(5, 1, '耳机音响', 2, '', 1),
(6, 1, '智能穿戴', 2, '', 2),
(7, 1, '电脑外设', 2, '', 3),
(8, 2, '上衣', 2, '', 1),
(9, 2, '外套', 2, '', 2),
(10, 2, '鞋靴', 2, '', 3),
(11, 3, '厨房用品', 2, '', 1),
(12, 3, '灯具照明', 2, '', 2),
(13, 3, '生活电器', 2, '', 3),
(14, 4, '文具', 2, '', 1);

-- 首页轮播图
INSERT INTO t_banner (id, image, link_type, link_value, sort) VALUES
(1, '/img/banner/b1.png', 'product', '1', 1),
(2, '/img/banner/b2.png', 'product', '4', 2),
(3, '/img/banner/b3.png', 'product', '8', 3);

-- 商品 SPU（10 个）
INSERT INTO t_product (id, category_id, name, subtitle, main_image, price, original_price, sales, detail, status) VALUES
(1, 5, '轻音真无线蓝牙耳机', '主动降噪 · 30 小时续航 · 半入耳设计', '/img/products/p1.png', 39900, 49900, 1286, '<h2>轻音真无线蓝牙耳机</h2><p>半入耳式人体工学设计，单耳仅 3.8g，久戴不累。内置 13mm 动圈单元与主动降噪芯片，通勤、办公、运动全场景适配。</p><p>配合充电盒可实现 30 小时综合续航，充电 10 分钟，畅听 2 小时。</p><img src="/img/products/p1.png"/>', 1),
(2, 6, '悦动智能手表 GT', '血氧心率监测 · 50 米防水 · 14 天续航', '/img/products/p2.png', 89900, 109900, 986, '<h2>悦动智能手表 GT</h2><p>1.43 英寸 AMOLED 高清圆屏，支持血氧、心率、睡眠全天候监测，内置 100+ 运动模式。</p><p>5ATM 级防水，游泳冲浪无需摘下；典型使用场景续航 14 天。</p><img src="/img/products/p2.png"/>', 1),
(3, 7, '序章 87 键机械键盘', 'Gasket 结构 · 三模连接 · 全键热插拔', '/img/products/p3.png', 34900, 42900, 1532, '<h2>序章 87 键机械键盘</h2><p>Gasket 结构搭配五层消音填充，敲击声音干净利落。支持蓝牙 / 2.4G / 有线三模连接，全键无冲热插拔，随心换轴。</p><img src="/img/products/p3.png"/>', 1),
(4, 8, '云朵重磅连帽卫衣', '420g 重磅纯棉 · 落肩宽松版型', '/img/products/p4.png', 15900, 19900, 2310, '<h2>云朵重磅连帽卫衣</h2><p>420g 重磅纯棉面料，厚实不透，落肩宽松版型不挑身材。罗纹收口，多次水洗不易变形。</p><img src="/img/products/p4.png"/>', 1),
(5, 9, '复古水洗牛仔外套', '经典短款版型 · 12oz 丹宁', '/img/products/p5.png', 32900, 39900, 876, '<h2>复古水洗牛仔外套</h2><p>12oz 丹宁布，中度水洗做旧工艺，经典短款版型。铜扣与撞钉细节，随穿着时间形成专属色落。</p><img src="/img/products/p5.png"/>', 1),
(6, 10, '逐风轻跑鞋 2 代', '超临界发泡中底 · 单只 210g', '/img/products/p6.png', 45900, 52900, 654, '<h2>逐风轻跑鞋 2 代</h2><p>超临界发泡中底，回弹率提升 30%；一体织飞织鞋面透气贴合，单只仅 210g，适合日常训练与长距离慢跑。</p><img src="/img/products/p6.png"/>', 1),
(7, 11, '山间手作陶瓷马克杯', '日式粗陶 · 350ml 大容量', '/img/products/p7.png', 4900, 6900, 4520, '<h2>山间手作陶瓷马克杯</h2><p>日式粗陶质感，杯口外翻弧度贴合唇形，350ml 大容量适合咖啡与燕麦。可进洗碗机与微波炉。</p><img src="/img/products/p7.png"/>', 1),
(8, 12, '折纸极简台灯', '无极调光 · 护眼无频闪 · Type-C 供电', '/img/products/p8.png', 12900, 16900, 1105, '<h2>折纸极简台灯</h2><p>折纸造型灯罩，光线经漫反射均匀铺开，国 AA 级照度，无频闪护眼。触控无极调光，Type-C 供电可接充电宝。</p><img src="/img/products/p8.png"/>', 1),
(9, 13, '雾道静音香薰加湿器', '3L 大水箱 · 25dB 静音 · 缺水断电', '/img/products/p9.png', 9900, 13900, 2870, '<h2>雾道静音香薰加湿器</h2><p>3L 上加水水箱，一次加湿 24 小时。25dB 睡眠级静音，缺水自动断电，可滴入精油作为香薰扩香使用。</p><img src="/img/products/p9.png"/>', 1),
(10, 14, '笔墨纸砚文具礼盒', '钢笔 + 墨囊 + 手账本 + 书签', '/img/products/p10.png', 8900, 11900, 1930, '<h2>笔墨纸砚文具礼盒</h2><p>含暗尖钢笔一支、墨囊 10 枚、布面手账本一册、金属书签两枚。礼盒包装，自用送礼两相宜。</p><img src="/img/products/p10.png"/>', 1);

-- 商品 SKU（26 个）
INSERT INTO t_product_sku (id, product_id, specs, price, stock, image) VALUES
(1, 1, '{"颜色":"皓月白"}', 39900, 200, '/img/products/p1.png'),
(2, 1, '{"颜色":"曜石黑"}', 39900, 150, '/img/products/p1.png'),
(3, 1, '{"颜色":"雾霭蓝"}', 42900, 80, '/img/products/p1.png'),
(4, 2, '{"颜色":"午夜黑","表带":"氟橡胶"}', 89900, 120, '/img/products/p2.png'),
(5, 2, '{"颜色":"晨雾金","表带":"真皮"}', 99900, 60, '/img/products/p2.png'),
(6, 3, '{"颜色":"冰川白","轴体":"线性轴"}', 34900, 180, '/img/products/p3.png'),
(7, 3, '{"颜色":"曜石黑","轴体":"段落轴"}', 36900, 90, '/img/products/p3.png'),
(8, 3, '{"颜色":"马卡龙","轴体":"线性轴"}', 37900, 60, '/img/products/p3.png'),
(9, 4, '{"颜色":"米杏","尺码":"M"}', 15900, 300, '/img/products/p4.png'),
(10, 4, '{"颜色":"米杏","尺码":"L"}', 15900, 280, '/img/products/p4.png'),
(11, 4, '{"颜色":"米杏","尺码":"XL"}', 16900, 120, '/img/products/p4.png'),
(12, 5, '{"颜色":"复古蓝","尺码":"M"}', 32900, 150, '/img/products/p5.png'),
(13, 5, '{"颜色":"复古蓝","尺码":"L"}', 32900, 160, '/img/products/p5.png'),
(14, 5, '{"颜色":"复古蓝","尺码":"XL"}', 33900, 90, '/img/products/p5.png'),
(15, 6, '{"颜色":"白蓝","尺码":"40"}', 45900, 100, '/img/products/p6.png'),
(16, 6, '{"颜色":"白蓝","尺码":"41"}', 45900, 120, '/img/products/p6.png'),
(17, 6, '{"颜色":"白蓝","尺码":"42"}', 45900, 80, '/img/products/p6.png'),
(18, 6, '{"颜色":"全黑","尺码":"42"}', 47900, 40, '/img/products/p6.png'),
(19, 7, '{"颜色":"奶白"}', 4900, 400, '/img/products/p7.png'),
(20, 7, '{"颜色":"苔绿"}', 4900, 260, '/img/products/p7.png'),
(21, 8, '{"颜色":"暖白"}', 12900, 180, '/img/products/p8.png'),
(22, 8, '{"颜色":"原木"}', 13900, 90, '/img/products/p8.png'),
(23, 9, '{"颜色":"云雾白"}', 9900, 220, '/img/products/p9.png'),
(24, 9, '{"颜色":"藕粉"}', 9900, 150, '/img/products/p9.png'),
(25, 10, '{"规格":"标准礼盒"}', 8900, 200, '/img/products/p10.png'),
(26, 10, '{"规格":"豪华礼盒"}', 12900, 80, '/img/products/p10.png');

-- 用户优惠券
INSERT INTO t_user_coupon (user_id, name, amount, threshold, status, expire_time) VALUES
(1, '新人专享券', 1000, 5000, 1, '2027-01-31 23:59:59'),
(1, '数码品类券', 3000, 20000, 1, '2027-01-31 23:59:59');

-- 站内消息
INSERT INTO t_message (user_id, title, content, type) VALUES
(1, '欢迎使用 HarmonyMall', '您的账号已注册成功，快去挑选心仪的商品吧～', 'system'),
(1, '新人礼包已到账', '两张优惠券已放入您的账户，下单时记得使用。', 'coupon');

-- 收藏 / 足迹示例
INSERT INTO t_favorite (user_id, sku_id) VALUES (1, 1), (1, 21);
INSERT INTO t_footprint (user_id, sku_id) VALUES (1, 1), (1, 4), (1, 21);

-- 商品评价示例
INSERT INTO t_review (order_item_id, user_id, sku_id, rating, content) VALUES
(1, 1, 1, 5, '音质清晰，佩戴舒适，续航给力！'),
(1, 1, 2, 5, '黑色质感很好，开盖即连很方便。'),
(1, 1, 19, 4, '杯子做工扎实，粗陶质感很治愈。');
'''


def main():
    print("[part2] writing entities, mappers, dtos ...")
    for name, (table, fields) in ENTITIES.items():
        w(JAVA_BASE + "/entity/" + name + ".java", entity(name, table, fields))
        w(JAVA_BASE + "/mapper/" + name + "Mapper.java", mapper(name + "Mapper", name))

    w(JAVA_BASE + "/dto/LoginRequest.java", LOGIN_REQUEST)
    w(JAVA_BASE + "/dto/RegisterRequest.java", REGISTER_REQUEST)
    w(JAVA_BASE + "/dto/CartAddRequest.java", CART_ADD_REQUEST)
    w(JAVA_BASE + "/dto/CartUpdateRequest.java", CART_UPDATE_REQUEST)
    w(JAVA_BASE + "/dto/OrderCreateRequest.java", ORDER_CREATE_REQUEST)
    w(JAVA_BASE + "/dto/ReviewRequest.java", REVIEW_REQUEST)
    w(JAVA_BASE + "/dto/CartVO.java", CART_VO)
    w(JAVA_BASE + "/dto/OrderVO.java", ORDER_VO)
    w(JAVA_BASE + "/dto/ProfileRequest.java", PROFILE_REQUEST)

    hash_value = bcrypt_hash()
    data_sql = DATA_SQL.replace("__BCRYPT__", hash_value if hash_value else "")
    if not hash_value:
        print("  WARN: bcrypt unavailable, demo user password empty")
    w("src/main/resources/db/data.sql", data_sql)
    print("[part2] done")


if __name__ == "__main__":
    main()
