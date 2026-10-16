import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';
import { Coupon } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 优惠券：领券中心 + 我的优惠券
 * 券状态：0 未使用 / 1 已使用 / 2 已过期
 */
@Entry
@Component
struct CouponPage {

  @State tab: number = 0;
  @State center: Coupon[] = [];
  @State mine: Coupon[] = [];
  @State loading: boolean = true;
  @State failed: string = '';
  @StorageProp('token') @Watch('onTokenChange') token: string = '';

  onTokenChange(): void {
    this.load();
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    this.failed = '';
    try {
      const list: Coupon[] = await Api.coupons();
      this.center = list ?? [];
      if (UserStore.isLogin()) {
        const myList: Coupon[] = await Api.myCoupons();
        this.mine = myList ?? [];
      } else {
        this.mine = [];
      }
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
  }

  async claim(coupon: Coupon): Promise<void> {
    if (!UserStore.isLogin()) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    try {
      await Api.claimCoupon(coupon.couponId);
      promptAction.showToast({ message: '领取成功，可在「我的优惠券」查看', duration: 1500 });
      this.load();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '领取失败' });
    }
  }

  statusText(status: number): string {
    const map: Record<number, string> = {
      0: '未使用',
      1: '已使用',
      2: '已过期'
    };
    return map[status] ?? '';
  }

  /** 面额展示：整元不显示小数（¥10 而不是 ¥10.00） */
  amountText(amount: number): string {
    const yuan: number = amount / 100;
    return yuan % 1 === 0 ? String(yuan) : yuan.toFixed(2);
  }

  thresholdText(threshold: number): string {
    if (threshold <= 0) {
      return '无门槛';
    }
    return '满 ' + this.amountText(threshold) + ' 元可用';
  }

  @Builder
  centerCard(coupon: Coupon) {
    Row({ space: 12 }) {
      // 左侧面额
      Column({ space: 2 }) {
        Row() {
          Text('¥')
            .fontSize(13)
            .fontColor('#FF3B30')
          Text(this.amountText(coupon.amount))
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF3B30')
        }
        Text(this.thresholdText(coupon.threshold))
          .fontSize(10)
          .fontColor('#8A9199')
      }
      .width(96)
      .alignItems(HorizontalAlign.Center)

      Divider()
        .vertical(true)
        .height(48)
        .color('#EEF0F3')
        .strokeWidth(1)

      Column({ space: 4 }) {
        Text(coupon.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
          .maxLines(1)
        if (coupon.description) {
          Text(coupon.description)
            .fontSize(11)
            .fontColor('#8A9199')
            .maxLines(1)
        }
        Text(coupon.remain === -1 ? '不限量' : '剩余 ' + coupon.remain + ' 张')
          .fontSize(10)
          .fontColor('#8A9199')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (coupon.claimed) {
        Text('已领取')
          .fontSize(12)
          .fontColor('#8A9199')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor('#F5F6F8')
          .borderRadius(16)
      } else {
        Text('领取')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor('#FF3B30')
          .borderRadius(16)
          .onClick(() => this.claim(coupon))
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  mineCard(coupon: Coupon) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Row() {
          Text('¥')
            .fontSize(13)
            .fontColor(coupon.status === 0 ? '#FF3B30' : '#B7BDC6')
          Text(this.amountText(coupon.amount))
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(coupon.status === 0 ? '#FF3B30' : '#B7BDC6')
        }
        Text(this.thresholdText(coupon.threshold))
          .fontSize(10)
          .fontColor('#8A9199')
      }
      .width(96)
      .alignItems(HorizontalAlign.Center)

      Divider()
        .vertical(true)
        .height(48)
        .color('#EEF0F3')
        .strokeWidth(1)

      Column({ space: 4 }) {
        Text(coupon.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(coupon.status === 0 ? '#182431' : '#8A9199')
          .maxLines(1)
        if (coupon.expireTime) {
          Text('有效期至 ' + FormatUtil.dateTime(coupon.expireTime))
            .fontSize(11)
            .fontColor('#8A9199')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.statusText(coupon.status ?? 0))
        .fontSize(11)
        .fontColor(coupon.status === 0 ? '#FF3B30' : '#8A9199')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(coupon.status === 0 ? '#FFF1F0' : '#F5F6F8')
        .borderRadius(4)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontColor('#0A59F7')
          .padding({ top: 9, bottom: 9, right: 16 })
          .onClick(() => {
            router.back();
          })
        Text('优惠券')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Blank()
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#FFFFFF')

      // Tab
      Row({ space: 24 }) {
        ForEach(['领券中心', '我的优惠券'], (name: string, index: number) => {
          Column({ space: 4 }) {
            Text(name)
              .fontSize(14)
              .fontColor(this.tab === index ? '#0A59F7' : '#8A9199')
              .fontWeight(this.tab === index ? FontWeight.Medium : FontWeight.Normal)
            Divider()
              .strokeWidth(this.tab === index ? 2 : 0)
              .color('#0A59F7')
              .width(24)
          }
          .onClick(() => {
            this.tab = index;
          })
        })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('#FFFFFF')

      if (!UserStore.isLogin() && this.tab === 1) {
        EmptyView({
          text: '登录后查看我的优惠券',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.loading) {
        LoadingView()
      } else if (this.tab === 0 && this.center.length === 0) {
        EmptyView({ text: this.failed.length > 0 ? this.failed : '暂无可领取的优惠券' })
      } else if (this.tab === 1 && this.mine.length === 0) {
        EmptyView({
          text: '还没有优惠券',
          actionText: '去领券中心',
          onAction: () => {
            this.tab = 0;
          }
        })
      } else {
        Scroll() {
          Column({ space: 10 }) {
            if (this.tab === 0) {
              ForEach(this.center, (coupon: Coupon) => {
                this.centerCard(coupon)
              })
            } else {
              ForEach(this.mine, (coupon: Coupon) => {
                this.mineCard(coupon)
              })
            }
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ minHeight: '100%' })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
