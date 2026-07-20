import { StudyPlanSummary } from '../../model/StudyPlanModels';

@Component
export struct StudyPlanSummaryCard {
  @Prop studentName: string = '';
  @Prop weekLabel: string = '';
  @Prop summary: StudyPlanSummary = {
    totalCount: 0, completedCount: 0, courseCount: 0, paperCount: 0,
    wrongQuestionCount: 0, unmasteredWrongQuestionCount: 0, totalMinutes: 0, progress: 0
  };

  @Builder
  private metric(value: number, label: string) {
    Column({ space: 4 }) {
      Text(`${value}`).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
      Text(label).fontSize(11).fontColor('#667085')
    }.layoutWeight(1)
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.studentName ? `${this.studentName}的本周计划` : '本周学习计划')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text(this.weekLabel).fontSize(12).fontColor('#667085')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`${this.summary.progress}%`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
      }.width('100%')
      Progress({ value: this.summary.progress, total: 100, type: ProgressType.Linear })
        .color('#2F6BFF').backgroundColor('#DFE7F8').width('100%')
      Row() {
        this.metric(this.summary.totalCount, '总任务')
        this.metric(this.summary.completedCount, '已完成')
        this.metric(this.summary.courseCount, '课程')
        this.metric(this.summary.paperCount, '试卷')
      }.width('100%')
      Row() {
        Text(`错题任务 ${this.summary.wrongQuestionCount} 项`).fontSize(12).fontColor('#7A5AF8').layoutWeight(1)
        Text(`待掌握 ${this.summary.unmasteredWrongQuestionCount} 题`).fontSize(12).fontColor('#D92D20')
      }.width('100%')
      Row() {
        Text('本周计划时长').fontSize(12).fontColor('#667085').layoutWeight(1)
        Text(`${this.summary.totalMinutes} 分钟`).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#344054')
      }.width('100%')
    }
    .padding(16).width('100%').backgroundColor('#F4F7FF').borderRadius(18)
    .border({ width: 1, color: '#DCE6FB' })
  }
}
