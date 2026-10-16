# HarmonyMall（鸿蒙商城 · 客户端）

毕业设计《基于 HarmonyOS 的移动电商商城应用》的鸿蒙客户端，ArkTS + ArkUI 声明式 UI + Stage 应用模型。

## 技术栈

| 项 | 说明 |
| --- | --- |
| 系统 | HarmonyOS NEXT（SDK 6.1.1 / API 24） |
| 语言 | ArkTS（`strict` 模式） |
| UI | ArkUI 声明式开发范式 |
| 模型 | Stage 模型（UIAbility） |
| 网络 | `@ohos.net.http` Promise 封装 + JWT Bearer + 40100 自动跳登录 |
| 富文本 | Web 组件加载商品详情 |
| 架构蓝本 | 华为官方《购物商城应用案例》（Stage + 声明式 UI、HAR 分包、一多断点 sm/md/lg） |

## 开发环境

- **DevEco Studio 6.1.1**（本机实测环境，hvigor 6.24.3）
- SDK：`targetSdkVersion` / `compatibleSdkVersion` = **`6.1.1(24)`**（已在 `build-profile.json5` 固定；若你的 DevEco 装的是别的 API，改成对应版本，例如 `5.0.5(17)`）
- hvigor：`hvigor/hvigor-config.json5` 的 `modelVersion` = **`6.1.1`**（需与 DevEco 版本一致，否则 Sync 失败）
- Node：命令行构建需 Node 18+（DevEco 内置亦可）

> ⚠️ **SDK 必须真实存在**：若 `AppData\Local\Huawei\Sdk` 下没有 HarmonyOS SDK，DevEco 会报同步失败。请在 DevEco → Settings → SDK → HarmonyOS 中下载，或把环境变量 `DEVECO_SDK_HOME` 指向有效 SDK 目录。

## 快速开始

### 1. 打开工程

DevEco Studio → Open → 选择 `C:/Users/95108/DevEcoStudioProjects/HarmonyMall`，点击 **Sync Now**。

命令行等价操作（已验证可用）：

```bash
cd C:/Users/95108/DevEcoStudioProjects/HarmonyMall
export DEVECO_SDK_HOME='D:\devecostudio-windows-6.1.1.290\DevEco Studio\sdk'   # 改成你的 SDK 路径
./hvigorw assembleHap --mode module -p product=default -p buildMode=debug
# 产物：entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 2. 配置后端地址（必须）

打开 `entry/src/main/ets/common/AppConfig.ets`，按调试设备选择地址：

**模拟器（推荐流程）**：

1. 双击项目根目录 `rport-for-emulator.bat`，建立"模拟器 → 电脑"的端口转发（模拟器每次重启后需重新执行一次）；
2. 保持默认配置即可（经 hdc 调试通道直达电脑后端）：

```ts
static readonly BASE_URL: string = 'http://127.0.0.1:8080/api';
static readonly IMG_BASE: string = 'http://127.0.0.1:8080';
```

**真机 / Previewer**：手机与电脑连同一 Wi-Fi，把 IP 换成电脑的局域网 IPv4（cmd 执行 `ipconfig` 查看）：

```ts
static readonly BASE_URL: string = 'http://10.240.12.125:8080/api'; // ← 改成你的局域网 IP
static readonly IMG_BASE: string = 'http://10.240.12.125:8080';
```

> 模拟器内部是 QEMU NAT 网络（10.0.2.x 网段），**访问不到电脑的局域网 IP**，所以必须走 hdc 端口转发 + `127.0.0.1`；真机不受此限制。
> 明文 HTTP 已通过 `network_config.json` 显式放行（详见文末"已知说明"），不需要额外配置。

### 3. 启动后端

见后端工程 README（`harmonymall-server/README.md`）：建库 → 执行 `schema.sql` / `data.sql` → `mvn spring-boot:run`。

### 4. 运行

- 连接真机或启动模拟器（Phone），点击 Run；
- 演示账号：`zhangsan` / `123456`（也可注册新账号）。

## 功能清单

| 页面 | 功能 |
| --- | --- |
| IndexPage | 自定义 Tab 容器（首页/分类/购物车/我的） |
| HomePage | 轮播横幅、金刚区分类、推荐商品网格 |
| CategoryPage | 左侧一级分类、右侧按二级分类分组预览商品（每组 3 个缩略图 + "更多"入口），商品懒加载 + 内存缓存 |
| SearchPage | 关键词搜索、历史记录、热门搜索（真实统计，前三标红） |
| DetailPage | 商品图集、SKU 规格选择（自动换行）、库存/售罄、收藏按钮、数量步进、Web 富文本详情、加购/立即购买、左上角返回 |
| CartPage | 列表、自绘勾选、数量修改（库存上限）、删除、售罄置灰、合计结算 |
| LoginPage | 账号密码登录（JWT）、验证码演示 Tab、注册入口 |
| RegisterPage | 新用户注册（账号/手机号/密码校验，注册成功后自动登录） |
| OrderConfirmPage | 确认订单（地址选择、优惠券抵扣、商品快照、幂等提交） |
| OrderListPage | 订单列表、状态 Tab、取消（选原因）、申请退款、去付款、确认收货 |
| OrderDetailPage | 订单详情、待付款倒计时、模拟支付/发货、取消与退款（选原因）、时间字段、评价入口、左上角返回 |
| MePage | 用户信息、订单四状态入口、地址管理、收藏/足迹/优惠券/消息/编辑资料、退出登录 |
| AddressListPage | 地址列表、设默认、删除、选择模式（供确认订单页选用） |
| AddressEditPage | 地址新增/编辑表单 |
| FavoritePage | 我的收藏（取消收藏、进详情） |
| FootprintPage | 浏览足迹（按时间倒序） |
| MessagePage | 消息中心（未读红点、点击已读） |
| CouponPage | 领券中心 + 我的优惠券（未使用/已使用/已过期） |
| ProfileEditPage | 个人资料编辑（昵称/手机号/头像） |

## 目录结构

```
AppScope/
├── app.json5                    # bundleName: com.harmonymall.app
└── resources/base/
    ├── element/                 # string/color
    └── media/app_icon.png       # 应用图标
