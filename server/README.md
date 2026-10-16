# HarmonyMall Server（鸿蒙商城 · 后端服务）

毕业设计《基于 HarmonyOS 的移动电商商城应用》的后端服务，为鸿蒙客户端提供 REST/JSON 接口。

## 技术栈

| 项 | 版本 / 说明 |
| --- | --- |
| 框架 | Spring Boot 3.5.4 |
| JDK | 17+ |
| ORM | MyBatis-Plus 3.5.7（分页插件、逻辑删除） |
| 数据库 | MySQL 8（库名 `harmonymall`） |
| 缓存 | Redis（商品详情缓存，异常时自动降级查库） |
| 安全 | Spring Security + JWT（jjwt 0.12.6，有效期 24h） |
| 接口文档 | springdoc-openapi 2.6.0（Swagger UI） |
| 构建 | Maven |

## 快速启动

### 1. 环境要求

- JDK 17+
- Maven 3.8+
- MySQL 8 运行中，Redis 运行中

### 2. 初始化数据库

```bash
# 登录 MySQL 后执行：
mysql -u root -p

CREATE DATABASE harmonymall DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE harmonymall;
source C:/Users/95108/IdeaProjects/harmonymall-server/src/main/resources/db/schema.sql;
source C:/Users/95108/IdeaProjects/harmonymall-server/src/main/resources/db/data.sql;
-- 增量补充数据（商品 + 轮播图），在 data.sql 之后执行
source C:/Users/95108/IdeaProjects/harmonymall-server/src/main/resources/db/add_products.sql;
-- 功能增强迁移（优惠券模板/用户券/搜索热词），执行一次即可
source C:/Users/95108/IdeaProjects/harmonymall-server/src/main/resources/db/add_features.sql;
-- 订单业务流迁移（取消原因/退款原因/退款时间），执行一次即可
source C:/Users/95108/IdeaProjects/harmonymall-server/src/main/resources/db/add_order_flow.sql;
```

- `schema.sql`：16 张表（用户、地址、分类、商品、SKU、购物车、订单、订单项、优惠券模板、用户优惠券、收藏、足迹、评价、横幅、消息、搜索热词）
- `data.sql`：**真实演示数据**——17 个分类、4 张横幅、47 个商品、718 个 SKU、优惠券、消息、收藏/足迹/评价（商品数据与图片爬取自网易严选公开接口）
- `add_products.sql`：**增量补充数据**——7 张轮播图、新增 50 个商品（id > 47）及其 SKU；数据同样爬取自网易严选，仅新增、不改动已有业务数据

> **数据规模（当前）**：17 个分类、**97 个商品 / 1404 个 SKU**、7 张轮播图，13 个二级分类下各 5~12 个商品。
> 数据维护脚本见毕设工程 `鸿蒙商城/tools/`：`crawl_products.py`（全量爬取）、`add_products.py`（增量补充，`--no-banners` 可跳过横幅）、`fix_banners.py`（轮播图策展）。

> **轮播图数据约定**：横幅图片统一为 **2.8:1**（客户端 Swiper 用同一比例展示，端上零裁切）；入库前须校验宽高比 ≥ 2.2——商品主图是 1:1，混入横幅位会被裁成一条。图片规格处理在离线脚本里完成（背景平坦的图上下补背景不裁内容，否则从右侧裁、保住左侧文案）。

> 也可放开 `application.yml` 末尾注释的 `spring.sql.init` 配置，由 Spring Boot 自动执行上述两个脚本。

### 3. 修改配置

`src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    username: ${MYSQL_USER:root}        # ← 默认 root，可用环境变量覆盖
    password: ${MYSQL_PASSWORD:123456}  # ← 改成你的 MySQL 密码
```

JWT secret 建议生产环境通过环境变量注入。

### 4. 启动

```bash
cd C:/Users/95108/IdeaProjects/harmonymall-server
mvn spring-boot:run        # 或 java -jar target/harmonymall-server-1.0.0.jar
```

启动后：

| 地址 | 说明 |
| --- | --- |
| http://localhost:8080/ | 欢迎页（项目信息 + 接口一览 + 演示账号） |
| http://localhost:8080/swagger-ui/index.html | Swagger 在线接口文档 |
| http://localhost:8080/img/products/xxx.jpg | 商品图片（静态资源） |

## 演示账号

| 账号 | 密码 | 说明 |
| --- | --- | --- |
| `zhangsan` | `123456` | 预置演示用户（含地址/订单/收藏/足迹数据） |

## 路径设计说明

接口统一 `/api` 前缀，**由各 Controller 的类级 `@RequestMapping("/api/xxx")` 声明**，而非 `server.servlet.context-path`。
这样做是为了让静态资源（`/img/**`）直接挂在根路径下，与数据库中保存的图片路径（`/img/products/item_xxx.jpg`）保持一致，客户端 `IMG_BASE` 只需配到主机名。

