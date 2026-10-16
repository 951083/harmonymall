/**
 * 加载中占位
 */
@Component
export struct LoadingView {

  build() {
    Column({ space: 8 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color('#0A59F7')
      Text('加载中...')
        .fontSize(12)
        .fontColor('#8A9199')
    }
    .width('100%')
    .padding(48)
    .justifyContent(FlexAlign.Center)
  }
}
