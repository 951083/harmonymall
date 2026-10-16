import router from '@ohos.router';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { Category, PageResult, Product, ProductQuery } from '../model/Models';
import { FormatUtil } from '../common/utils/FormatUtil';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/** 每个二级分类下预览的商品个数 */
const PREVIEW_SIZE: number = 3;

/** 单个二级分类的商品预览缓存 */
class SubPreview {
  subId: number = 0;
  products: Product[] = [];
  loaded: boolean = false;
  failed: string = '';

  constructor(subId: number) {
    this.subId = subId;
  }
}

/**
 * 分类页：左侧一级分类，右侧按二级分类分组预览商品（京东 / 淘宝分类页风格）
 *
 * 商品预览采用「懒加载 + 内存缓存」：
 * 只有进入某个一级分类时才请求其下二级分类的商品，已加载过的分组再次切换回来不会重复请求；
 * 每个分组最多展示 3 个商品，点击缩略图进商品详情，「更多 >」进该分类的商品列表页。
 */
@Component
export struct CategoryPage {

  @State roots: Category[] = [];
  @State current: number = 0;
  @State loading: boolean = true;
  @State failed: string = '';
  /** 二级分类 id -> 商品预览（懒加载缓存） */
  @State previews: SubPreview[] = [];

  aboutToAppear(): void {
    this.load();
  }

  /** 加载分类树，随后补齐当前一级分类下的商品预览 */
  async load(): Promise<void> {
    this.loading = true;
    this.failed = '';
    try {
      const list: Category[] = await Api.categories();
      this.roots = list ?? [];
      this.current = 0;
      this.previews = [];
    } catch (e) {
      this.failed = (e as Error).message ?? '加载失败';
    } finally {
      this.loading = false;
    }
    if (this.failed.length === 0) {
      // 分类骨架先渲染出来，商品预览再逐个补齐（内部已做异常处理，这里无需 await）
      this.loadPreviews();
    }
  }

  currentRoot(): Category | undefined {
    if (this.current < 0 || this.current >= this.roots.length) {
      return undefined;
    }
    return this.roots[this.current];
  }

  currentChildren(): Category[] {
    const root: Category | undefined = this.currentRoot();
    return (root && root.children) ? root.children : [];
  }

  /** 当前一级分类下参与预览的分组：优先二级分类，没有二级分类时回退到一级自身 */
  currentUnits(): Category[] {
    const children: Category[] = this.currentChildren();
    if (children.length > 0) {
      return children;
    }
    const root: Category | undefined = this.currentRoot();
    return root ? [root] : [];
  }

  /* ---------------- 商品预览缓存 ---------------- */

  private previewOf(subId: number): SubPreview | undefined {
    for (const item of this.previews) {
      if (item.subId === subId) {
        return item;
      }
    }
    return undefined;
  }

  /** 尚未加载完成（含请求中） */
  private previewLoading(subId: number): boolean {
    return this.previewOf(subId) === undefined;
  }

  private previewProducts(subId: number): Product[] {
    const item: SubPreview | undefined = this.previewOf(subId);
    return item ? item.products : [];
  }

  private previewFailed(subId: number): string {
    const item: SubPreview | undefined = this.previewOf(subId);
    return item ? item.failed : '';
  }

  /** 拉取当前一级分类下尚未加载的分组（已缓存的直接复用，不重复请求） */
  private async loadPreviews(): Promise<void> {
    const tasks: Promise<void>[] = [];
    for (const unit of this.currentUnits()) {
      const cached: SubPreview | undefined = this.previewOf(unit.id);
      if (cached !== undefined && cached.loaded) {
        continue;
      }
      tasks.push(this.fetchPreview(unit.id));
    }
    if (tasks.length > 0) {
      await Promise.all(tasks);
    }
  }

  private async fetchPreview(subId: number): Promise<void> {
    try {
      const query: ProductQuery = {
        categoryId: subId,
        page: 1,
        size: PREVIEW_SIZE
      };
      const result: PageResult<Product> = await Api.productList(query);
      this.putPreview(subId, result.list ?? [], '');
    } catch (e) {
      this.putPreview(subId, [], (e as Error).message ?? '加载失败');
    }
  }

  /** 整体替换缓存数组以触发刷新（ArkUI 只观测第一层变更） */
  private putPreview(subId: number, products: Product[], failed: string): void {
    const next: SubPreview[] = [];
    let replaced: boolean = false;
    for (const item of this.previews) {
      if (item.subId === subId) {
        next.push(this.newPreview(subId, products, failed));
        replaced = true;
      } else {
        next.push(item);
      }
    }
    if (!replaced) {
      next.push(this.newPreview(subId, products, failed));
    }
    this.previews = next;
  }

  private newPreview(subId: number, products: Product[], failed: string): SubPreview {
    const item: SubPreview = new SubPreview(subId);
    item.products = products;
    item.failed = failed;
    item.loaded = true;
    return item;
  }

  /** 失败重试：先清掉失败缓存，再重新拉取 */
  async retryPreview(subId: number): Promise<void> {
    const next: SubPreview[] = [];
    for (const item of this.previews) {
      if (item.subId !== subId) {
        next.push(item);
      }
    }
    this.previews = next;
    await this.fetchPreview(subId);
  }

  /* ---------------- 跳转 ---------------- */

  private goSearch(unit: Category): void {
    router.pushUrl({
      url: 'pages/SearchPage',
      params: { categoryId: unit.id, name: unit.name }
    });
  }