## 接口一览

统一响应体：`{ "code": 0, "message": "ok", "data": ... }`（`code = 0` 成功；`20000` 参数错误；`40100` 未登录/登录过期；`40400` 接口不存在；`40500` 请求方法不支持；`50000` 系统异常）。
JWT 通过 `Authorization: Bearer <token>` 传递，由 `JwtInterceptor` 解析后以 `@RequestAttribute("userId")` 注入。

| 模块 | 路径前缀 | 主要接口 |
| --- | --- | --- |
| 认证 | `/api/auth` | `POST /login`、`POST /register` |
| 首页 | `/api/home` | `GET /home`（横幅 + 分类树 + 推荐商品一次返回） |
| 分类 | `/api/categories` | `GET /categories`（一二级分类树） |
| 商品 | `/api/products` | `GET /products?keyword&categoryId&sort&page&size`、`GET /products/{id}`、`GET /products/{id}/reviews`、`GET /hot-keywords`（搜索即统计） |
| 评价 | `/api/reviews` | `POST /reviews`（需登录，校验订单明细归属/已完成/不重复） |
| 购物车 | `/api/cart` | `GET /`、`POST /`（返回购物车项 id）、`PUT /{id}`、`DELETE /{id}` |
| 订单 | `/api/orders` | `POST /`（事务下单：幂等 + 原子扣库存 + 优惠券抵扣）、`GET /?status&page&size`、`GET /{id}`、`POST /{id}/pay\|cancel\|confirm\|ship\|refund`（cancel/refund 可携带 `{"reason":"..."}`） |
| 优惠券 | `/api/coupons` | `GET /`（领券中心）、`POST /{id}/claim`（每人限领一张）、`GET /mine`、`GET /usable?amount=` |
| 地址 | `/api/address` | `GET/POST /`、`PUT/DELETE /{id}`、`PUT /{id}/default` |
| 用户 | `/api/user` | `GET/PUT /profile`、`GET/POST/DELETE /favorites`、`GET /footprints`、`GET /messages`、`PUT /messages/{id}/read` |

## 订单业务逻辑（核心设计）

- **防超卖（原子扣库存）**：下单时库存扣减不用「先查再改」，而是 `UPDATE t_product_sku SET stock = stock - ? WHERE id = ? AND stock >= ?`，以受影响行数判断成败（0 行 = 库存不足 → 抛业务异常、事务回滚）。并发抢购由数据库行级条件天然互斥。**实测**：两个账号并发抢 1 件库存——一人成功、一人被拒「库存不足」，库存不变负。
- **状态机守卫（条件更新）**：所有状态流转（支付/取消/发货/确认/退款）统一写成 `UPDATE ... WHERE id = ? AND status = 旧状态`，用受影响行数判断是否真正生效。重复点击、定时任务与用户操作撞车时只有一方成功，杜绝「库存重复回滚」「一笔订单退两次款」。
- **优惠券防双花**：券锁定用条件更新 `WHERE status = 1 SET status = 0`，并发下单用同一张券时只有一笔能锁定成功。
- **下单幂等**：`clientToken` + Redis `order:token:{userId}:{token}`（`setIfAbsent`，TTL 30 分钟），重复提交直接拒绝；Redis 不可用时降级放行（靠购物车项已删除兜底）。
- **退款两步流程**：`待发货/待收货 → 退款中(5) → 已退款(6)`。申请退款后由 `OrderTask` 模拟商家审核（约 30 秒内）自动完成退款，并回滚库存、销量与优惠券。
- **定时任务（OrderTask）**：① 超时未支付自动取消（默认 30 分钟，`harmonymall.order.timeout-minutes`）；② 模拟商家审核退款；③ 发货 7 天未确认自动收货（`harmonymall.order.auto-confirm-days`）。
- **回滚一致性**：取消 / 退款时库存 `stock = stock + ?`、销量 `sales = sales ± ?` 全部走数据库端原子自增减，避免并发「读-改-写」丢更新。

## 与鸿蒙客户端联调

1. 服务端与手机/模拟器必须在**同一局域网**。
2. 启动后端，查看本机局域网 IP（如 `192.168.1.100`）。
3. 修改客户端 `entry/src/main/ets/common/AppConfig.ets`：

   ```ts
   export const BASE_URL = 'http://192.168.1.100:8080/api';  // 接口地址
   export const IMG_BASE = 'http://192.168.1.100:8080';      // 图片地址（无需 /api）
   ```

4. 客户端图片路径由 `AppConfig.imgUrl()` 拼接：`IMG_BASE + '/img/products/item_xxx.jpg'`，直接访问根路径下的静态资源。

## 商品图片资源

