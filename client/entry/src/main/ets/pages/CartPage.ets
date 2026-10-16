import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { CartVO } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';

/**
 * 购物车：选中 / 改数量 / 删除 / 合计 / 结算
 */
@Component
export struct CartPage {

  @State items: CartVO[] = [];
  @State loading: boolean = true;
  @State allChecked: boolean = false;
  @State total: number = 0;
  @State selectedCount: number = 0;
  // 登录态变化时自动刷新（同 MePage：登录成功返回后本组件不会重建，靠监听 token 触发重载）
  @StorageProp('token') @Watch('onTokenChange') token: string = '';

  onTokenChange(): void {
    this.load();
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.items = [];
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      const list: CartVO[] = await Api.cartList();
      this.items = list ?? [];
      this.refreshChecked();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '加载失败' });
    } finally {
      this.loading = false;
    }
  }

  /** 是否售罄（库存为 0） */
  soldOut(item: CartVO): boolean {
    return (item.stock ?? 0) <= 0;
  }

  /** 数量是否已达库存上限 */
  reachLimit(item: CartVO): boolean {
    const stock: number = item.stock ?? 0;
    return stock > 0 && item.quantity >= stock;
  }

  refreshChecked(): void {
    let all: boolean = this.items.length > 0;
    let total: number = 0;
    let count: number = 0;
    for (const item of this.items) {
      // 售罄商品不参与「全选」判断，也不计入合计（否则会出现点了结算却被后端拒）
      if (item.selected !== 1 || this.soldOut(item)) {
        all = false;
      } else {
        total += item.price * item.quantity;
        count += 1;
      }
    }
    this.allChecked = all;
    this.total = total;
    this.selectedCount = count;
  }

  /**
   * 用「新对象」替换数组中的同一项。
   * @State 只观测第一层：直接改 items[i].quantity 不会触发 UI 刷新
   * （实测：点 + 加到 5 件，合计对了但数量仍显示 1），必须整体替换数组。
   */
  replaceItem(id: number, quantity: number, selected: number): void {
    const next: CartVO[] = [];
    for (const it of this.items) {
      if (it.id === id) {
        const copy: CartVO = {
          id: it.id,
          skuId: it.skuId,
          productId: it.productId,
          productName: it.productName,
          image: it.image,
          specs: it.specs,
          price: it.price,
          quantity: quantity,
          selected: selected,
          stock: it.stock
        };
        next.push(copy);
      } else {
        next.push(it);
      }
    }
    this.items = next;
  }

  /**
   * 勾选/取消单个商品
   * 勾选框一律自绘（Circle + ✓），不用 Checkbox 组件：
   * ① Checkbox 的 onChange 会在「按 select 值回填」这条路径上被触发，
   *    回调里若按当前状态取反，就会把用户的选择反向写回服务端
   *    （实测：重进购物车 → 所有商品被自动取消勾选）；
   * ② 自绘的样式在 ArkUI 各版本上表现一致，不依赖组件默认内边距。
   */
  setItemSelected(item: CartVO, checked: boolean): void {
    if (this.soldOut(item)) {
      return;
    }
    const target: number = checked ? 1 : 0;
    if (item.selected === target) {
      return;
    }
    this.replaceItem(item.id, item.quantity, target);
    Api.updateCart(item.id, item.quantity, target).catch(() => { });
    this.refreshChecked();
  }

  /** 全选 / 全不选 */
  setAllSelected(checked: boolean): void {
    const target: number = checked ? 1 : 0;
    for (const item of this.items) {
      if (this.soldOut(item) || item.selected === target) {
        continue;
      }
      Api.updateCart(item.id, item.quantity, target).catch(() => { });
      this.replaceItem(item.id, item.quantity, target);
    }
    this.refreshChecked();
  }

  changeQuantity(item: CartVO, delta: number): void {
    const next: number = item.quantity + delta;
    if (next < 1) {
      return;
    }
    if (delta > 0 && this.reachLimit(item)) {
      promptAction.showToast({ message: '已达库存上限（' + item.stock + ' 件）' });
      return;
    }
    this.replaceItem(item.id, next, item.selected);
    Api.updateCart(item.id, next, item.selected).catch((e: Error) => {
      // 后端也会拦库存：失败时直接重新拉取，保证界面与服务端一致
      promptAction.showToast({ message: e.message ?? '修改失败' });
      this.load();
    });
    this.refreshChecked();
  }

  removeItem(item: CartVO): void {
    Api.deleteCart(item.id)
      .then(() => {
        this.load();
      })
      .catch((e: Error) => {
        promptAction.showToast({ message: e.message ?? '删除失败' });
      });
  }

  checkout(): void {
    if (!UserStore.isLogin()) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    const ids: number[] = [];
    let hasSoldOut: boolean = false;
    for (const item of this.items) {
      if (item.selected === 1) {
        if (this.soldOut(item)) {
          hasSoldOut = true;
        } else {
          ids.push(item.id);
        }
      }
    }
    if (hasSoldOut) {
      promptAction.showToast({ message: '已售罄商品不会参与结算，请先移除', duration: 1600 });
    }
    if (ids.length === 0) {
      promptAction.showToast({ message: '请选择要结算的商品' });
      return;
    }
    router.pushUrl({ url: 'pages/OrderConfirmPage', params: { cartIds: ids.join(',') } });
  }

  build() {
    Column() {
      if (!UserStore.isLogin()) {
        EmptyView({
          text: '登录后同步购物车',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.items.length === 0 && !this.loading) {
        EmptyView({ text: '购物车是空的，去挑选商品吧' })
      } else {
        List() {
          ForEach(this.items, (item: CartVO) => {
            ListItem() {
              Row({ space: 10 }) {
                Stack() {
                  Circle({ width: 20, height: 20 })
                    .fill(item.selected === 1 && !this.soldOut(item) ? '#0A59F7' : '#FFFFFF')
                    .stroke(item.selected === 1 && !this.soldOut(item) ? '#0A59F7' : '#C9CDD4')
                    .strokeWidth(1.5)
                  if (item.selected === 1 && !this.soldOut(item)) {
                    Text('✓')
                      .fontSize(13)
                      .fontColor('#FFFFFF')
                      .fontWeight(FontWeight.Bold)
                  }
                }
                .width(32)
                .height(32)
                .onClick(() => this.setItemSelected(item, item.selected !== 1))

                Image(AppConfig.imgUrl(item.image))
                  .width(72)
                  .height(72)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(8)

                Column({ space: 6 }) {
                  Row({ space: 6 }) {
                    Text(item.productName)
                      .fontSize(13)
                      .fontColor(this.soldOut(item) ? '#B7BDC6' : '#182431')
                      .maxLines(2)
                      .lineHeight(18)
                      .layoutWeight(1)
                    if (this.soldOut(item)) {
                      Text('已售罄')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                        .backgroundColor('#B7BDC6')
                        .borderRadius(4)
                    }
                  }
                  .width('100%')
                  Text(FormatUtil.specText(item.specs))
                    .fontSize(11)
                    .fontColor('#8A9199')
                  Row({ space: 8 }) {
                    Text(FormatUtil.money(item.price))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.soldOut(item) ? '#B7BDC6' : '#FF3B30')
                  Row({ space: 6 }) {
                    // 小方块自绘步进器：Button 在 26~32 尺寸下文字会被内边距挤没（实测不显示）
                    Text('−')
                      .fontSize(15)
                      .fontColor(this.soldOut(item) ? '#C9CDD4' : '#182431')
                      .width(26)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor('#F5F6F8')
                      .borderRadius(5)
                      .onClick(() => this.changeQuantity(item, -1))
                    Text(String(item.quantity))
                      .fontSize(13)
                      .fontColor('#182431')
                    Text('+')
                      .fontSize(15)
                      .fontColor(this.soldOut(item) || this.reachLimit(item) ? '#C9CDD4' : '#182431')
                      .width(26)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor('#F5F6F8')
                      .borderRadius(5)
                      // 到库存上限就置灰，避免用户白点一次
                      .onClick(() => this.changeQuantity(item, 1))
                  }
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text('删除')
                  .fontSize(12)
                  .fontColor('#8A9199')
                  .onClick(() => this.removeItem(item))
              }
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor('#FFFFFF')
            }
          })
        }
        .layoutWeight(1)

        // 结算栏
        Row({ space: 12 }) {
          Row({ space: 6 }) {
            Stack() {
              Circle({ width: 20, height: 20 })
                .fill(this.allChecked ? '#0A59F7' : '#FFFFFF')
                .stroke(this.allChecked ? '#0A59F7' : '#C9CDD4')
                .strokeWidth(1.5)
              if (this.allChecked) {
                Text('✓')
                  .fontSize(13)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Bold)
              }
            }
            .width(28)
            .height(28)
            .onClick(() => this.setAllSelected(!this.allChecked))
            Text('全选')
              .fontSize(13)
              .fontColor('#182431')
          }
          Column({ space: 2 }) {
            Text('合计')
              .fontSize(11)
              .fontColor('#8A9199')
            Text(FormatUtil.money(this.total))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FF3B30')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.End)

          Button('结算（' + this.selectedCount + '）')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF3B30')
            .height(38)
            .padding({ left: 18, right: 18 })
            .borderRadius(19)
            .onClick(() => this.checkout())
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .border({ width: { top: 0.5 }, color: '#EEF0F3' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
