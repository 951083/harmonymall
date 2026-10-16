import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { Banner, Category, HomeData, Product } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 首页：搜索栏 / 轮播图 / 分类金刚区 / 推荐商品
 */
@Component
export struct HomePage {

  @State banners: Banner[] = [];
  @State categories: Category[] = [];
  @State recommend: Product[] = [];
  @State loading: boolean = true;
  @State failed: string = '';
  @State bannerIndex: number = 0;

  aboutToAppear(): void {
    hilog.info(0x0000, 'HarmonyMall', '[Home] aboutToAppear 被调用');
    this.loadData();
  }

  async loadData(): Promise<void> {
    hilog.info(0x0000, 'HarmonyMall', '[Home] loadData 开始');
    this.loading = true;
    this.failed = '';
    try {
      const data: HomeData = await Api.home();
      this.banners = data.banners ?? [];
      this.categories = data.categories ?? [];
      this.recommend = data.recommend ?? [];
      hilog.info(0x0000, 'HarmonyMall', '[Home] 加载成功 banners=' + this.banners.length + ' categories=' + this.categories.length + ' products=' + this.recommend.length);
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
      hilog.error(0x0000, 'HarmonyMall', '[Home] 加载失败: ' + this.failed);
    } finally {
      this.loading = false;
      hilog.info(0x0000, 'HarmonyMall', '[Home] loadData 结束 loading=' + this.loading);
    }
  }

  private colorOf(id: number): string {
    const colors: string[] = ['#0A59F7', '#F59E0B', '#10B981', '#8B5CF6'];
    return colors[id % colors.length];
  }

  @Builder
  productCard(p: Product) {
    Column({ space: 6 }) {
      Image(AppConfig.imgUrl(p.mainImage))
        .width('100%')
        .aspectRatio(1)
        .objectFit(ImageFit.Cover)
      Column({ space: 4 }) {
        Text(p.name)
          .fontSize(13)
          .fontColor('#182431')
          .maxLines(2)
          .lineHeight(18)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 4 }) {
          Text(FormatUtil.money(p.price))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF3B30')
          if (p.originalPrice && p.originalPrice > p.price) {
            Text(FormatUtil.money(p.originalPrice))
              .fontSize(11)
              .fontColor('#8A9199')
              .decoration({ type: TextDecorationType.LineThrough })
          }
        }
        Text('已售 ' + p.sales)
          .fontSize(11)
          .fontColor('#8A9199')
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 8, right: 8, bottom: 8 })
    }
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .clip(true)
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { id: p.id } });
    })
  }

  build() {
    Column() {
      // 顶部搜索栏
      Row() {
        Text('搜索商品')
          .fontSize(13)
          .fontColor('#8A9199')
          .layoutWeight(1)
          .margin({ left: 4 })
      }
      .height(36)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .margin({ left: 12, right: 12, top: 8, bottom: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/SearchPage' });
      })

      if (this.loading) {
        LoadingView()
      } else if (this.failed.length > 0) {
        EmptyView({
          text: this.failed,
          actionText: '重试',
          onAction: () => this.loadData()
        })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 轮播图
            // 展示比例固定 2.8:1，与服务端横幅图片的裁剪比例一致 —— 端上不再发生裁切。
            // （此前写死 height(160)，与源图 3:1 的比例不符，ImageFit.Cover 会把两侧文案裁掉）
            if (this.banners.length > 0) {
              Column() {
                Swiper() {
                  ForEach(this.banners, (banner: Banner) => {
                    Image(AppConfig.imgUrl(banner.image))
                      .width('100%')
                      .height('100%')
                      .objectFit(ImageFit.Cover)
                  })
                }
                .width('100%')
                .height('100%')
                .indicator(true)
                .indicatorStyle({ selectedColor: '#0A59F7' })
                .loop(true)
                .autoPlay(true)
                .onChange((index: number) => {
                  this.bannerIndex = index;
                })
                .onClick(() => {
                  const banner: Banner = this.banners[this.bannerIndex];
                  if (banner && banner.linkType === 'product' && banner.linkValue) {
                    router.pushUrl({ url: 'pages/DetailPage', params: { id: Number(banner.linkValue) } });
                  } else if (banner && banner.linkType === 'category' && banner.linkValue) {
                    router.pushUrl({
                      url: 'pages/SearchPage',
                      params: { categoryId: Number(banner.linkValue) }
                    });
                  }
                })
              }
              .width('100%')
              .aspectRatio(2.8)
              .borderRadius(8)
              .clip(true)
            }

            // 分类金刚区
            Row({ space: 8 }) {
              ForEach(this.categories, (cat: Category) => {
                Column({ space: 6 }) {
                  Stack() {
                    Circle({ width: 44, height: 44 }).fill(this.colorOf(cat.id))
                    Text(cat.name.length > 0 ? cat.name.substring(0, 1) : '类')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                  }
                  Text(cat.name)
                    .fontSize(12)
                    .fontColor('#182431')
                }
                .layoutWeight(1)
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/SearchPage',
                    params: { categoryId: cat.id, name: cat.name }
                  });
                })
              })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 4 })

            // 推荐商品
            Column({ space: 8 }) {
              Row() {
                Text('为你推荐')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#182431')
                  .layoutWeight(1)
                Text('更多')
                  .fontSize(12)
                  .fontColor('#8A9199')
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/SearchPage' });
                  })
              }
              .width('100%')

              Grid() {
                ForEach(this.recommend, (p: Product) => {
                  GridItem() {
                    this.productCard(p)
                  }
                })
              }
              .columnsTemplate('1fr 1fr')
              .columnsGap(8)
              .rowsGap(8)
            }
            .padding({ left: 12, right: 12, bottom: 16 })
            .alignItems(HorizontalAlign.Start)
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