entry/src/main/
├── module.json5                 # 权限(INTERNET)、图标、明文 HTTP
├── ets/
│   ├── entryability/EntryAbility.ets
│   ├── common/
│   │   ├── AppConfig.ets        # BASE_URL / IMG_BASE / PAGE_SIZE
│   │   ├── network/
│   │   │   ├── HttpClient.ets   # @ohos.net.http Promise 封装、token、40100 跳登录
│   │   │   ├── Api.ets          # 全部接口
│   │   │   └── ApiResponse.ets  # { code, message, data } 统一响应体
│   │   ├── store/UserStore.ets  # AppStorage 登录态
│   │   └── utils/FormatUtil.ets # 金额(分→元)/日期/订单状态/快照解析
│   ├── model/Models.ets         # 领域模型
│   ├── components/              # EmptyView / LoadingView
│   └── pages/                   # 19 个页面
└── resources/base/
    ├── element/                 # color.json / string.json
    └── media/app_icon.png       # entry 模块图标
```

## 页面要点：首页轮播图（HomePage）

- **比例约定 2.8:1**：Swiper 外层容器固定 `aspectRatio(2.8)`，服务端横幅图片已在离线阶段统一归一到 2.8:1，因此端上 `ImageFit.Cover` **不会发生任何裁切**。
- 之前的写法是 `Swiper().height(160)`，与源图 3:1 的比例不符，导致两侧文案被裁掉（曾把一张 800×800 的商品主图当横幅，被裁成一条）。
- 横幅数据要求：宽高比 ≥ 2.2 才算横幅（商品主图是 1:1，不允许入库）；主题需与商城分类对应；`link_type=category` 时点击跳转对应分类商品列表。

## 页面要点：分类页（CategoryPage）

京东/淘宝风格的分类页：左侧一级分类栏，右侧按二级分类分组展示商品。

- **布局要点（都是踩过的坑）**：`Row` 的默认交叉轴对齐是 **`VerticalAlign.Center`**，左右两栏如果不给高度就会被按内容高度居中，上下各空出一大片；`Scroll` 在**内容不足一屏时也会把子组件垂直居中**（文创只有 1 个二级分类时内容明显偏下）。解法：Row 加 `alignItems(VerticalAlign.Top)`、List/Scroll 加 `height('100%')`、Scroll 内的 Column 加 `constraintSize({ minHeight: '100%' })`（最小撑满、超长仍可滚动）。
- **分组展示**：每个二级分类一张卡片（标题 + "更多 >" + 一行 3 个商品缩略图）；缩略图点击进 `DetailPage`，"更多 >"进 `SearchPage`（带 `categoryId`、`name`）。不足 3 个商品时用空位补足，保证三列对齐。
- **懒加载 + 缓存**：只请求当前一级分类下的二级分类商品（`/api/products?categoryId=&page=1&size=3`），已加载的分组切回来不重复请求；缓存放在 `@State previews: SubPreview[]`，**整体替换数组**以触发刷新（ArkUI 只观测第一层变更）。
- **降级表现**：请求中显示骨架屏；失败显示"重试"；该分类无商品显示"暂无商品"。

## 页面要点：详情页的返回按钮（DetailPage / OrderDetailPage）

详情类页面由 `router.pushUrl` 推入，**没有系统标题栏**，必须在页面内自己放返回入口。统一写法：

```ts
// 顶部返回：固定在页面最上方（加载中 / 加载失败时同样可用，避免退不出去）
Row() {
  Text('← 返回')
    .fontSize(15)
    .fontColor('#0A59F7')
    .padding({ top: 9, bottom: 9, right: 16 })   // 扩大点击热区
    .onClick(() => { router.back(); })
}
.width('100%')
.height(40)
.padding({ left: 12, right: 12 })
```

- 与 `LoginPage` / `RegisterPage` / `AddressListPage` / `AddressEditPage` 的返回链接**保持同一套样式**（蓝色 15 号字）。
- **必须放在 `if (loading)` 判断之外**：加载中、加载失败时也要能返回，否则用户会卡在页面上。
- 详情页内容较长，返回栏放在 `Scroll` 之外（不随内容滚动）。

## 页面要点：订单业务流

订单状态机：`0 待付款 → 1 待发货 → 2 待收货 → 3 已完成`，分支 `4 已取消`、`5 退款中 → 6 已退款`。

- **待付款倒计时**：订单详情页按 `createdAt + 30 分钟` 每秒刷新剩余时间（`setInterval` 需在 `aboutToDisappear` 里 `clearInterval`）；到点后由后端 `OrderTask` 关单，端上只做展示。
- **取消 / 退款原因选择**：底部弹层自绘单选圈（`Circle + fill/stroke`），复用「遮罩 + 面板」Stack 结构；**不要用 `@Builder xxx(selected)` 传参**渲染选中态——`@Builder` 参数不参与状态观察，样式不会刷新，必须内联进 `build()` 直接读 `@State`。
- **状态守卫**：端上重复点击由后端「条件更新」兜底（详见后端 README），收到「订单状态已变化」时前端重新 `load()` 即可。
- **退款两步**：申请后订单变「退款中」，后端定时任务模拟商家审核（演示环境约 30 秒内）自动完成退款；端上重新进入详情页即可看到「已退款 + 退款原因 + 退款时间」。

## 网络层说明

- 所有请求经 `HttpClient`（`@ohos.net.http` 的 Promise 封装）；
- 登录成功后 token 存 `AppStorage`，请求自动带 `Authorization: Bearer <token>`；
- 响应 `code = 40100` 时清空登录态并跳转 `LoginPage`；
- 商品图片为后端返回的相对路径，由 `AppConfig.imgUrl()` 补全为绝对地址。

## 已知说明（毕设范围）

- **支付/物流/推送为模拟**：下单后直接调支付接口置为已支付；物流轨迹与消息为预置数据。
- **明文 HTTP**：项目使用 `http://` 访问局域网后端。HarmonyOS NEXT 默认禁止明文流量，已通过 `entry/src/main/resources/base/profile/network_config.json`（`cleartextTrafficPermitted: true`）+ `module.json5` 的 `ohos.net.http.NetworkSecurityConfig` metadata 显式放行（参考本机 HuangheMemory 工程写法）；上线换 HTTPS 后可移除。
- **未做一多断点完整适配**：当前布局为手机优先，平板可运行；官方案例的 sm/md/lg 断点作为论文中的扩展方向。
- **收藏 / 足迹 / 消息 / 优惠券 / 资料编辑**：均已实现（FavoritePage / FootprintPage / MessagePage / CouponPage / ProfileEditPage）。
- **物流与自动确认**：订单详情展示付款/发货/完成/退款时间字段（未单独做物流时间线）；模拟发货后订单进入「待收货」，发货超过 7 天未确认由后端 `OrderTask` 自动确认（演示环境未做实时验证）。

