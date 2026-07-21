@Component
export struct CourseBottomBar {
  @Prop role: string = 'parent';
  @Prop isFavorite: boolean = false;
  @Prop favoriteBusy: boolean = false;
  @Prop isAdding: boolean = false;
  @Prop isAdded: boolean = false;
  onToggleFavorite: () => void = (): void => {};
  onAddPlan: () => void = (): void => {};

  private planText(): string {
    if (this.role !== 'parent') return '由家长安排学习计划';
    if (this.isAdding) return '添加中...';
    if (this.isAdded) return '已加入学习计划';
    return '加入学习计划';
  }

  build() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(this.isFavorite ? '♥' : '♡').fontSize(24).fontColor(this.isFavorite ? '#F04438' : '#475467')
        Text(this.isFavorite ? '已收藏' : '收藏').fontSize(10).fontColor('#475467')
      }.width(58).enabled(!this.favoriteBusy).onClick(() => this.onToggleFavorite())
      Button(this.planText()).layoutWeight(1).height(48).fontSize(16).fontWeight(FontWeight.Bold)
        .backgroundColor(this.isAdded || this.role !== 'parent' ? '#B8C4DA' : '#2F6BFF')
        .enabled(this.role === 'parent' && !this.isAdding && !this.isAdded)
        .onClick(() => this.onAddPlan())
    }
    .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 }).backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#EAECF0' })
  }
}
