# -*- coding: utf-8 -*-
"""生成《系统设计文档》配图（浅色主题 SVG）。

输出目录：鸿蒙商城/设计图/*.svg
运行：python gen_diagrams.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "设计图"))
FONT = "Microsoft YaHei, PingFang SC, Segoe UI, sans-serif"

# 调色板（与文档 HTML 主题一致）
BLUE = "#2563eb"
BLUE_D = "#1e3a8a"
BLUE_BG = "#eaf0fb"
GRAY = "#475569"
GRAY_L = "#94a3b8"
INK = "#1f2328"
LINE = "#cbd5e1"
AMBER = "#f59e0b"
AMBER_D = "#92400e"
AMBER_BG = "#fff7ed"
GREEN = "#16a34a"
GREEN_BG = "#ecfdf5"
RED = "#dc2626"
SLATE_BG = "#f1f5f9"


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def head(w, h):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
        f'viewBox="0 0 {w} {h}" font-family="{FONT}">\n'
        '<defs>'
        '<marker id="arr" markerWidth="9" markerHeight="7" refX="8" refY="3.5" orient="auto">'
        f'<path d="M0,0 L9,3.5 L0,7 z" fill="{GRAY}"/></marker>'
        '<marker id="arrb" markerWidth="9" markerHeight="7" refX="8" refY="3.5" orient="auto">'
        f'<path d="M0,0 L9,3.5 L0,7 z" fill="{BLUE}"/></marker>'
        '<marker id="arro" markerWidth="9" markerHeight="7" refX="8" refY="3.5" orient="auto">'
        f'<path d="M0,0 L9,3.5 L0,7 z" fill="{AMBER}"/></marker>'
        '<marker id="arrg" markerWidth="9" markerHeight="7" refX="8" refY="3.5" orient="auto">'
        f'<path d="M0,0 L9,3.5 L0,7 z" fill="{GREEN}"/></marker>'
        '</defs>\n'
        f'<rect width="{w}" height="{h}" fill="#ffffff"/>\n'
    )


def panel(x, y, w, h, fill="#f8fafc", stroke=LINE, r=14, sw=1.4):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>\n')


def box(x, y, w, h, title, lines=(), fill=BLUE_BG, stroke=BLUE, tc=BLUE_D,
        lc=GRAY, r=10, ts=14, ls=11, ty=24, ly=44, lh=16):
    s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
         f'fill="{fill}" stroke="{stroke}" stroke-width="1.4"/>\n')
    s += (f'<text x="{x + w / 2}" y="{y + ty}" text-anchor="middle" font-size="{ts}" '
          f'font-weight="bold" fill="{tc}">{esc(title)}</text>\n')
    for i, ln in enumerate(lines):
        s += (f'<text x="{x + w / 2}" y="{y + ly + i * lh}" text-anchor="middle" '
              f'font-size="{ls}" fill="{lc}">{esc(ln)}</text>\n')
    return s


def path(pts, color=GRAY, marker="arr", dash=None, sw=1.6):
    d = "M" + " L".join(f"{x},{y}" for x, y in pts)
    s = f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}"'
    if marker:
        s += f' marker-end="url(#{marker})"'
    if dash:
        s += f' stroke-dasharray="{dash}"'
    return s + "/>\n"


def label(x, y, t, size=11, color=GRAY, anchor="middle", bold=False):
    fw = ' font-weight="bold"' if bold else ""
    return (f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}" '
            f'fill="{color}"{fw}>{esc(t)}</text>\n')


def note(x, y, lines, size=10.5, color=GRAY, lh=15, anchor="start"):
    s = ""
    for i, ln in enumerate(lines):
        s += (f'<text x="{x}" y="{y + i * lh}" text-anchor="{anchor}" font-size="{size}" '
              f'fill="{color}">{esc(ln)}</text>\n')
    return s


# ---------------------------------------------------------------- 图1 架构图
def gen_arch():
    w, h = 1040, 700
    s = head(w, h)

    # ---- 客户端层
    s += panel(60, 36, 920, 140)
    s += label(80, 66, "客户端层 · HarmonyOS App（ArkTS / ArkUI 声明式 UI / Stage 模型）",
               size=15, color=BLUE_D, anchor="start", bold=True)
    s += box(80, 84, 280, 76, "页面层 · 19 个页面",
             ["首页 / 分类 / 搜索 / 商品详情", "购物车 / 确认订单 / 订单 / 我的"], ts=13, ls=10.5, ty=22, ly=42, lh=15)
    s += box(380, 84, 280, 76, "公共层",
             ["network：HttpClient + Api（40 接口）", "store：UserStore / AppStorage 登录态"], ts=13, ls=10.5, ty=22, ly=42, lh=15)
    s += box(680, 84, 280, 76, "模型与组件层",
             ["Models：领域对象 + 请求体", "components：EmptyView / LoadingView"], ts=13, ls=10.5, ty=22, ly=42, lh=15)

    # ---- 通信
    s += path([(500, 180), (500, 244)], color=BLUE, marker="arrb")
    s += path([(540, 244), (540, 180)], color=GRAY, marker="arr")
    s += label(560, 204, "REST / JSON over HTTP（请求 ↓ / 响应 ↑）", anchor="start")
    s += label(560, 222, "统一响应 {code, message, data} · JWT Bearer", anchor="start", color=GRAY_L)

    # ---- 服务端层
    s += panel(60, 252, 920, 210, fill=BLUE_BG, stroke="#bfd3f5")
    s += label(80, 282, "服务端层 · Spring Boot 3.5（JDK 17）", size=15, color=BLUE_D, anchor="start", bold=True)
    s += box(80, 300, 280, 88, "Controller × 10", ["40 个 REST 接口", "参数校验 @Valid · userId 注入"], fill="#ffffff")
    s += box(380, 300, 280, 88, "Service × 5", ["业务规则 · 事务边界 @Transactional", "订单 / 购物车 / 商品 / 用户 / 地址"], fill="#ffffff")
    s += box(680, 300, 280, 88, "Mapper × 16（MyBatis-Plus）", ["CRUD + 分页 + 逻辑删除", "原子扣库存 · 条件状态流转 SQL"], fill="#ffffff")
    s += panel(80, 406, 880, 38, fill="#fff8e6", stroke=AMBER, r=8, sw=1.2)
    s += label(520, 430, "横切能力：GlobalExceptionHandler 全局异常 ｜ JwtInterceptor 鉴权 ｜ OrderTask 定时任务（关单 / 退款审核 / 自动收货）",
               size=11.5, color=AMBER_D)

    # ---- 存储
    s += path([(500, 462), (500, 514)], color=GRAY, marker="arr")
    s += label(560, 484, "JDBC（MyBatis-Plus）· Redis 客户端", anchor="start")

    s += panel(60, 520, 920, 140)
    s += label(80, 550, "数据层与静态资源", size=15, color=BLUE_D, anchor="start", bold=True)
    s += box(80, 568, 280, 76, "MySQL 8 · harmonymall",
             ["16 张表（用户/商品/订单/券…）", "utf8mb4 · 金额存“分” · 逻辑删除"], fill="#ffffff", ts=13, ls=10.5, ty=22, ly=42, lh=15)
    s += box(380, 568, 280, 76, "Redis",
             ["商品详情缓存（TTL 30min）", "下单幂等令牌 order:token:*"], fill="#ffffff", ts=13, ls=10.5, ty=22, ly=42, lh=15)
    s += box(680, 568, 280, 76, "静态资源 /img/**",
             ["商品图 97 张 · 横幅 7 张 · 头像", "WebMvc 根路径直接托管"], fill="#ffffff", ts=13, ls=10.5, ty=22, ly=42, lh=15)

    s += "</svg>\n"
    return s


# ---------------------------------------------------------------- 图2 ER 图
def gen_er():
    w, h = 1150, 620
    s = head(w, h)
    s += label(40, 30, "核心实体关系（16 张表中 12 张核心表；其余 4 张独立表见注释）",
               size=13, color=INK, anchor="start", bold=True)

    X = [40, 280, 520, 760, 1000]
    BW, BH = 170, 95
    Y1, Y2, Y3 = 60, 300, 480

    def eb(x, y, title, lines, accent=BLUE):
        fill = BLUE_BG if accent == BLUE else "#ffffff"
        tc = BLUE_D if accent == BLUE else INK
        return box(x, y, BW, BH, title, lines, fill=fill, stroke=accent if accent != BLUE else BLUE,
                   tc=tc, r=9, ts=12.5, ls=10, ty=20, ly=38, lh=14)

    # Row1 主干
    s += eb(X[0], Y1, "t_user 用户", ["username 唯一", "password(BCrypt)", "nickname / avatar"])
    s += eb(X[1], Y1, "t_order 订单", ["order_no / user_id", "status / 三金额", "cancel·refund_reason"])
    s += eb(X[2], Y1, "t_order_item 明细", ["order_id / sku_id", "price / quantity", "product_snapshot"])
    s += eb(X[3], Y1, "t_product_sku", ["product_id", "specs / price / stock", "image"])
    s += eb(X[4], Y1, "t_product SPU", ["category_id / name", "price / sales / status", "detail 富文本"])
    # Row2
    s += eb(X[0], Y2, "t_address 地址", ["user_id / receiver", "省市区 + detail", "is_default"])
    s += eb(X[1], Y2, "t_cart_item 购物车", ["user_id / sku_id", "quantity / selected", "(user,sku) 去重合并"])
    s += eb(X[2], Y2, "t_favorite 收藏", ["user_id / sku_id", "created_at"])
    s += eb(X[3], Y2, "t_review 评价", ["order_item_id", "user_id / rating", "content / images"])
    s += eb(X[4], Y2, "t_category 分类", ["parent_id（树）", "name / level(1,2)", "icon / sort"])
    # Row3
    s += eb(X[0], Y3, "t_user_coupon", ["user_id / coupon_id", "status(1 未用 0 已用)", "expire_time / used_at"])
    s += eb(X[1], Y3, "t_coupon 券模板", ["amount / threshold", "total / claimed", "valid_days"])

    # 连线（核心链，蓝）
    s += path([(210, 107), (276, 107)], color=BLUE, marker="arrb")
    s += label(243, 99, "1:n", color=BLUE)
    s += path([(450, 107), (516, 107)], color=BLUE, marker="arrb")
    s += label(483, 99, "1:n", color=BLUE)
    s += path([(690, 107), (756, 107)], color=BLUE, marker="arrb")
    s += label(723, 99, "n:1", color=BLUE, anchor="middle")
    s += path([(930, 107), (996, 107)], color=BLUE, marker="arrb")
    s += label(963, 99, "n:1", color=BLUE)
    s += path([(1085, 155), (1085, 296)], color=BLUE, marker="arrb")
    s += label(1093, 230, "n:1", color=BLUE, anchor="start")

    # user 的资产关系（灰）
    s += path([(85, 155), (85, 296)], color=GRAY_L, marker="arr")
    s += label(78, 228, "1:n", color=GRAY, anchor="end")
    s += path([(165, 155), (165, 240), (365, 240), (365, 296)], color=GRAY_L, marker="arr")
    s += label(262, 232, "1:n", color=GRAY)
    s += path([(40, 130), (22, 130), (22, 430), (605, 430), (605, 395)], color=GRAY_L, marker="arr")
    s += label(315, 422, "1:n", color=GRAY)
    s += path([(40, 145), (30, 145), (30, 455), (125, 455), (125, 476)], color=GRAY_L, marker="arr")
    s += label(78, 447, "1:n", color=GRAY)
    s += path([(210, 527), (276, 527)], color=GRAY_L, marker="arr")
    s += label(243, 519, "n:1", color=GRAY)

    # 跨行引用（虚线斜线）
    s += path([(415, 300), (800, 155)], color=GRAY, marker="arr", dash="5,4")
    s += label(760, 172, "n:1", color=GRAY, anchor="start")
    s += path([(760, 300), (605, 155)], color=GRAY, marker="arr", dash="5,4")
    s += label(730, 252, "n:1", color=GRAY, anchor="start")

    # 独立表注释
    s += panel(520, 480, 590, 95, fill="#ffffff", stroke=LINE, r=10)
    s += label(545, 512, "独立表（无外键关联）", size=12, color=INK, anchor="start", bold=True)
    s += note(545, 534, ["t_footprint 浏览足迹 · t_message 站内消息 · t_banner 首页轮播 · t_search_keyword 搜索热词",
                         "金额单位：分（INT）｜逻辑删除：deleted 0/1（全表）"], size=10, color=GRAY, lh=18)

    s += "</svg>\n"
    return s


# ---------------------------------------------------------------- 图3 订单状态机
def gen_statemachine():
    w, h = 960, 560
    s = head(w, h)
    s += label(40, 32, "订单状态机（status：0~6）", size=14, color=INK, anchor="start", bold=True)

    def st(x, y, t, fill, stroke, tc):
        return box(x, y, 160, 64, t, fill=fill, stroke=stroke, tc=tc, r=12, ts=14)

    s += st(380, 50, "0 · 待付款", BLUE_BG, BLUE, BLUE_D)
    s += st(380, 170, "1 · 待发货", BLUE_BG, BLUE, BLUE_D)
    s += st(380, 290, "2 · 待收货", BLUE_BG, BLUE, BLUE_D)
    s += st(380, 410, "3 · 已完成", GREEN_BG, GREEN, "#14532d")
    s += st(120, 170, "4 · 已取消", SLATE_BG, GRAY_L, "#475569")
    s += st(700, 230, "5 · 退款中", AMBER_BG, AMBER, AMBER_D)
    s += st(700, 380, "6 · 已退款", GREEN_BG, GREEN, "#14532d")

    s += path([(460, 114), (460, 166)], color=BLUE, marker="arrb")
    s += label(474, 144, "支付", color=BLUE_D, anchor="start")

    s += path([(460, 234), (460, 286)], color=BLUE, marker="arrb")
    s += label(474, 264, "模拟商家发货", color=BLUE_D, anchor="start")

    s += path([(460, 354), (460, 406)], color=BLUE, marker="arrb")
    s += label(474, 384, "确认收货 / 发货超 7 天自动", color=BLUE_D, anchor="start")

    s += path([(380, 90), (200, 90), (200, 166)], color=GRAY, marker="arr")
    s += label(290, 80, "取消 / 超时 30 分钟自动", color=GRAY)

    s += path([(540, 202), (780, 202), (780, 226)], color=GRAY, marker="arr")
    s += label(662, 192, "申请退款", color=GRAY)

    s += path([(540, 322), (660, 322), (660, 262), (696, 262)], color=GRAY, marker="arr")
    s += label(600, 344, "申请退款", color=GRAY)

    s += path([(780, 294), (780, 376)], color=AMBER, marker="arro")
    s += label(794, 340, "商家审核通过（定时任务）", color=AMBER_D, anchor="start")

    s += label(200, 262, "回滚库存 / 销量 / 券", size=10.5, color=GRAY)
    s += label(780, 468, "回滚库存 / 销量 / 券", size=10.5, color=GRAY)

    s += "</svg>\n"
    return s


# ---------------------------------------------------------------- 图4 下单流程
def gen_create_order():
    w, h = 880, 810
    s = head(w, h)
    s += label(40, 30, "POST /api/orders —— 事务内多步校验与写入，任一环节失败整单回滚（@Transactional）",
               size=13, color=INK, anchor="start", bold=True)

    MX, MW = 90, 470
    FX, FW = 610, 240
    BH = 52

    def node(y, t, fill=BLUE_BG, stroke=BLUE, tc=BLUE_D):
        return box(MX, y, MW, BH, t, (), fill=fill, stroke=stroke, tc=tc, r=10, ts=13, ty=31)

    def fail(y, t):
        return box(FX, y, FW, BH, t, (), fill=AMBER_BG, stroke=AMBER, tc=AMBER_D, r=10, ts=12, ty=31)

    s += node(40, "① 提交订单（端上生成 clientToken）")
    s += node(130, "② 幂等检查：Redis setIfAbsent(order:token)")
    s += node(220, "③ 校验购物车项与地址归属")
    s += node(310, "④ 逐项原子扣库存：stock = stock - qty，WHERE stock ≥ qty")
    s += node(400, "⑤ 优惠券校验 + 条件锁定（status 1→0）")
    s += node(490, "⑥ 生成订单与明细，原子累加销量")
    s += node(580, "⑦ 删除已结算购物车项")
    s += node(670, "⑧ 下单成功，返回订单（status=0 待付款）", fill=GREEN_BG, stroke=GREEN, tc="#14532d")

    s += fail(130, "已提交过 → 拒绝「请勿重复操作」")
    s += fail(220, "部分项已失效 → 拒绝结算")
    s += fail(310, "受影响行数 = 0 → 「库存不足」")
    s += fail(400, "券不可用 → 拒绝并回滚")

    cx = MX + MW / 2
    for y1, y2 in [(92, 130), (182, 220), (272, 310), (362, 400), (452, 490), (542, 580), (632, 670)]:
        s += path([(cx, y1), (cx, y2)], color=GRAY, marker="arr")

    for y in (130, 220, 310, 400):
        s += path([(MX + MW, y + BH / 2), (FX - 4, y + BH / 2)], color=AMBER, marker="arro", dash="5,4")

    s += label(440, 762, "任一环节失败 → 事务回滚：库存 / 销量 / 优惠券 / 订单全部不落库",
               size=12, color=RED, bold=True)
    s += label(440, 784, "并发下「④ 条件更新」「⑤ 条件锁定」由数据库行级互斥保证不会超卖、不会一券两单",
               size=11, color=GRAY)

    s += "</svg>\n"
    return s


# ---------------------------------------------------------------- 图5 退款流程
def gen_refund():
    w, h = 880, 790
    s = head(w, h)
    s += label(40, 30, "退款流程（两步走：申请 → 退款中 → 已退款）", size=13, color=INK, anchor="start", bold=True)

    MX, MW = 200, 480
    cx = MX + MW / 2
    BH = 52

    def node(y, t, fill=BLUE_BG, stroke=BLUE, tc=BLUE_D):
        return box(MX, y, MW, BH, t, (), fill=fill, stroke=stroke, tc=tc, r=10, ts=13, ty=31)

    s += node(50, "用户选择退款原因（端上弹层）")
    s += node(130, "POST /api/orders/{id}/refund")
    s += node(210, "条件更新：status 1/2 → 5 退款中（记录退款原因）")
    s += node(290, "端上显示「退款中」", fill=AMBER_BG, stroke=AMBER, tc=AMBER_D)

    for y1, y2 in [(102, 130), (182, 210), (262, 290)]:
        s += path([(cx, y1), (cx, y2)], color=GRAY, marker="arr")

    s += path([(60, 380), (820, 380)], color=LINE, dash="6,5", marker=None)
    s += label(820, 370, "OrderTask · 每 20 秒扫描一次", size=11.5, color=AMBER_D, anchor="end")

    s += node(420, "扫描全部「退款中」订单（模拟商家审核）")
    s += node(500, "条件更新：status 5 → 6 已退款（记录退款时间）")
    s += node(580, "回滚库存 / 销量 / 优惠券")
    s += node(660, "端上显示「已退款 + 退款原因 + 退款时间」", fill=GREEN_BG, stroke=GREEN, tc="#14532d")

    for y1, y2 in [(472, 500), (552, 580), (632, 660)]:
        s += path([(cx, y1), (cx, y2)], color=GRAY, marker="arr")

    s += note(700, 236, ["仅「待发货 / 待收货」", "可申请；重复申请被", "状态守卫拒绝"], size=10, color=GRAY)
    s += note(700, 526, ["条件更新保证一笔", "退款只会被处理一次"], size=10, color=GRAY)

    s += label(440, 752, "「退款中 → 已退款」由后端定时任务自动完成，端上重进页面即可看到最终状态",
               size=11.5, color=GRAY)

    s += "</svg>\n"
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {
        "架构图.svg": gen_arch(),
        "ER图.svg": gen_er(),
        "订单状态机.svg": gen_statemachine(),
        "下单流程.svg": gen_create_order(),
        "退款流程图.svg": gen_refund(),
    }
    for name, content in files.items():
        p = os.path.join(OUT, name)
        with open(p, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"OK {name} ({len(content)} chars)")


if __name__ == "__main__":
    main()
