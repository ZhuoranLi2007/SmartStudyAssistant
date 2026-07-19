@Component
export struct EmptyStateView {
  @Prop title: string = '暂无数据';
  @Prop description: string = '这里还没有内容';

  build() {
    Column({ space: 10 }) {
      Text('○').fontSize(44).fontColor('#B2CCFF')
      Text(this.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#344054')
      Text(this.description).fontSize(13).fontColor('#98A2B3').textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 52, bottom: 52, left: 24, right: 24 })
    .backgroundColor(Color.White)
    .borderRadius(18)
  }
}
