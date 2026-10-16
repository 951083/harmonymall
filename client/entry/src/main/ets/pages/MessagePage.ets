import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';
import { Message } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 消息中心：站内消息列表 / 未读标记 / 点击即已读
 */
@Entry
@Component
struct MessagePage {

  @State messages: Message[] = [];
  @State loading: boolean = true;
  @State failed: string = '';
  /** 展开的消息 id（0 表示都收起） */
  @State expandedId: number = 0;
  @StorageProp('token') @Watch('onTokenChange') token: string = '';

  onTokenChange(): void {
    this.load();
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.loading = false;
      return;
    }
    this.loading = true;
    this.failed = '';
    try {
      const list: Message[] = await Api.messages();
      this.messages = list ?? [];
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
  }

  unreadCount(): number {
    let count: number = 0;
    for (const message of this.messages) {
      if (message.isRead !== 1) {
        count += 1;
      }
    }
    return count;
  }

  /** 点击消息：展开/收起，首次展开时上报已读 */
  async toggle(message: Message): Promise<void> {
    if (this.expandedId === message.id) {
      this.expandedId = 0;
      return;
    }
    this.expandedId = message.id;
    if (message.isRead === 1) {
      return;
    }
    try {
      await Api.readMessage(message.id);
      // 就地更新：@State 只观测第一层，必须整体替换数组
      const next: Message[] = [];
      for (const item of this.messages) {
        if (item.id === message.id) {
          const copy: Message = {
            id: item.id,
            title: item.title,
            content: item.content,
            type: item.type,
            isRead: 1,
            createdAt: item.createdAt
          };
          next.push(copy);
        } else {
          next.push(item);
        }
      }
      this.messages = next;
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  typeText(type: string): string {
    // 注意：Record 字面量的键必须是「带引号的字符串字面量」，
    // 写成 system / order 这种裸标识符会报 arkts-no-untyped-obj-literals
    const map: Record<string, string> = {
      'system': '系统',
      'order': '订单',
      'coupon': '优惠'
    };
    return map[type] ?? '通知';
  }

  typeColor(type: string): string {
    const map: Record<string, string> = {
      'system': '#0A59F7',
      'order': '#FF9F1A',
      'coupon': '#FF3B30'
    };
    return map[type] ?? '#8A9199';
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
        Text('消息中心')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Blank()
        if (this.unreadCount() > 0) {
          Text(this.unreadCount() + ' 条未读')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor('#FF3B30')
            .borderRadius(10)
        }
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#FFFFFF')

      if (!UserStore.isLogin()) {
        EmptyView({
          text: '登录后查看消息',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.loading) {
        LoadingView()
      } else if (this.messages.length === 0) {
        EmptyView({ text: this.failed.length > 0 ? this.failed : '暂无消息' })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.messages, (message: Message) => {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Text(this.typeText(message.type))
                    .fontSize(10)
                    .fontColor('#FFFFFF')
                    .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                    .backgroundColor(this.typeColor(message.type))
                    .borderRadius(4)
                  Text(message.title)
                    .fontSize(14)
                    .fontWeight(message.isRead === 1 ? FontWeight.Normal : FontWeight.Medium)
                    .fontColor('#182431')
                    .layoutWeight(1)
                    .maxLines(1)
                  if (message.isRead !== 1) {
                    Circle({ width: 8, height: 8 }).fill('#FF3B30')
                  }
                }
                Text(FormatUtil.dateTime(message.createdAt))
                  .fontSize(11)
                  .fontColor('#8A9199')
                Text(message.content)
                  .fontSize(13)
                  .fontColor('#5E6877')
                  .lineHeight(20)
                  .maxLines(this.expandedId === message.id ? 20 : 1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding(12)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => this.toggle(message))
            })
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
