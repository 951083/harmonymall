# HarmonyMall · 鸿蒙商城（毕业设计）

基于 **HarmonyOS NEXT** 的移动电商商城应用 —— 客户端（ArkTS / ArkUI）+ 服务端（Spring Boot 3.5）全栈实现，覆盖「浏览 → 搜索 → 加购 → 下单 → 支付 → 订单状态机 → 评价」完整购物闭环。

> 郑州经贸学院 · 计算机科学与技术 · 本科毕业设计

## 目录结构

| 目录 | 内容 |
|---|---|
| [`client/`](client/) | HarmonyOS 客户端：ArkTS + ArkUI 声明式 UI，19 个页面 |
| [`server/`](server/) | Spring Boot 3.5 后端：40 个 REST 接口、MySQL 8 + Redis |
| [`docs/`](docs/) | 毕业设计文档：《需求分析报告》《系统设计文档》（含架构 / ER / 订单状态机等 5 张设计图） |
| [`tools/`](tools/) | 数据维护与文档工具脚本（商品爬取、图表生成等） |

## 功能概览

- **购物闭环**：首页轮播 / 分类 / 搜索（历史 + 热词）→ 商品详情（SKU / 库存 / 收藏 / 评价）→ 购物车 → 确认订单（地址 + 优惠券）→ 支付 → 订单状态机 → 确认收货 → 评价
- **订单状态机**：`0 待付款 → 1 待发货 → 2 待收货 → 3 已完成`，分支 `4 已取消`、`5 退款中 → 6 已退款`；超时未支付自动取消、发货超期自动确认收货
- **账户资产**：收藏 / 浏览足迹 / 优惠券（领券中心 + 下单抵扣 + 取消退券）/ 消息中心 / 地址管理
- **业务亮点**：SQL 条件原子更新防超卖、下单幂等（Redis 令牌）、订单状态机守卫（条件更新 + 影响行数）、优惠券防双花、订单商品/地址快照

## 技术栈

| 端 | 技术 |
|---|---|
| 客户端 | HarmonyOS NEXT（SDK 6.1.1 / API 24）· ArkTS（strict）· ArkUI 声明式 UI · Stage 模型 |
| 服务端 | Spring Boot 3.5（JDK 17）· MyBatis-Plus · MySQL 8 · Redis · JWT（jjwt）· Spring Scheduling |
| 通信 | REST / JSON over HTTP，统一响应体 `{code, message, data}` + JWT Bearer |

## 快速启动

- **后端**：见 [`server/README.md`](server/README.md) —— 建库 → 执行 `db/*.sql` → `mvn spring-boot:run`（演示账号 `zhangsan / 123456`）
- **客户端**：见 [`client/README.md`](client/README.md) —— DevEco Studio 打开 `client/` → Sync → 配置 `AppConfig.ets` 后端地址 → 运行（模拟器联调见 README 的端口转发说明）

## 文档

《需求分析报告》《系统设计文档》见 [`docs/`](docs/)（含系统架构图、数据库 ER 图、订单状态机图、下单 / 退款流程图）。

---

*本项目为个人毕业设计；商品图片与部分数据爬取自公开电商网站，仅供学习交流使用。*
