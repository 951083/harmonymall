import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { webview } from '@kit.ArkWeb';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { Product, ProductSku, Review, SimpleSku } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 商品详情：图集 / 价格 / SKU 规格选择 / 数量 / 评价 / 图文详情 / 加购 / 立即购买
 */
@Entry
@Component
struct DetailPage {

  @State product: Product | null = null;
  @State skus: ProductSku[] = [];
  @State selectedSku: ProductSku | null = null;
  @State quantity: number = 1;
  @State reviews: Review[] = [];
  @State loading: boolean = true;
  @State failed: string = '';
  /** 已收藏的 skuId 列表：详情页的收藏是按 SKU 维度的，切规格要跟着变 */
  @State favoriteSkus: number[] = [];
  private webController: webview.WebviewController = new webview.WebviewController();
  // 登录态变化时重新拉收藏状态（登录/退出后返回本页不会重建）
  @StorageProp('token') @Watch('onTokenChange') token: string = '';

  onTokenChange(): void {
    this.loadFavoriteState();
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    const id: number = params && params['id'] ? Number(params['id']) : 0;
    if (id <= 0) {
      this.loading = false;
      this.failed = '商品不存在';
      return;
    }
    this.load(id);
  }

  async load(id: number): Promise<void> {
    this.loading = true;
    this.failed = '';
    try {
      const detail = await Api.productDetail(id);
      this.product = detail.product;
      this.skus = detail.skus ?? [];
      this.selectedSku = this.skus.length > 0 ? this.skus[0] : null;
      const list: Review[] = await Api.productReviews(id);
      this.reviews = list ?? [];
      if (UserStore.isLogin() && this.selectedSku) {
        Api.addFootprint(this.selectedSku.id).catch(() => { });
      }
      this.webController.loadData(this.detailHtml(), 'text/html', 'UTF-8', AppConfig.IMG_BASE + '/');
      this.loadFavoriteState();
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
  }

  /** 拉取收藏列表，只保留 skuId（详情页只需判断当前 SKU 是否已收藏） */
  async loadFavoriteState(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.favoriteSkus = [];
      return;
    }
    try {
      const list: SimpleSku[] = await Api.favorites();
      const ids: number[] = [];
      for (const item of list ?? []) {
        ids.push(item.skuId);
      }
      this.favoriteSkus = ids;
    } catch (e) {
      // 收藏状态拉取失败不影响商品详情展示
    }
  }

  isFavorite(): boolean {
    if (!this.selectedSku) {
      return false;
    }
    return this.favoriteSkus.indexOf(this.selectedSku.id) >= 0;
  }

