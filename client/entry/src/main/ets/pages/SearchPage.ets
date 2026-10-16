import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { Product, ProductQuery } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';

/** 搜索历史（应用运行期内有效，重启清空） */
let searchHistory: string[] = [];

/**
 * 搜索页：关键词 + 分类 + 排序 + 商品网格 + 加载更多
 */
@Entry
@Component
struct SearchPage {

  @State keyword: string = '';
  @State categoryId: number = 0;
  @State categoryName: string = '';
  @State sort: string = '';
  @State products: Product[] = [];
  @State page: number = 1;
  @State total: number = 0;
  @State loading: boolean = false;
  @State searched: boolean = false;
  /** 热门搜索词（后端按真实搜索次数统计） */
  @State hotWords: string[] = [];
  private readonly sorts: string[] = ['', 'sales', 'price_asc', 'price_desc'];
  private readonly sortNames: string[] = ['综合', '销量', '价格↑', '价格↓'];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string | number>;
    if (params) {
      if (params['keyword']) {
        this.keyword = params['keyword'] as string;
      }
      if (params['categoryId']) {
        this.categoryId = Number(params['categoryId']);
        this.categoryName = (params['name'] as string) ?? '';
      }
    }
    this.loadHotWords();
    this.doSearch(true);
  }

  /** 热门搜索词：拉取失败静默降级（不展示热词区即可） */
  async loadHotWords(): Promise<void> {
    try {
      const list: string[] = await Api.hotKeywords();
      this.hotWords = list ?? [];
    } catch (e) {
      this.hotWords = [];
    }
  }

  async doSearch(reset: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    const targetPage: number = reset ? 1 : this.page + 1;
    this.loading = true;
    try {
      const query: ProductQuery = {
        keyword: this.keyword.length > 0 ? this.keyword : undefined,
        categoryId: this.categoryId > 0 ? this.categoryId : undefined,
        sort: this.sort.length > 0 ? this.sort : undefined,
        page: targetPage,
        size: AppConfig.PAGE_SIZE
      };
      const result = await Api.productList(query);
      if (reset) {
        this.products = result.list ?? [];
        if (this.keyword.length > 0 && searchHistory.indexOf(this.keyword) < 0) {
          searchHistory.unshift(this.keyword);
          if (searchHistory.length > 10) {
            searchHistory.pop();
          }
        }
      } else {
        const list: Product[] = result.list ?? [];
        for (const p of list) {
          this.products.push(p);
        }
      }
      this.page = result.page ?? targetPage;
      this.total = result.total ?? 0;
      this.searched = true;
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '搜索失败' });
    } finally {
      this.loading = false;
    }
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
        Row({ space: 4 }) {
          Text(FormatUtil.money(p.price))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF3B30')
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
    Column({ space: 8 }) {
      // 顶部返回：固定在页面最上方（加载中 / 空结果时同样可用，避免退不出去）
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

      // 搜索栏
      Row({ space: 8 }) {
        TextInput({ placeholder: '搜索商品', text: this.keyword })
          .height(36)
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.keyword = value;
          })
          .onSubmit(() => {
            this.doSearch(true);
          })
        Button('搜索')
          .fontSize(13)
          .backgroundColor('#0A59F7')
          .fontColor('#FFFFFF')
          .height(36)
          .onClick(() => this.doSearch(true))
      }
      .padding({ left: 12, right: 12, top: 8 })

      // 分类提示 + 排序
      Row({ space: 10 }) {
        if (this.categoryId > 0) {
          Text(this.categoryName + ' ×')
            .fontSize(12)
            .fontColor('#0A59F7')
            .onClick(() => {
              this.categoryId = 0;
              this.categoryName = '';
              this.doSearch(true);
            })
        }
        ForEach(this.sortNames, (name: string, index: number) => {
          Text(name)
            .fontSize(12)
            .fontColor(this.sort === this.sorts[index] ? '#0A59F7' : '#8A9199')
            .onClick(() => {
              this.sort = this.sorts[index];
              this.doSearch(true);
            })
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12 })

      // 热门搜索：只在「没有关键词、也没选分类」时展示。
      // 注意不能用 this.searched 判断——本页进入时就会自动拉一次商品列表，
      // searched 恒为 true，热词区会永远不显示
      if (this.keyword.length === 0 && this.categoryId === 0 && this.hotWords.length > 0) {
        Column({ space: 8 }) {
          Text('热门搜索')
            .fontSize(12)
            .fontColor('#8A9199')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.hotWords, (word: string, index: number) => {
              Row({ space: 4 }) {
                // 前三名标红，突出「热」榜
                Text(String(index + 1))
                  .fontSize(10)
                  .fontColor(index < 3 ? '#FFFFFF' : '#8A9199')
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  .backgroundColor(index < 3 ? '#FF3B30' : '#EEF0F3')
                  .borderRadius(3)
                Text(word)
                  .fontSize(12)
                  .fontColor('#182431')
              }
              .padding({ left: 10, right: 12, top: 5, bottom: 5 })
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.keyword = word;
                this.doSearch(true);
              })
            })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12 })
      }

      // 搜索历史（同样只看有没有关键词 / 分类）
      if (this.keyword.length === 0 && this.categoryId === 0 && searchHistory.length > 0) {
        Column({ space: 8 }) {
          Text('历史搜索')
            .fontSize(12)
            .fontColor('#8A9199')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(searchHistory, (word: string) => {
              Text(word)
                .fontSize(12)
                .fontColor('#182431')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#FFFFFF')
                .borderRadius(14)
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.keyword = word;
                  this.doSearch(true);
                })
            })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12 })
      }

      // 结果列表
      if (this.products.length === 0 && !this.loading) {
        EmptyView({ text: this.searched ? '没有找到相关商品' : '输入关键词搜索商品' })
      } else {
        Scroll() {
          Column({ space: 8 }) {
            Grid() {
              ForEach(this.products, (p: Product) => {
                GridItem() {
                  this.productCard(p)
                }
              })
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(8)
            .rowsGap(8)

            if (this.products.length < this.total) {
              Button('加载更多')
                .fontSize(13)
                .fontColor('#0A59F7')
                .backgroundColor('#FFFFFF')
                .height(36)
                .width('60%')
                .onClick(() => this.doSearch(false))
            }
          }
          .padding({ left: 12, right: 12, bottom: 16 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
