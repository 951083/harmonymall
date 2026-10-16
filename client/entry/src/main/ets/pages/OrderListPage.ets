import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';
import { Order } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';

/**
 * 订单列表：状态 Tab + 订单卡片 + 快捷操作
 */
@Entry
@Component
struct OrderListPage {

  @State currentTab: number = 0;
  @State orders: Order[] = [];
  @State page: number = 1;
  @State total: number = 0;
  @State loading: boolean = false;
  // ---------- 取消 / 退款原因弹层 ----------
  @State reasonOrderId: number = 0;
  @State reasonKind: string = 'cancel';
  @State reasonSelected: number = -1;
  @State reasonSubmitting: boolean = false;
  private readonly cancelReasons: string[] = ['不想要了', '信息填写错误', '重复下单', '其他原因'];
  private readonly refundReasons: string[] = ['拍错了/不想要了', '商品缺货', '发货太慢', '其他原因'];
  private readonly tabs: string[] = ['全部', '待付款', '待发货', '待收货', '已完成'];
  private readonly statusMap: number[] = [-1, 0, 1, 2, 3];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    if (params && params['status'] !== undefined) {
      const target: number = Number(params['status']);
      for (let i = 0; i < this.statusMap.length; i++) {
        if (this.statusMap[i] === target) {
          this.currentTab = i;
          break;
        }
      }
    }
  }

  /**
   * 页面每次显示都刷新：在订单详情页付款 / 取消 / 确认收货后返回本页时，
   * 本组件不会重建（aboutToAppear 不再执行），必须靠 onPageShow 重新拉取，
   * 否则列表上的状态还是旧值
   */
  onPageShow(): void {
    this.load(true);
  }

  async load(reset: boolean): Promise<void> {
    if (!UserStore.isLogin() || this.loading) {
      return;
    }
    const targetPage: number = reset ? 1 : this.page + 1;
    this.loading = true;
    try {
      const status: number = this.statusMap[this.currentTab];
      const result = await Api.orderList(status < 0 ? undefined : status, targetPage);
      if (reset) {
        this.orders = result.list ?? [];
      } else {
        const list: Order[] = result.list ?? [];
        for (const order of list) {
          this.orders.push(order);
        }
      }
      this.page = result.page ?? targetPage;
      this.total = result.total ?? 0;
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '加载失败' });
    } finally {
      this.loading = false;
    }
  }

  async action(order: Order, type: string): Promise<void> {
    try {
      if (type === 'pay') {
        await Api.payOrder(order.id);
      } else if (type === 'confirm') {
        await Api.confirmOrder(order.id);
      }
      promptAction.showToast({ message: '操作成功', duration: 1200 });
      this.load(true);
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  // ---------- 取消 / 退款原因弹层 ----------
  openReasonPanel(orderId: number, kind: string): void {
    this.reasonOrderId = orderId;
    this.reasonKind = kind;
    this.reasonSelected = -1;
  }

  closeReasonPanel(): void {
    this.reasonOrderId = 0;
    this.reasonSelected = -1;
  }

  reasonOptions(): string[] {
    return this.reasonKind === 'cancel' ? this.cancelReasons : this.refundReasons;
  }

  async submitReason(): Promise<void> {
    if (this.reasonSubmitting || this.reasonOrderId <= 0) {
      return;
    }
    if (this.reasonSelected < 0) {
      promptAction.showToast({ message: '请先选择原因' });
      return;
    }
    const reason: string = this.reasonOptions()[this.reasonSelected];
    this.reasonSubmitting = true;
    try {
      if (this.reasonKind === 'cancel') {
        await Api.cancelOrder(this.reasonOrderId, reason);
        promptAction.showToast({ message: '订单已取消', duration: 1200 });
      } else {
        await Api.refundOrder(this.reasonOrderId, reason);
        promptAction.showToast({ message: '退款申请已提交', duration: 1200 });
      }
      this.closeReasonPanel();
      this.load(true);
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    } finally {
      this.reasonSubmitting = false;
    }
  }

  /** 取消 / 退款原因选择弹层（与订单详情页同款交互） */
  @Builder
  reasonSheet() {
    Column({ space: 0 }) {
      Row() {
        Text(this.reasonKind === 'cancel' ? '选择取消原因' : '选择退款原因')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
          .layoutWeight(1)
        Text('关闭')
          .fontSize(13)
          .fontColor('#8A9199')
          .onClick(() => this.closeReasonPanel())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 6 })

      ForEach(this.reasonOptions(), (reason: string, index: number) => {
        Row({ space: 10 }) {
          Circle({ width: 18, height: 18 })
            .fill(this.reasonSelected === index ? '#FF3B30' : '#FFFFFF')
            .stroke(this.reasonSelected === index ? '#FF3B30' : '#C9CDD4')
            .strokeWidth(1.5)
          Text(reason)
            .fontSize(14)
            .fontColor('#182431')
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .onClick(() => {
          this.reasonSelected = index;
        })
      })

      Button(this.reasonSubmitting ? '提交中…' : '确认提交')
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor('#FF3B30')
        .height(42)
        .width('100%')
        .borderRadius(21)
        .enabled(!this.reasonSubmitting)
        .margin({ top: 6 })
        .onClick(() => this.submitReason())
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 14, topRight: 14 })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
    Column({ space: 10 }) {
      // 顶部返回：固定在页面最上方（未登录 / 空列表时同样可用，避免退不出去）
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
      .backgroundColor('#FFFFFF')

      // 状态 Tab
      Row({ space: 16 }) {
        ForEach(this.tabs, (name: string, index: number) => {
          Column({ space: 4 }) {
            Text(name)
              .fontSize(13)
              .fontColor(this.currentTab === index ? '#0A59F7' : '#8A9199')
              .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
            Divider()
              .strokeWidth(this.currentTab === index ? 2 : 0)
              .color('#0A59F7')
              .width(20)
          }
          .onClick(() => {
            if (this.currentTab !== index) {
              this.currentTab = index;
              this.load(true);
            }
          })
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10 })
      .backgroundColor('#FFFFFF')

      if (!UserStore.isLogin()) {
        EmptyView({
          text: '登录后查看订单',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.orders.length === 0 && !this.loading) {
        EmptyView({ text: '暂无相关订单' })
      } else {
        List() {
          ForEach(this.orders, (order: Order) => {
            ListItem() {
              Column({ space: 10 }) {
                Row() {
                  Text('订单号：' + order.orderNo)
                    .fontSize(11)
                    .fontColor('#8A9199')
                    .layoutWeight(1)
                    .maxLines(1)
                  Text(FormatUtil.orderStatus(order.status))
                    .fontSize(12)
                    .fontColor(order.status === 0 ? '#FF3B30' : '#182431')
                }

                Row() {
                  Text('下单时间：' + FormatUtil.dateTime(order.createdAt))
                    .fontSize(12)
                    .fontColor('#8A9199')
                    .layoutWeight(1)
                  Text(FormatUtil.money(order.payAmount))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FF3B30')
                }

                Row({ space: 10 }) {
                  Text('查看详情')
                    .fontSize(12)
                    .fontColor('#8A9199')
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                    .border({ width: 1, color: '#D5D9E0' })
                    .borderRadius(14)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                      router.pushUrl({ url: 'pages/OrderDetailPage', params: { id: order.id } });
                    })

                  if (order.status === 0) {
                    Text('取消订单')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                      .border({ width: 1, color: '#D5D9E0' })
                      .borderRadius(14)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.openReasonPanel(order.id, 'cancel'))
                    Text('去付款')
                      .fontSize(12)
                      .fontColor('#FFFFFF')
                      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                      .backgroundColor('#FF3B30')
                      .borderRadius(14)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.action(order, 'pay'))
                  } else if (order.status === 1) {
                    Text('申请退款')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                      .border({ width: 1, color: '#D5D9E0' })
                      .borderRadius(14)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.openReasonPanel(order.id, 'refund'))
                  } else if (order.status === 2) {
                    Text('确认收货')
                      .fontSize(12)
                      .fontColor('#FFFFFF')
                      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                      .backgroundColor('#FF3B30')
                      .borderRadius(14)
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.action(order, 'confirm'))
                  }
                }
              }
              .padding(12)
            }
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .margin({ left: 12, right: 12, top: 4 })
          })
        }
        .layoutWeight(1)

        if (this.orders.length < this.total) {
          Button('加载更多')
            .fontSize(13)
            .fontColor('#0A59F7')
            .backgroundColor('#FFFFFF')
            .height(36)
            .width('60%')
            .onClick(() => this.load(false))
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')

    // 取消 / 退款原因弹层：遮罩与面板是 Stack 兄弟节点，点面板不会触发遮罩关闭
    if (this.reasonOrderId > 0) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.35)')
        .onClick(() => this.closeReasonPanel())
      this.reasonSheet()
    }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