`src/main/resources/static/img/` 下：

- `products/item_{严选ID}.{ext}`：97 张商品主图（按严选商品 ID 命名，重跑爬虫不会错位）
- `banner/banner_{md5}.{ext}`：7 张横幅（已离线统一为 **2.8:1**，与端上轮播位比例一致）
- `avatar.png`：默认头像

数据库中保存的即为相对路径（如 `/img/products/item_1110003.jpg`），客户端 `IMG_BASE + path` 直接可访问，例如 `http://192.168.1.100:8080/img/products/item_1110003.jpg`。

> 图片抓取脚本见毕业设计工作区 `鸿蒙商城/tools/crawl_products.py`（网易严选公开搜索接口）。

## 目录结构

```
src/main/java/com/harmonymall/
├── HarmonyMallApplication.java   # 启动类
├── common/                       # Result/ResultCode/BizException/全局异常/分页
├── config/                       # MyBatis-Plus 分页、WebMvc 拦截器+CORS
├── security/                     # JwtUtil/JwtInterceptor/SecurityConfig
├── entity/                       # 16 个实体（对应 16 张表）
├── mapper/                       # MyBatis-Plus Mapper（含原子扣库存/条件状态流转 SQL）
├── dto/                          # 请求/响应对象
├── service/                      # User/Product(含 Redis 缓存)/Cart/Address/Order(事务下单)/Coupon
├── task/                         # OrderTask 定时任务（超时关单/退款审核/自动收货）
└── controller/                   # Auth/Home/Category/Product/Review/Cart/Order/Address/User/Coupon
src/main/resources/
├── application.yml               # 服务/数据源/Redis/JWT/订单规则 配置
├── db/schema.sql                 # 建表脚本
├── db/data.sql                   # 演示数据（爬虫生成）
├── db/add_products.sql           # 增量商品/横幅数据
├── db/add_features.sql           # 功能增强迁移（优惠券/搜索热词）
├── db/add_order_flow.sql         # 订单业务流迁移（取消/退款原因字段）
└── static/img/                   # 商品图/横幅/头像
```

## 常见问题

| 现象 | 原因 / 解决 |
| --- | --- |
| 同一个商品**第一次**打开详情正常，**第二次**名称丢失、价格区显示空、"已售 undefined" | Redis 缓存的商品详情被写成了空对象 `{}`。根因：`JsonUtils` 里的 `ObjectMapper` 没注册 `JavaTimeModule`，而实体含 `LocalDateTime` 字段，序列化抛异常后被 `catch` 吞掉返回 `"{}"`（已在 `JsonUtils` 注册 `JavaTimeModule` + 禁 `WRITE_DATES_AS_TIMESTAMPS`，并在 `ProductService.getBase` 加"空对象不入缓存"防御） |
| 同上，修复代码前的存量脏缓存 | `redis-cli get product:detail:<id>` 若返回 `{}` 即为脏数据；清掉即可：`redis-cli keys "product:detail:*"` 逐个 `del`（或 `flushdb`，注意本机 Redis 还有别的项目在用） |
| 改完 `application.yml` 或新增 `static/` 图片后不生效 | jar 内配置与静态资源是**构建时快照**，必须重新 `mvn package` 并用新 jar 启动；打包前先停掉占用 jar 的进程（Windows 文件锁：`Unable to rename ...jar`） |
| 命令行启动端口变成 61025 / 启动失败 | 沙箱环境注入了 `SERVER__PORT` 环境变量，Spring Boot relaxed binding 会把它当 `server.port`。启动前 `unset SERVER__PORT SERVER_PORT` 或显式传 `--server.port=8080` |
| `curl` 报 `upstream connect failed` | 走了系统代理，加 `--noproxy '*'` |
| 置空字段（如取消订单退券清 `used_at`）没有生效 | MyBatis-Plus `updateById` 默认忽略 null 字段（NOT_NULL 策略），必须用 `LambdaUpdateWrapper.set(字段, null)` 显式置空；逻辑删除字段 insert 时也应显式 `setDeleted(0)`（否则落 NULL 会被 MP 查询漏掉） |

## 已知说明（毕设范围）

- **支付、物流、推送、商家操作为模拟实现**：支付接口直接置为已支付；「模拟商家发货」「模拟商家审核退款」分别由端上按钮与定时任务驱动（本工程无管理端）；物流轨迹与消息推送为预置/模拟数据。
- **并发安全依赖数据库条件更新**：单库单表场景下已足够（实测防超卖有效）；若上分布式/分库，需升级为 Redis 预扣或分布式锁，作为论文中的延伸讨论。
- **验证码未接入短信网关**：注册/找回密码流程在毕设中以账号密码 + JWT 为主。
- **性能压测未做**：Redis 缓存仅覆盖商品详情热点查询，作为亮点展示。
