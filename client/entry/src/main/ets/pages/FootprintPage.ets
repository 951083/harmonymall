import router from '@ohos.router';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { SimpleSku } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 浏览足迹：按浏览时间倒序展示看过的商品
 */
@Entry
@Component
struct FootprintPage {

  @State items: SimpleSku[] = [];
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
    if (!UserStore.isLogin()) {
      this.loading = false;
      return;
    }
    this.loading = true;
    this.failed = '';
    try {
      const list: SimpleSku[] = await Api.footprints();
      this.items = list ?? [];
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
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
        Text('浏览足迹')
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
          text: '登录后查看浏览足迹',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.loading) {
        LoadingView()
      } else if (this.items.length === 0) {
        EmptyView({
          text: this.failed.length > 0 ? this.failed : '还没有浏览记录',
          actionText: '去逛逛',
          onAction: () => router.back()
        })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.items, (item: SimpleSku) => {
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
                  if (item.specs) {
                    Text(FormatUtil.specText(item.specs))
                      .fontSize(11)
                      .fontColor('#8A9199')
                      .maxLines(1)
                  }
                  Text(FormatUtil.money(item.price))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FF3B30')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text('>')
                  .fontSize(14)
                  .fontColor('#8A9199')
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => {
                router.pushUrl({ url: 'pages/DetailPage', params: { id: item.productId } });
              })
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