  private goDetail(id: number): void {
    router.pushUrl({ url: 'pages/DetailPage', params: { id: id } });
  }

  /* ---------------- 视图 ---------------- */

  /** 商品缩略卡：图片 + 名称 + 价格 */
  @Builder
  thumb(p: Product) {
    Column({ space: 4 }) {
      Image(AppConfig.imgUrl(p.mainImage))
        .width('100%')
        .aspectRatio(1)
        .objectFit(ImageFit.Cover)
        .borderRadius(6)
        .backgroundColor('#F5F6F8')
      Text(p.name)
        .fontSize(11)
        .fontColor('#182431')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(FormatUtil.money(p.price))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FF3B30')
        .width('100%')
    }
    .width('100%')
    .padding(6)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .onClick(() => {
      this.goDetail(p.id);
    })
  }

  /** 单个商品位：不足 3 个时用空占位撑住等宽，保证左对齐、间距一致 */
  @Builder
  previewSlot(subId: number, index: number) {
    Column() {
      if (index < this.previewProducts(subId).length) {
        this.thumb(this.previewProducts(subId)[index])
      }
    }
    .layoutWeight(1)
  }

  /** 一行三个商品位 */
  @Builder
  previewRow(subId: number) {
    Row({ space: 8 }) {
      this.previewSlot(subId, 0)
      this.previewSlot(subId, 1)
      this.previewSlot(subId, 2)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  /** 商品加载中的骨架屏 */
  @Builder
  previewSkeleton() {
    Row({ space: 8 }) {
      Column().layoutWeight(1).height(110).backgroundColor('#FFFFFF').borderRadius(8)
      Column().layoutWeight(1).height(110).backgroundColor('#FFFFFF').borderRadius(8)
      Column().layoutWeight(1).height(110).backgroundColor('#FFFFFF').borderRadius(8)
    }
    .width('100%')
  }

  /** 一个二级分类分组：标题 + 更多入口 + 商品预览 */
  @Builder
  previewGroup(unit: Category) {
    Column({ space: 8 }) {
      Row() {
        Text(unit.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Blank()
        Text('更多 >')
          .fontSize(12)
          .fontColor('#8A9199')
          .onClick(() => {
            this.goSearch(unit);
          })
      }
      .width('100%')

      if (this.previewLoading(unit.id)) {
        this.previewSkeleton()
      } else if (this.previewFailed(unit.id).length > 0) {
        Row() {
          Text('商品加载失败')
            .fontSize(12)
            .fontColor('#8A9199')
            .layoutWeight(1)
          Text('重试')
            .fontSize(12)
            .fontColor('#0A59F7')
            .onClick(() => {
              this.retryPreview(unit.id);
            })
        }
        .width('100%')
      } else if (this.previewProducts(unit.id).length === 0) {
        Text('该分类下暂无商品')
          .fontSize(12)
          .fontColor('#8A9199')
      } else {
        this.previewRow(unit.id)
      }
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F7F8FA')
    .borderRadius(10)
  }

  build() {
    Column() {
      if (this.loading) {
        LoadingView()
      } else if (this.failed.length > 0) {
        EmptyView({
          text: this.failed,
          actionText: '重试',
          onAction: () => this.load()
        })
      } else {
        Row() {
          // 左侧一级分类
          // 注意：Row 默认垂直居中（VerticalAlign.Center），若不给高度，
          // List / Scroll 会按内容高度居中，上下各空出一大片 —— 必须撑满高度 + 顶端对齐
          List() {
            ForEach(this.roots, (root: Category, index: number) => {
              ListItem() {
                Row() {
                  Column()
                    .width(3)
                    .height(18)
                    .borderRadius(2)
                    .backgroundColor(this.current === index ? '#0A59F7' : '#00000000')
                  Text(root.name)
                    .layoutWeight(1)
                    .height(46)
                    .fontSize(13)
                    .textAlign(TextAlign.Center)
                    .fontColor(this.current === index ? '#0A59F7' : '#182431')
                    .fontWeight(this.current === index ? FontWeight.Medium : FontWeight.Normal)
                }
                .width(84)
                .backgroundColor(this.current === index ? '#FFFFFF' : '#00000000')
              }
              .onClick(() => {
                this.current = index;
                // 切到该一级分类时补齐它下面还没加载过的商品预览
                this.loadPreviews();
              })
            })
          }
          .width(84)
          .height('100%')
          .backgroundColor('#F0F2F5')

          // 右侧：按二级分类分组预览商品
          Scroll() {
            Column({ space: 10 }) {
              Row() {
                Text(this.currentRoot()?.name ?? '')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#182431')
                Blank()
                Text('共 ' + this.currentUnits().length + ' 个分类')
                  .fontSize(11)
                  .fontColor('#8A9199')
              }
              .width('100%')

              ForEach(this.currentUnits(), (unit: Category) => {
                this.previewGroup(unit)
              }, (unit: Category) => 'unit-' + unit.id)

              if (this.currentUnits().length === 0) {
                Text('该分类下暂无内容')
                  .fontSize(13)
                  .fontColor('#8A9199')
                  .margin({ top: 40 })
              }
            }
            .width('100%')
            .padding(12)
            .alignItems(HorizontalAlign.Start)
            // Scroll 在内容不足一屏时会把子组件垂直居中（文创只有 1 个二级分类时会明显偏下），
            // 用最小高度撑满视口，内容自然顶端对齐；内容超长时仍可正常滚动
            .constraintSize({ minHeight: '100%' })
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor('#FFFFFF')
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
