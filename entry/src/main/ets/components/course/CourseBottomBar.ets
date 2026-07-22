@Component
export struct CourseBottomBar {
  @Prop isFavorite: boolean = false;
  @Prop favoriteBusy: boolean = false;
  @Prop isEnrolled: boolean = false;
  @Prop enrollBusy: boolean = false;
  @Prop isAdding: boolean = false;
  @Prop isAdded: boolean = false;
  onToggleFavorite: () => void = (): void => {};
  onEnroll: () => void = (): void => {};
  onAddPlan: () => void = (): void => {};

  private enrollText(): string {
    if (this.enrollBusy) return '加入中...';
    if (this.isEnrolled) return '已加入课程';
    return '加入课程';
  }

  private planText(): string {
    if (this.isAdding) return '添加中...';
    if (this.isAdded) return '已在计划';
    return '加入计划';
  }

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.isFavorite ? '♥' : '♡').fontSize(22).fontColor(this.isFavorite ? '#F04438' : '#475467')
        Text(this.isFavorite ? '已收藏' : '收藏').fontSize(10).fontColor('#475467')
      }.width(48).enabled(!this.favoriteBusy).onClick(() => this.onToggleFavorite())
      Button(this.enrollText()).layoutWeight(1).height(46).fontSize(14).fontWeight(FontWeight.Medium)
        .backgroundColor(this.isEnrolled ? '#D0D5DD' : '#12B76A')
        .enabled(!this.isEnrolled && !this.enrollBusy)
        .onClick(() => this.onEnroll())
      Button(this.planText()).layoutWeight(1).height(46).fontSize(14).fontWeight(FontWeight.Bold)
        .backgroundColor(this.isAdded ? '#B8C4DA' : '#2F6BFF')
        .enabled(!this.isAdding && !this.isAdded)
        .onClick(() => this.onAddPlan())
    }
    .width('100%').padding({ left: 14, right: 14, top: 10, bottom: 10 }).backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#EAECF0' })
  }
}
