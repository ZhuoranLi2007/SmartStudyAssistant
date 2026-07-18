@Component
export struct PageHeader {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop title: string = '';
  @Prop showBack: boolean = true;

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Text('‹')
          .fontSize(34)
          .fontColor('#101828')
          .onClick(() => this.appPathStack.pop())
      }
      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#101828')
    }
    .width('100%')
    .height(60)
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.White)
  }
}