  async toggleFavorite(): Promise<void> {
    if (!UserStore.isLogin()) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (!this.selectedSku) {
      promptAction.showToast({ message: '请选择规格' });
      return;
    }
    const skuId: number = this.selectedSku.id;
    try {
      if (this.isFavorite()) {
        await Api.removeFavorite(skuId);
        const rest: number[] = [];
        for (const id of this.favoriteSkus) {
          if (id !== skuId) {
            rest.push(id);
          }
        }
        this.favoriteSkus = rest;
        promptAction.showToast({ message: '已取消收藏', duration: 1200 });
      } else {
        await Api.addFavorite(skuId);
        // 整体替换数组才能触发刷新（@State 只观测第一层）
        const next: number[] = this.favoriteSkus.slice();
        next.push(skuId);
        this.favoriteSkus = next;
        promptAction.showToast({ message: '已加入收藏', duration: 1200 });
      }
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  private detailHtml(): string {
    if (!this.product) {
      return '<html><body></body></html>';
    }
    const html: string = this.product.detail ?? '';
    return html.replace(/src="\//g, 'src="' + AppConfig.IMG_BASE + '/');
  }

  specGroups(): Record<string, string[]> {
    const groups: Record<string, string[]> = {};
    for (const sku of this.skus) {
      const specs = FormatUtil.parseSnapshot(sku.specs);
      const keys: string[] = Object.keys(specs);
      for (const key of keys) {
        if (!groups[key]) {
          groups[key] = [];
        }
        if (groups[key].indexOf(specs[key]) < 0) {
          groups[key].push(specs[key]);
        }
      }
    }
    return groups;
  }

  isSpecSelected(key: string, value: string): boolean {
    if (!this.selectedSku) {
      return false;
    }
    const specs = FormatUtil.parseSnapshot(this.selectedSku.specs);
    return specs[key] === value;
  }

  selectSpec(key: string, value: string): void {
    for (const sku of this.skus) {
      const specs = FormatUtil.parseSnapshot(sku.specs);
      if (specs[key] === value) {
        this.selectedSku = sku;
        // 换规格后库存可能变小，把已选数量压回可购范围
        const stock: number = sku.stock ?? 0;
        if (stock > 0 && this.quantity > stock) {
          this.quantity = stock;
          promptAction.showToast({ message: '该规格库存仅剩 ' + stock + ' 件' });
        }
        return;
      }
    }
  }

  specText(sku: ProductSku): string {
    const specs = FormatUtil.parseSnapshot(sku.specs);
    const keys: string[] = Object.keys(specs);
    const parts: string[] = [];
    for (const key of keys) {
      parts.push(specs[key]);
    }
    return parts.join(' / ');
  }

  /** 当前选中规格是否售罄 */
  soldOut(): boolean {
    return this.selectedSku !== null && (this.selectedSku.stock ?? 0) <= 0;
  }

  /** 可购上限：库存为 0 时按 1 显示，避免出现「数量 0」这种怪值 */
  maxQuantity(): number {
    if (!this.selectedSku) {
      return 1;
    }
    const stock: number = this.selectedSku.stock ?? 0;
    return stock > 0 ? stock : 1;
  }

  topReviews(): Review[] {
    const result: Review[] = [];
    for (const review of this.reviews) {
      if (result.length >= 3) {
        break;
      }
      result.push(review);
    }
    return result;
  }

  async addToCart(): Promise<void> {
    if (!UserStore.isLogin()) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (!this.selectedSku) {
      promptAction.showToast({ message: '请选择规格' });
      return;
    }
    try {
      await Api.addCart(this.selectedSku.id, this.quantity);
      promptAction.showToast({ message: '已加入购物车', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  async buyNow(): Promise<void> {
    if (!UserStore.isLogin()) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (!this.selectedSku) {
      promptAction.showToast({ message: '请选择规格' });
      return;
    }
    try {
      const cartId: number = await Api.addCart(this.selectedSku.id, this.quantity);
      router.pushUrl({ url: 'pages/OrderConfirmPage', params: { cartIds: String(cartId) } });
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  build() {
    Column() {
      // 顶部返回 + 收藏：固定在页面最上方（加载中 / 加载失败时同样可用，避免退不出去）
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontColor('#0A59F7')
          // 上下内边距把点击热区撑高，方便手指点击
          .padding({ top: 9, bottom: 9, right: 16 })
          .onClick(() => {
            router.back();
          })
        Blank()
        Text(this.isFavorite() ? '★ 已收藏' : '☆ 收藏')
          .fontSize(15)
          .fontColor(this.isFavorite() ? '#FF9F1A' : '#0A59F7')
          .padding({ top: 9, bottom: 9, left: 12 })
          .onClick(() => this.toggleFavorite())
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })

      if (this.loading) {
        LoadingView()
      } else if (!this.product) {
        EmptyView({
          text: this.failed.length > 0 ? this.failed : '商品不存在',
          actionText: '重试',
          onAction: () => this.load(0)
        })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 主图
            Image(AppConfig.imgUrl(this.selectedSku && this.selectedSku.image
              ? this.selectedSku.image : this.product.mainImage))
              .width('100%')
              .height(300)
              .objectFit(ImageFit.Cover)

            // 价格
            Row({ space: 8 }) {
              if (this.selectedSku) {
                Text(FormatUtil.money(this.selectedSku.price))
                  .fontSize(24)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FF3B30')
                if (this.product.originalPrice && this.product.originalPrice > this.selectedSku.price) {
                  Text(FormatUtil.money(this.product.originalPrice))
                    .fontSize(13)
                    .fontColor('#8A9199')
                    .decoration({ type: TextDecorationType.LineThrough })
                }
              }
              Text('已售 ' + this.product.sales)
                .fontSize(12)
                .fontColor('#8A9199')
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')

            // 名称与副标题
            Column({ space: 4 }) {
              Text(this.product.name)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#182431')
              if (this.product.subtitle) {
                Text(this.product.subtitle)
                  .fontSize(12)
                  .fontColor('#8A9199')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            // 规格选择
            Column({ space: 10 }) {
              ForEach(Object.keys(this.specGroups()), (key: string) => {
                Column({ space: 6 }) {
                  Text(key)
                    .fontSize(12)
                    .fontColor('#8A9199')
                  // 用 Flex 自动换行：规格文字长短不一（如"【替换装】葡萄精油*3（无机身）"），
                  // 用 Row 不换行会把超出的规格挤到屏幕外裁掉
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.specGroups()[key], (value: string) => {
                      Text(value)
                        .fontSize(12)
                        .fontColor(this.isSpecSelected(key, value) ? '#FFFFFF' : '#182431')
                        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                        .backgroundColor(this.isSpecSelected(key, value) ? '#0A59F7' : '#F5F6F8')
                        .borderRadius(6)
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => this.selectSpec(key, value))
                    })
                  }
                  .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
              })

              // 数量
              Row({ space: 12 }) {
                Text('数量')
                  .fontSize(12)
                  .fontColor('#8A9199')
                // 用小方块自绘步进器：Button 在 26~32 尺寸下文字会被内边距挤没（实测不显示）
                Text('−')
                  .fontSize(16)
                  .fontColor(this.quantity > 1 ? '#182431' : '#C9CDD4')
                  .width(30)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#F5F6F8')
                  .borderRadius(6)
                  .onClick(() => {
                    if (this.quantity > 1) {
                      this.quantity -= 1;
                    }
                  })
                Text(String(this.quantity))
                  .fontSize(14)
                  .fontColor('#182431')
                Text('+')
                  .fontSize(16)
                  .fontColor(this.quantity < this.maxQuantity() ? '#182431' : '#C9CDD4')
                  .width(30)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#F5F6F8')
                  .borderRadius(6)
                  .onClick(() => {
                    // 数量不能超过库存：超了后端也会拒，不如在这里就挡住
                    if (this.quantity < this.maxQuantity()) {
                      this.quantity += 1;
                    } else {
                      promptAction.showToast({ message: '已达库存上限' });
                    }
                  })
                if (this.selectedSku) {
                  Text(this.soldOut() ? '已售罄' : '库存 ' + this.selectedSku.stock + ' 件')
                    .fontSize(11)
                    .fontColor(this.soldOut() ? '#FF3B30' : '#8A9199')
                }
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            // 评价
            Column({ space: 8 }) {
              Text('商品评价（' + this.reviews.length + '）')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#182431')
              ForEach(this.topReviews(), (review: Review) => {
                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    // 评价人头像：无头像时用首字圆形占位
                    Stack() {
                      Circle({ width: 22, height: 22 }).fill('#E8F0FE')
                      Text((review.nickname ?? '匿').substring(0, 1))
                        .fontSize(11)
                        .fontColor('#0A59F7')
                    }
                    Text(review.nickname ?? '匿名用户')
                      .fontSize(12)
                      .fontColor('#5E6877')
                      .layoutWeight(1)
                    Text('★'.repeat(review.rating))
                      .fontSize(12)
                      .fontColor('#F59E0B')
                  }
                  Text(review.content)
                    .fontSize(13)
                    .fontColor('#182431')
                  Text(FormatUtil.dateTime(review.createdAt))
                    .fontSize(11)
                    .fontColor('#8A9199')
                }
                .alignItems(HorizontalAlign.Start)
                .padding({ top: 8 })
              })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            // 图文详情
            Column({ space: 8 }) {
              Text('商品详情')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#182431')
              Web({ src: '', controller: this.webController })
                .width('100%')
                .height(360)
                .backgroundColor('#FFFFFF')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)

        // 底部操作栏
        Row({ space: 10 }) {
          Button(this.soldOut() ? '已售罄' : '加入购物车')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(this.soldOut() ? '#C9CDD4' : '#FF9F1A')
            .height(44)
            .layoutWeight(1)
            .borderRadius(22)
            .enabled(!this.soldOut())
            .onClick(() => this.addToCart())
          Button(this.soldOut() ? '已售罄' : '立即购买')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(this.soldOut() ? '#C9CDD4' : '#FF3B30')
            .height(44)
            .layoutWeight(1)
            .borderRadius(22)
            .enabled(!this.soldOut())
            .onClick(() => this.buyNow())
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
