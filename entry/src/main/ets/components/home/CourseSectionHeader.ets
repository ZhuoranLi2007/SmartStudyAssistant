@Component
export struct CourseSectionHeader {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop title: string = '';
  @Prop moreText: string = '查看更多';
  @Prop routeName: string = '';

  build() {
    Row() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#101828').layoutWeight(1)
      Text(`${this.moreText} ›`).fontSize(12).fontColor('#667085').onClick(() => {
        if (this.routeName) this.appPathStack.pushPathByName(this.routeName, null);
      })
    }.width('100%')
  }
}
