import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { User } from '../model/Models';

/**
 * 个人中心：用户信息 / 订单入口 / 地址 / 退出登录
 */
@Component
export struct MePage {

  @State user: User | null = null;
  // 登录态变化时自动刷新：从 LoginPage 登录成功返回本页时，本组件不会重建
  // （aboutToAppear 不再执行），必须靠监听 AppStorage 的 token 变化来刷新，
  // 否则页面会一直停留在「未登录」
  @StorageProp('token') @Watch('onTokenChange') token: string = '';

  onTokenChange(): void {
    this.refresh();
  }

  aboutToAppear(): void {
    this.refresh();
  }

  refresh(): void {
    if (UserStore.isLogin()) {
      Api.profile()
        .then((u: User) => {
          this.user = u;
        })
        .catch(() => {
          this.user = UserStore.user();
        });
    } else {
      this.user = null;
    }
  }

  logout(): void {
    UserStore.logout();
    this.user = null;
    promptAction.showToast({ message: '已退出登录', duration: 1200 });
  }

  @Builder
  functionRow(name: string, onClick: () => void) {
    Row() {
      Text(name)
        .fontSize(14)
        .fontColor('#182431')
        .layoutWeight(1)
      Text('>')
        .fontSize(14)
        .fontColor('#8A9199')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .backgroundColor('#FFFFFF')
    .onClick(() => onClick())
  }

  build() {
    Column({ space: 12 }) {
      // 用户卡片
      Row({ space: 14 }) {
        if (this.user && this.user.avatar) {
          // 头像多为相对路径（/img/avatar.png），必须补全图片域名前缀才能加载
          Image(AppConfig.imgUrl(this.user.avatar))
            .width(52)
            .height(52)
            .borderRadius(26)
            .objectFit(ImageFit.Cover)
        } else {
          Stack() {
            Circle({ width: 52, height: 52 }).fill('#0A59F7')
            Text(this.user && this.user.nickname
              ? this.user.nickname.substring(0, 1)
              : '客')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
          }
        }
        Column({ space: 4 }) {
          Text(this.user ? (this.user.nickname ?? this.user.username) : '未登录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
          if (this.user) {
            Text('@' + this.user.username)
              .fontSize(12)
              .fontColor('#8A9199')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.user) {
          Button('登录 / 注册')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#0A59F7')
            .height(34)
            .padding({ left: 14, right: 14 })
            .borderRadius(17)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })
        } else {
          Text('退出')
            .fontSize(13)
            .fontColor('#8A9199')
            .onClick(() => this.logout())
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .margin({ left: 12, right: 12, top: 12 })

      // 我的订单
      Column({ space: 10 }) {
        Row() {
          Text('我的订单')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .layoutWeight(1)
          Text('查看全部')
            .fontSize(12)
            .fontColor('#8A9199')
            .onClick(() => {
              router.pushUrl({ url: 'pages/OrderListPage' });
            })
        }
        Row({ space: 8 }) {
          ForEach(['待付款', '待发货', '待收货', '已完成'], (name: string, index: number) => {
            Text(name)
              .fontSize(12)
              .fontColor('#182431')
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
              .padding({ top: 8, bottom: 8 })
              .backgroundColor('#F5F6F8')
              .borderRadius(8)
              .onClick(() => {
                router.pushUrl({ url: 'pages/OrderListPage', params: { status: index } });
              })
          })
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .margin({ left: 12, right: 12 })

      // 功能列表
      Column({ space: 0 }) {
        this.functionRow('收货地址', () => {
          router.pushUrl({ url: 'pages/AddressListPage' });
        })
        this.functionRow('我的收藏', () => {
          router.pushUrl({ url: 'pages/FavoritePage' });
        })
        this.functionRow('浏览足迹', () => {
          router.pushUrl({ url: 'pages/FootprintPage' });
        })
        this.functionRow('我的优惠券', () => {
          router.pushUrl({ url: 'pages/CouponPage' });
        })
        this.functionRow('消息中心', () => {
          router.pushUrl({ url: 'pages/MessagePage' });
        })
        this.functionRow('编辑资料', () => {
          router.pushUrl({ url: 'pages/ProfileEditPage' });
        })
        this.functionRow('关于鸿蒙商城', () => {
          promptAction.showToast({ message: 'HarmonyMall 毕业设计 Demo', duration: 1500 });
        })
      }
      .borderRadius(8)
      .clip(true)
      .margin({ left: 12, right: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
