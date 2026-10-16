import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { OrderDetail, OrderItem } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 订单详情：商品快照 / 地址快照 / 金额（含优惠） / 状态操作 / 评价入口
 * 状态：0 待付款 1 待发货 2 待收货 3 已完成 4 已取消 5 退款中 6 已退款
 */
@Entry
@Component
struct OrderDetailPage {

  @State order: OrderDetail | null = null;
  @State loading: boolean = true;
  @State failed: string = '';
  // ---------- 评价面板状态 ----------
  /** 正在评价的订单明细 ID（0 表示面板关闭） */
  @State reviewItemId: number = 0;
  @State reviewItemName: string = '';
  @State reviewRating: number = 5;
  @State reviewContent: string = '';
  @State submitting: boolean = false;

  // ---------- 取消 / 退款原因弹层 ----------
  /** '' 关闭 | 'cancel' 取消订单 | 'refund' 申请退款 */
  @State reasonPanel: string = '';
  @State reasonSelected: number = -1;
  @State reasonSubmitting: boolean = false;
  private readonly cancelReasons: string[] = ['不想要了', '信息填写错误', '重复下单', '其他原因'];
  private readonly refundReasons: string[] = ['拍错了/不想要了', '商品缺货', '发货太慢', '其他原因'];

  // ---------- 待付款倒计时 ----------
  @State countdown: string = '';
  private timerId: number = -1;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    const id: number = params && params['id'] ? Number(params['id']) : 0;
    this.load(id);
  }

  /** 页面销毁时清掉倒计时，避免定时器泄漏 */
  aboutToDisappear(): void {
    this.stopCountdown();
  }

  /** 取快照字段（ArkTS 组件链内不能声明变量，故抽成方法） */
  private snapValue(snapshot: string, key: string): string {
    const map: Record<string, string> = FormatUtil.parseSnapshot(snapshot);
    return map[key] ?? '';
  }

  private addr(key: string): string {
    if (!this.order) {
      return '';
    }
    return this.snapValue(this.order.addressSnapshot, key);
  }

  private itemSnap(item: OrderItem, key: string): string {
    return this.snapValue(item.productSnapshot, key);
  }

  async load(id: number): Promise<void> {
    if (id <= 0) {
      this.loading = false;
      this.failed = '订单不存在';
      return;
    }
    this.loading = true;
    try {
      this.order = await Api.orderDetail(id);
      // 待付款订单启动倒计时（与后端 30 分钟超时自动取消规则保持一致）
      if (this.order.status === 0) {
        this.startCountdown();
      } else {
        this.stopCountdown();
      }
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
  }

  // ---------- 待付款倒计时 ----------
  startCountdown(): void {
    if (this.timerId >= 0) {
      return;
    }
    this.tickCountdown();
    this.timerId = setInterval(() => {
      this.tickCountdown();
    }, 1000);
  }

  stopCountdown(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** 每秒刷新剩余支付时间；到点后提示即将取消，真实关单由后端定时任务完成 */
  tickCountdown(): void {
    const order = this.order;
    if (!order || order.status !== 0) {
      this.countdown = '';
      this.stopCountdown();
      return;
    }
    const created: number = new Date(order.createdAt).getTime();
    if (isNaN(created)) {
      this.countdown = '';
      return;
    }
    // 30 分钟与后端 harmonymall.order.timeout-minutes 保持一致
    const remain: number = created + 30 * 60 * 1000 - Date.now();
    if (remain <= 0) {
      this.countdown = '已超过支付时限，订单即将自动取消';
      return;
    }
    const totalSec: number = Math.floor(remain / 1000);
    const mm: number = Math.floor(totalSec / 60);
    const ss: number = totalSec % 60;
    this.countdown = '剩余支付时间 ' + mm + ' 分 ' + (ss < 10 ? '0' + ss : ss) + ' 秒，超时自动取消';
  }

  // ---------- 取消 / 退款原因 ----------
  openReasonPanel(kind: string): void {
    this.reasonPanel = kind;
    this.reasonSelected = -1;
  }

  closeReasonPanel(): void {
    this.reasonPanel = '';
    this.reasonSelected = -1;
  }

  reasonOptions(): string[] {
    return this.reasonPanel === 'cancel' ? this.cancelReasons : this.refundReasons;
  }

  async submitReason(): Promise<void> {
    if (this.reasonSubmitting || !this.order) {
      return;
    }
    if (this.reasonSelected < 0) {
      promptAction.showToast({ message: '请先选择原因' });
      return;
    }
    const reason: string = this.reasonOptions()[this.reasonSelected];
    const kind: string = this.reasonPanel;
    this.reasonSubmitting = true;
    try {
      if (kind === 'cancel') {
        await Api.cancelOrder(this.order.id, reason);
        promptAction.showToast({ message: '订单已取消', duration: 1500 });
      } else {
        await Api.refundOrder(this.order.id, reason);
        promptAction.showToast({ message: '退款申请已提交，商家将自动处理', duration: 1500 });
      }
      this.closeReasonPanel();
      this.load(this.order.id);
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    } finally {
      this.reasonSubmitting = false;
    }
  }

  async action(type: string): Promise<void> {
    if (!this.order) {
      return;
    }
    try {
      if (type === 'pay') {
        await Api.payOrder(this.order.id);
      } else if (type === 'cancel') {
        // 取消需要先选原因：打开原因弹层，提交走 submitReason()
        this.openReasonPanel('cancel');
        return;
      } else if (type === 'confirm') {
        await Api.confirmOrder(this.order.id);
      } else if (type === 'refund') {
        // 退款同样让用户先选原因
        this.openReasonPanel('refund');
        return;
      } else if (type === 'ship') {
        await Api.shipOrder(this.order.id);
      }
      promptAction.showToast({ message: '操作成功', duration: 1200 });
      this.load(this.order.id);
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  // ---------- 评价 ----------
  openReview(item: OrderItem): void {
    this.reviewItemId = item.id;
    this.reviewItemName = this.itemSnap(item, 'name');
    this.reviewRating = 5;
    this.reviewContent = '';
  }

  closeReview(): void {
    this.reviewItemId = 0;
    this.reviewContent = '';
  }

  async submitReview(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.reviewContent.length === 0) {
      promptAction.showToast({ message: '请填写评价内容' });
      return;
    }
    this.submitting = true;
    try {
      // skuId 传 0 即可：后端以订单明细里的 skuId 为准，避免端上传错
      await Api.addReview(this.reviewItemId, 0, this.reviewRating, this.reviewContent);
      promptAction.showToast({ message: '评价成功，感谢您的反馈', duration: 1500 });
      this.closeReview();
      if (this.order) {
        this.load(this.order.id);
      }
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '评价失败' });
    } finally {
      this.submitting = false;
    }
  }

  /** 当前订单是否还有未评价的商品（决定「去评价」提示是否展示） */
  hasPendingReview(): boolean {
    if (!this.order || this.order.status !== 3) {
      return false;
    }
    for (const item of this.order.items) {
      if (item.reviewed !== true) {
        return true;
      }
    }
    return false;
  }

  @Builder
  reviewPanel() {
    Column({ space: 12 }) {
      Row() {
        Text('发表评价')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
          .layoutWeight(1)
        Text('关闭')
          .fontSize(13)
          .fontColor('#8A9199')
          .onClick(() => this.closeReview())
      }
      Text(this.reviewItemName)
        .fontSize(12)
        .fontColor('#8A9199')
        .maxLines(1)

      // 星级选择
      Row({ space: 8 }) {
        Text('评分')
          .fontSize(13)
          .fontColor('#182431')
        ForEach([1, 2, 3, 4, 5], (star: number) => {
          Text(star <= this.reviewRating ? '★' : '☆')
            .fontSize(24)
            .fontColor('#F59E0B')
            .onClick(() => {
              this.reviewRating = star;
            })
        })
        Text(this.reviewRating + ' 分')
          .fontSize(12)
          .fontColor('#8A9199')
      }
      .width('100%')

      TextArea({ placeholder: '说说这件商品怎么样，可以帮助其他用户', text: this.reviewContent })
        .height(90)
        .backgroundColor('#F5F6F8')
        .borderRadius(8)
        .onChange((value: string) => {
          this.reviewContent = value;
        })

      Button(this.submitting ? '提交中…' : '提交评价')
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor('#FF3B30')
        .height(42)
        .width('100%')
        .borderRadius(21)
        .enabled(!this.submitting)
        .onClick(() => this.submitReview())
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 14, topRight: 14 })
  }

  /** 取消 / 退款原因选择弹层（自绘单选圈，避免原生控件的回填路径陷阱） */
  @Builder
  reasonSheet() {
    Column({ space: 0 }) {
      Row() {
        Text(this.reasonPanel === 'cancel' ? '选择取消原因' : '选择退款原因')
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
          // 自绘单选圈：选中填充红色，未选中白色描边
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
      Column() {
        // 顶部返回：固定在页面最上方（加载中 / 加载失败时同样可用，避免退不出去）
        Row() {
          Text('← 返回')
            .fontSize(15)
            .fontColor('#0A59F7')
            // 上下内边距把点击热区撑高，方便手指点击
            .padding({ top: 9, bottom: 9, right: 16 })
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })

        if (this.loading) {
          LoadingView()
        } else if (!this.order) {
          EmptyView({
            text: this.failed.length > 0 ? this.failed : '订单不存在',
            actionText: '重试',
            onAction: () => {
              const params = router.getParams() as Record<string, number>;
              this.load(params && params['id'] ? Number(params['id']) : 0);
            }
          })
        } else {
          Scroll() {
            Column({ space: 12 }) {
              // 订单状态
              Column({ space: 4 }) {
                Text(FormatUtil.orderStatus(this.order.status))
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FF3B30')
                if (this.order.status === 0) {
                  // 倒计时每秒刷新（createdAt + 30 分钟），与后端自动取消规则一致
                  Text(this.countdown.length > 0 ? this.countdown : '请在 30 分钟内完成支付，超时订单将自动取消并释放库存')
                    .fontSize(12)
                    .fontColor('#8A9199')
                }
                if (this.order.status === 5) {
                  Text('退款申请已提交，商家审核通过后自动退回（演示环境约 30 秒内完成）')
                    .fontSize(12)
                    .fontColor('#8A9199')
                }
                if (this.hasPendingReview()) {
                  Text('订单已完成，可对商品发表评价')
                    .fontSize(12)
                    .fontColor('#8A9199')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)

              // 收货地址
              Column({ space: 4 }) {
                Text(this.addr('receiver') + '  ' + this.addr('phone'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#182431')
                Text(this.addr('region') + ' ' + this.addr('detail'))
                  .fontSize(12)
                  .fontColor('#8A9199')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)

              // 商品明细
              Column({ space: 12 }) {
                ForEach(this.order.items, (item: OrderItem) => {
                  Column({ space: 8 }) {
                    Row({ space: 10 }) {
                      Image(AppConfig.imgUrl(this.itemSnap(item, 'image')))
                        .width(64)
                        .height(64)
                        .objectFit(ImageFit.Cover)
                        .borderRadius(8)
                      Column({ space: 4 }) {
                        Text(this.itemSnap(item, 'name'))
                          .fontSize(13)
                          .fontColor('#182431')
                          .maxLines(2)
                          .lineHeight(18)
                        Text(FormatUtil.specText(this.itemSnap(item, 'specs')))
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

                    // 评价入口：订单已完成才出现；已评价的只做只读提示
                    if (this.order && this.order.status === 3) {
                      Row() {
                        Blank()
                        if (item.reviewed === true) {
                          Text('已评价')
                            .fontSize(12)
                            .fontColor('#8A9199')
                        } else {
                          Text('去评价')
                            .fontSize(12)
                            .fontColor('#FFFFFF')
                            .padding({ left: 14, right: 14, top: 5, bottom: 5 })
                            .backgroundColor('#FF3B30')
                            .borderRadius(14)
                            .onClick(() => this.openReview(item))
                        }
                      }
                      .width('100%')
                    }
                  }
                })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)

              // 订单信息
              Column({ space: 8 }) {
                Row() {
                  Text('订单编号')
                    .fontSize(12)
                    .fontColor('#8A9199')
                    .layoutWeight(1)
                  Text(this.order.orderNo)
                    .fontSize(12)
                    .fontColor('#182431')
                }
                Row() {
                  Text('下单时间')
                    .fontSize(12)
                    .fontColor('#8A9199')
                    .layoutWeight(1)
                  Text(FormatUtil.dateTime(this.order.createdAt))
                    .fontSize(12)
                    .fontColor('#182431')
                }
                if (this.order.payTime) {
                  Row() {
                    Text('付款时间')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(FormatUtil.dateTime(this.order.payTime))
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                if (this.order.shipTime) {
                  Row() {
                    Text('发货时间')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(FormatUtil.dateTime(this.order.shipTime))
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                if (this.order.finishTime) {
                  Row() {
                    Text('完成时间')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(FormatUtil.dateTime(this.order.finishTime))
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                if (this.order.remark) {
                  Row() {
                    Text('订单备注')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(this.order.remark)
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                if (this.order.cancelReason) {
                  Row() {
                    Text('取消原因')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(this.order.cancelReason)
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                if (this.order.refundReason) {
                  Row() {
                    Text('退款原因')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(this.order.refundReason)
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                if (this.order.refundTime) {
                  Row() {
                    Text('退款时间')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text(FormatUtil.dateTime(this.order.refundTime))
                      .fontSize(12)
                      .fontColor('#182431')
                  }
                }
                Divider().color('#EEF0F3').strokeWidth(0.5)
                Row() {
                  Text('商品总额')
                    .fontSize(12)
                    .fontColor('#8A9199')
                    .layoutWeight(1)
                  Text(FormatUtil.money(this.order.totalAmount))
                    .fontSize(12)
                    .fontColor('#182431')
                }
                if ((this.order.discountAmount ?? 0) > 0) {
                  Row() {
                    Text('优惠券抵扣')
                      .fontSize(12)
                      .fontColor('#8A9199')
                      .layoutWeight(1)
                    Text('- ' + FormatUtil.money(this.order.discountAmount ?? 0))
                      .fontSize(12)
                      .fontColor('#FF3B30')
                  }
                }
                Row() {
                  Text('实付金额')
                    .fontSize(13)
                    .fontColor('#182431')
                    .layoutWeight(1)
                  Text(FormatUtil.money(this.order.payAmount))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FF3B30')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
            }
            .padding(12)
            .alignItems(HorizontalAlign.Start)
            // 内容不足一屏时 Scroll 会把子组件垂直居中（返回栏下方空一大片），
            // 用最小高度撑满视口让内容顶端对齐
            .constraintSize({ minHeight: '100%' })
          }
          .layoutWeight(1)

          // 底部操作
          if (this.order.status === 0) {
            Row({ space: 10 }) {
              Text('取消订单')
                .fontSize(13)
                .fontColor('#8A9199')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .border({ width: 1, color: '#D5D9E0' })
                .borderRadius(20)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.action('cancel'))
              Text('模拟支付')
                .fontSize(13)
                .fontColor('#FFFFFF')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor('#FF3B30')
                .borderRadius(20)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.action('pay'))
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')
          } else if (this.order.status === 1) {
            Row({ space: 10 }) {
              Text('申请退款')
                .fontSize(13)
                .fontColor('#8A9199')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .border({ width: 1, color: '#D5D9E0' })
                .borderRadius(20)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.action('refund'))
              // 无管理端，用「模拟商家发货」把状态推到待收货，打通 收货 → 评价 链路
              Text('模拟商家发货')
                .fontSize(13)
                .fontColor('#FFFFFF')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor('#0A59F7')
                .borderRadius(20)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.action('ship'))
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')
          } else if (this.order.status === 2) {
            Row() {
              Text('确认收货')
                .fontSize(13)
                .fontColor('#FFFFFF')
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor('#FF3B30')
                .borderRadius(20)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .onClick(() => this.action('confirm'))
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#FFFFFF')
          }
        }
      }
      .width('100%')
      .height('100%')

      // 评价面板：遮罩与面板是兄弟节点，点面板不会命中遮罩的关闭事件
      if (this.reviewItemId > 0) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.35)')
          .onClick(() => this.closeReview())
        this.reviewPanel()
      }

      // 取消 / 退款原因弹层
      if (this.reasonPanel.length > 0) {
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
