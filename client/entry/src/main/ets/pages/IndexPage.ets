import { HomePage } from './HomePage';
import { CategoryPage } from './CategoryPage';
import { CartPage } from './CartPage';
import { MePage } from './MePage';

/**
 * 主容器：底部自定义 Tab（首页 / 分类 / 购物车 / 我的）
 */
@Entry
@Component
struct IndexPage {

  @State currentIndex: number = 0;
  private readonly tabs: string[] = ['首页', '分类', '购物车', '我的'];

  @Builder
  tabItem(index: number, name: string) {
    Column({ space: 2 }) {
      Text(name)
        .fontSize(this.currentIndex === index ? 13 : 12)
        .fontColor(this.currentIndex === index ? '#0A59F7' : '#8A9199')
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .padding(6)
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  build() {
    Column() {
      Stack() {
        if (this.currentIndex === 0) {
          HomePage()
        } else if (this.currentIndex === 1) {
          CategoryPage()
        } else if (this.currentIndex === 2) {
          CartPage()
        } else {
          MePage()
        }
      }
      .layoutWeight(1)

      Row() {
        ForEach(this.tabs, (name: string, index: number) => {
          this.tabItem(index, name)
        })
      }
      .width('100%')
      .height(52)
      .backgroundColor('#FFFFFF')
      .justifyContent(FlexAlign.SpaceAround)
      .border({ width: { top: 0.5 }, color: '#EEF0F3' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
