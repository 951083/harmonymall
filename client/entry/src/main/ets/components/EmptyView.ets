/**
 * 空状态占位
 */
@Component
export struct EmptyView {

  @Prop text: string = '暂无数据';
  actionText: string = '';
  // 注意：不能声明为 private，否则外部无法通过构造参数注入回调（编译器仅告警，点击将静默失效）
  onAction: () => void = () => { };

  build() {
    Column({ space: 12 }) {
      Stack() {
        Circle({ width: 48, height: 48 })
          .fill('#F5F6F8')
          .stroke('#D5D9E0')
          .strokeWidth(1)
          .strokeDashArray([6, 4])
        Text('空')
          .fontSize(14)
          .fontColor('#8A9199')
      }
      Text(this.text)
        .fontSize(13)
        .fontColor('#8A9199')
      if (this.actionText.length > 0) {
        Button(this.actionText)
          .fontSize(13)
          .backgroundColor('#0A59F7')
          .fontColor('#FFFFFF')
          .height(32)
          .padding({ left: 16, right: 16 })
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
    .padding(48)
    .justifyContent(FlexAlign.Center)
  }
}
