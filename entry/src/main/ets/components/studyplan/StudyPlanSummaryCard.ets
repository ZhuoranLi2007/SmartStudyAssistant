@Component
export struct StudyPlanSummaryCard {
  @Prop studentName: string = '';
  @Prop weekLabel: string = '';
  @Prop totalCount: number = 0;
  @Prop completedCount: number = 0;
  @Prop courseCount: number = 0;
  @Prop paperCount: number = 0;
  @Prop progress: number = 0;

  build() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.studentName ? `${this.studentName}的本周计划` : '本周学习计划')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text(this.weekLabel).fontSize(12).fontColor('#667085')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`${this.progress}%`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
      }.width('100%')
      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .color('#2F6BFF').backgroundColor('#DFE7F8').width('100%')
      Row() {
        Column({ space: 4 }) {
          Text(`${this.totalCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('总任务').fontSize(11).fontColor('#667085')
        }.layoutWeight(1)
        Column({ space: 4 }) {
          Text(`${this.completedCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('已完成').fontSize(11).fontColor('#667085')
        }.layoutWeight(1)
        Column({ space: 4 }) {
          Text(`${this.courseCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('课程').fontSize(11).fontColor('#667085')
        }.layoutWeight(1)
        Column({ space: 4 }) {
          Text(`${this.paperCount}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('试卷').fontSize(11).fontColor('#667085')
        }.layoutWeight(1)
      }.width('100%')
    }
    .padding(16).width('100%').backgroundColor('#F4F7FF').borderRadius(18)
    .border({ width: 1, color: '#DCE6FB' })
  }
}
