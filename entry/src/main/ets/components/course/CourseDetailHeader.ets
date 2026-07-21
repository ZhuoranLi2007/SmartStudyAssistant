@Component
export struct CourseDetailHeader {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop isFavorite: boolean = false;
  @Prop favoriteBusy: boolean = false;
  onToggleFavorite: () => void = (): void => {};

  build() {
    Row({ space: 12 }) {
      Text('‹').fontSize(34).fontColor('#172033').onClick(() => this.appPathStack.pop())
      Text('课程详情').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#172033').layoutWeight(1)
      Row({ space: 5 }) {
        Text(this.isFavorite ? '♥' : '♡').fontSize(23).fontColor(this.isFavorite ? '#F04438' : '#667085')
        Text(this.isFavorite ? '已收藏' : '收藏').fontSize(13).fontColor(this.isFavorite ? '#F04438' : '#475467')
      }.enabled(!this.favoriteBusy).onClick(() => this.onToggleFavorite())
    }
    .width('100%').height(58).padding({ left: 16, right: 18 }).backgroundColor(Color.White)
  }
}
