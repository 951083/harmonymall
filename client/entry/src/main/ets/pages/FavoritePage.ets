import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { SimpleSku } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 我的收藏：列表 / 取消收藏 / 进商品详情
 */
@Entry
@Component
struct FavoritePage {

  @State items: SimpleSku[] = [];
  @State loading: boolean = true;
  @State failed: string = '';
  // 登录态变化时自动刷新（登录 / 退出后返回本页不会重建）
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
      const list: SimpleSku[] = await Api.favorites();
      this.items = list ?? [];
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
  }

  async remove(skuId: number): Promise<void> {
    try {
      await Api.removeFavorite(skuId);
      // 整体替换数组才能触发刷新（@State 只观测第一层）
      const rest: SimpleSku[] = [];
      for (const item of this.items) {
        if (item.skuId !== skuId) {
          rest.push(item);
        }
      }
      this.items = rest;
      promptAction.showToast({ message: '已取消收藏', duration: 1200 });
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  @Builder
  skuRow(item: SimpleSku) {
    Row({ space: 10 }) {
      // 点击图片 / 名称进详情；把点击区限制在这两块上，
      // 避免「取消收藏」被外层的行点击冒泡一起触发（点一下跳两次）
      Row({ space: 10 }) {
        Image(AppConfig.imgUrl(item.image))
          .width(72)
          .height(72)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
        Column({ space: 6 }) {
          Text(item.name)
            .fontSize(13)
            .fontColor('#182431')
            .maxLines(2)
            .lineHeight(18)
          Text(FormatUtil.money(item.price))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF3B30')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => {
        router.pushUrl({ url: 'pages/DetailPage', params: { id: item.productId } });
      })

      Text('取消收藏')
        .fontSize(12)
        .fontColor('#8A9199')
        .padding({ left: 12, right: 12, top: 5, bottom: 5 })
        .border({ width: 1, color: '#D5D9E0' })
        .borderRadius(14)
        .onClick(() => this.remove(item.skuId))
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  build() {
    Column() {
      // 顶部返回栏
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontColor('#0A59F7')
          .padding({ top: 9, bottom: 9, right: 16 })
          .onClick(() => {
            router.back();
          })
        Text('我的收藏')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Blank()
        if (this.items.length > 0) {
          Text('共 ' + this.items.length + ' 件')
            .fontSize(12)
            .fontColor('#8A9199')
        }
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#FFFFFF')

      if (!UserStore.isLogin()) {
        EmptyView({
          text: '登录后查看收藏',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.loading) {
        LoadingView()
      } else if (this.items.length === 0) {
        EmptyView({
          text: this.failed.length > 0 ? this.failed : '还没有收藏任何商品',
          actionText: '去逛逛',
          onAction: () => router.back()
        })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.items, (item: SimpleSku) => {
              this.skuRow(item)
            })
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
          // 内容不足一屏时 Scroll 会把子组件垂直居中，用最小高度撑满视口让内容顶端对齐
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
