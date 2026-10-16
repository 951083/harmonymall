import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { Address, CartVO, Coupon } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 确认订单：地址 / 商品清单 / 优惠券 / 备注 / 提交
 */
@Entry
@Component
struct OrderConfirmPage {

  @State cartIds: number[] = [];
  @State items: CartVO[] = [];
  @State addresses: Address[] = [];
  @State addressId: number = 0;
  @State remark: string = '';
  @State loading: boolean = true;
  @State submitting: boolean = false;
  /** 可用优惠券（按订单金额过滤） */
  @State coupons: Coupon[] = [];
  /** 已选优惠券（t_user_coupon.id），0 表示不用券 */
  @State couponId: number = 0;
  /** 优惠券选择面板是否展开 */
  @State showCoupons: boolean = false;
  /**
   * 幂等令牌：进入本页时生成一次，提交时带上。
   * 重复点击 / 网络重试会命中同一个令牌，后端据此拒绝第二笔相同订单
   */
  private clientToken: string = String(Date.now()) + '_' + Math.floor(Math.random() * 1000000);

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['cartIds']) {
      const parts: string[] = (params['cartIds'] as string).split(',');
      for (const part of parts) {
        const id: number = Number(part);
        if (id > 0) {
          this.cartIds.push(id);
        }
      }
    }
    // 重新进入本页视为一次新的下单意图，换一个令牌
    this.clientToken = String(Date.now()) + '_' + Math.floor(Math.random() * 1000000);
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  async load(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      const carts: CartVO[] = await Api.cartList();
      this.items = [];
      for (const cart of carts) {
        if (this.cartIds.indexOf(cart.id) >= 0) {
          this.items.push(cart);
        }
      }
      const list: Address[] = await Api.addressList();
      this.addresses = list ?? [];
      let chosen: number = 0;
      for (const address of this.addresses) {
        if (address.isDefault === 1) {
          chosen = address.id ?? 0;
          break;
        }
      }
      if (chosen === 0 && this.addresses.length > 0) {
        chosen = this.addresses[0].id ?? 0;
      }
      this.addressId = chosen;
      await this.loadCoupons();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '加载失败' });
    } finally {
      this.loading = false;
    }
  }

  /** 拉取本单可用券：金额满足门槛才返回，换地址/换商品后金额变了要重算 */
  async loadCoupons(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.coupons = [];
      return;
    }
    try {
      const list: Coupon[] = await Api.usableCoupons(this.totalPrice());
      this.coupons = list ?? [];
      // 之前选的券如果已经不可用（比如删了商品金额不够），自动取消选择
      let stillValid: boolean = false;
      for (const coupon of this.coupons) {
        if (coupon.id === this.couponId) {
          stillValid = true;
          break;
        }
      }
      if (!stillValid) {
        this.couponId = 0;
      }
    } catch (e) {
      this.coupons = [];
      this.couponId = 0;
    }
  }

  selectedCoupon(): Coupon | null {
    for (const coupon of this.coupons) {
      if (coupon.id === this.couponId) {
        return coupon;
      }
    }
    return null;
  }

  /** 优惠金额（分）：不超过商品总额，避免出现负数实付 */
  discountAmount(): number {
    const coupon: Coupon | null = this.selectedCoupon();
    if (!coupon) {
      return 0;
    }
    return Math.min(coupon.amount, this.totalPrice());
  }

  /** 券面额文案：整元不显示小数（¥10 而非 ¥10.00） */
  couponFace(coupon: Coupon): string {
    const yuan: number = coupon.amount / 100;
    return '¥' + (yuan % 1 === 0 ? String(yuan) : yuan.toFixed(2));
  }

  /** 实付金额（分） */
  payAmount(): number {
    return Math.max(this.totalPrice() - this.discountAmount(), 0);
  }

  currentAddress(): Address | null {
    for (const address of this.addresses) {
      if (address.id === this.addressId) {
        return address;
      }
    }
    return null;
  }

  totalPrice(): number {
    let total: number = 0;
    for (const item of this.items) {
      total += item.price * item.quantity;
    }
    return total;
  }

  async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.items.length === 0) {
      promptAction.showToast({ message: '没有可结算的商品' });
      return;
    }
    if (this.addressId <= 0) {
      promptAction.showToast({ message: '请先添加收货地址' });
      router.pushUrl({ url: 'pages/AddressListPage', params: { pick: '1' } });
      return;
    }
    this.submitting = true;
    try {
      const order = await Api.createOrder(this.cartIds, this.addressId, this.remark,
        this.couponId, this.clientToken);
      promptAction.showToast({ message: '下单成功', duration: 1200 });
      router.replaceUrl({ url: 'pages/OrderDetailPage', params: { id: order.id } });
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '下单失败' });
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column() {
      // 顶部返回：固定在页面最上方（未登录 / 加载中同样可用，避免退不出去）
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontColor('#0A59F7')
          .padding({ top: 9, bottom: 9, right: 16 })
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })

      if (!UserStore.isLogin()) {
        EmptyView({
          text: '请先登录',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.loading) {
        LoadingView()
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 地址卡片
            Row({ space: 10 }) {
              if (this.currentAddress()) {
                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text(this.currentAddress()?.receiver ?? '')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#182431')
                    Text(this.currentAddress()?.phone ?? '')
                      .fontSize(12)
                      .fontColor('#8A9199')
                  }
                  Text((this.currentAddress()?.province ?? '') + (this.currentAddress()?.city ?? '') +
                        (this.currentAddress()?.district ?? '') + ' ' + (this.currentAddress()?.detail ?? ''))
                    .fontSize(12)
                    .fontColor('#8A9199')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              } else {
                Text('添加收货地址')
                  .fontSize(14)
                  .fontColor('#0A59F7')
                  .layoutWeight(1)
              }
              Text('>')
                .fontSize(14)
                .fontColor('#8A9199')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .onClick(() => {
              router.pushUrl({ url: 'pages/AddressListPage', params: { pick: '1' } });
            })

            // 商品清单
            Column({ space: 10 }) {
              ForEach(this.items, (item: CartVO) => {
                Row({ space: 10 }) {
                  Image(AppConfig.imgUrl(item.image))
                    .width(64)
                    .height(64)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                  Column({ space: 4 }) {
                    Text(item.productName)
                      .fontSize(13)
                      .fontColor('#182431')
                      .maxLines(1)
                    Text(FormatUtil.specText(item.specs))
                      .fontSize(11)
                      .fontColor('#8A9199')
                    Row({ space: 6 }) {
                      Text(FormatUtil.money(item.price))
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#FF3B30')
                      Text('x' + item.quantity)
                        .fontSize(12)
                        .fontColor('#8A9199')
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                }
              })
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)

            // 优惠券
            Column({ space: 0 }) {
              Row({ space: 10 }) {
                Text('优惠券')
                  .fontSize(14)
                  .fontColor('#182431')
                Blank()
                Text(this.selectedCoupon()
                  ? ('- ' + FormatUtil.money(this.discountAmount()))
                  : (this.coupons.length > 0 ? this.coupons.length + ' 张可用' : '暂无可用'))
                  .fontSize(13)
                  .fontColor(this.selectedCoupon() ? '#FF3B30' : '#8A9199')
                Text(this.showCoupons ? '▲' : '▼')
                  .fontSize(11)
                  .fontColor('#8A9199')
              }
              .width('100%')
              .padding(14)
              .onClick(() => {
                if (this.coupons.length === 0) {
                  promptAction.showToast({ message: '当前订单暂无可用优惠券' });
                  return;
                }
                this.showCoupons = !this.showCoupons;
              })

              // 展开后的券列表
              if (this.showCoupons) {
                Divider().color('#EEF0F3').strokeWidth(0.5).margin({ left: 14, right: 14 })
                ForEach(this.coupons, (coupon: Coupon) => {
                  Row({ space: 10 }) {
                    Text(this.couponFace(coupon))
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FF3B30')
                      .width(72)
                    Column({ space: 2 }) {
                      Text(coupon.name)
                        .fontSize(13)
                        .fontColor('#182431')
                      Text(coupon.threshold > 0
                        ? '满 ' + (coupon.threshold / 100).toFixed(0) + ' 元可用'
                        : '无门槛')
                        .fontSize(11)
                        .fontColor('#8A9199')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    if (this.couponId === coupon.id) {
                      Text('✓ 已选')
                        .fontSize(12)
                        .fontColor('#FF3B30')
                    } else {
                      Text('使用')
                        .fontSize(12)
                        .fontColor('#0A59F7')
                    }
                  }
                  .width('100%')
                  .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                  .onClick(() => {
                    this.couponId = coupon.id ?? 0;
                    this.showCoupons = false;
                  })
                })
                // 不使用优惠券
                Row() {
                  Text('不使用优惠券')
                    .fontSize(13)
                    .fontColor('#8A9199')
                    .layoutWeight(1)
                  if (this.couponId === 0) {
                    Text('✓ 已选')
                      .fontSize(12)
                      .fontColor('#FF3B30')
                  }
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .onClick(() => {
                  this.couponId = 0;
                  this.showCoupons = false;
                })
              }
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .borderRadius(8)

            // 备注
            TextInput({ placeholder: '订单备注（选填）', text: this.remark })
              .height(44)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .padding({ left: 14 })
              .onChange((value: string) => {
                this.remark = value;
              })
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
          // 内容不足一屏时 Scroll 会把子组件垂直居中，用最小高度撑满视口让内容顶端对齐
          .constraintSize({ minHeight: '100%' })
        }
        .layoutWeight(1)

        // 提交栏
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Row({ space: 6 }) {
              Text('合计')
                .fontSize(11)
                .fontColor('#8A9199')
              Text(FormatUtil.money(this.totalPrice()))
                .fontSize(11)
                .fontColor('#8A9199')
              if (this.discountAmount() > 0) {
                Text('优惠 -' + FormatUtil.money(this.discountAmount()))
                  .fontSize(11)
                  .fontColor('#FF3B30')
              }
            }
            Text(FormatUtil.money(this.payAmount()))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FF3B30')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.End)

          Button(this.submitting ? '提交中…' : '提交订单')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF3B30')
            .height(40)
            .padding({ left: 20, right: 20 })
            .borderRadius(20)
            .enabled(!this.submitting)
            .onClick(() => this.submit())
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