## 常见问题

| 现象 | 原因 / 解决 |
| --- | --- |
| 登录提示网络错误 | `BASE_URL` IP 不对或后端未启动；模拟器请先运行 `rport-for-emulator.bat`；真机需与电脑同网段 |
| 页面一直显示"加载中" | 检查自动加载逻辑是否写在 `aboutToAppear()` 里——ArkUI 生命周期**没有 on 前缀**，写成 `onAboutToAppear` 不报编译错但永远不执行 |
| 图片不显示 | `IMG_BASE` 未配置；检查后端 `static/img` 目录有图 |
| Sync 失败 / 报 hvigor 相关错误 | 检查 `hvigor/hvigor-config.json5` 的 `modelVersion` 是否与 DevEco 版本一致（6.1.1 → `6.1.1`） |
| 编译报缺 SDK 或 `DEVECO_SDK_HOME` 无效 | DevEco → Settings → SDK 下载 HarmonyOS SDK，或设置 `DEVECO_SDK_HOME` 指向 SDK 根目录 |
| 报 `must have one and only one '@Entry'` | `main_pages.json` 中声明的页面必须有且仅有一个 `@Entry`；作为子组件嵌入的页面不要写进该文件 |
| 报 arkts-no-untyped-obj-literals | ArkTS 禁止无类型对象字面量，请求体请用 `Models.ets` 里的 `XxxRequest` 类 |
| 页面内容上下居中 / 旁边一大片空白 | 两个默认行为会"吞掉"高度：① `Row` 默认 `alignItems(VerticalAlign.Center)`，子组件不给高度就按内容高度居中；② `Scroll` 在内容不足一屏时会把子组件垂直居中。解法见"分类页要点" |
| 子组件的回调不生效（如"重试"按钮点了没反应） | 自定义组件里被外部注入的成员**不能声明 `private`**，否则编译器只告警（`Property 'xx' is private and can not be initialized through the component constructor`），运行时静默失效 |
| 登录接口返回成功，但页面仍显示"未登录" | **`AppStorage.set()` 在 key 不存在时什么都不做并返回 false**（SDK 明确语义），登录态是首次写入，必须用 **`AppStorage.setOrCreate()`**，否则 token 静默丢失（`UserStore.saveLogin` 已修正） |
| 登录成功后返回上一页，页面还是"未登录"状态 | 子页面（MePage/CartPage）在 `router.back()` 后不会重建，`aboutToAppear` 不再执行。解法：加 `@StorageProp('token') @Watch('onTokenChange')`，登录态一变就自动刷新 |
| 订单/购物车里规格显示成 `{"规格": "…"}` | 快照里存的是原始 JSON。用 `FormatUtil.specText(raw)` 解析成「值1 / 值2」再展示（非 JSON 内容原样返回） |
| 第二次进同一个商品详情，名称丢失、"已售 undefined" | 后端商品详情缓存被写成了空对象（`JsonUtils` 序列化 `LocalDateTime` 抛异常），详见后端 README「常见问题」；排查命令：`redis-cli get product:detail:<id>`，修复后清缓存 `redis-cli keys "product:detail:*"` 逐个 del |
| 模拟器时间与真机不一致导致 token 失效 | 重新登录即可 |
| 购物车数量改了但界面不刷新 | `@State` 只观测第一层：直接改 `items[i].quantity` 不触发渲染，必须整体替换数组（`replaceItem()`）或用 `@Observed` + `@ObjectLink` |
| 勾选框自动「反向勾选」 | `Checkbox.onChange` 在「按 select 值回填」的路径上也会触发，回调里取反会把服务端状态写反。改用自绘 `Circle + ✓` + `onClick` |
| 小按钮（高度 ≤28vp）文字不显示 | `Button` 的内边距把文字挤没了。改用 `Text` + `textAlign(TextAlign.Center)` + `backgroundColor` 自绘 |
| `Record` 字面量报 arkts-no-untyped-obj-literals | 键必须是带引号的字符串字面量：`{'system': '系统'}`，不能写 `{system: ...}` |
| 自动化点击坐标不生效 / 点击后界面没反应 | 软键盘弹起会让页面整体上移（约 203px），先 `uitest uiInput keyEvent 2` 收起键盘、重新 `dumpLayout` 再定位；坐标是否正确可用「截图文件字节数是否变化」判定 |
