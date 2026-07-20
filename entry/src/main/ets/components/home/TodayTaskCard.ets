import { AppRoutes } from '../../common/AppRoutes';
import { TodayTaskSummary } from '../../model/HomeModels';

@Component
export struct TodayTaskCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop task: TodayTaskSummary = { totalCount: 0, completedCount: 0, nextTask: '' };

  build() {
    Row({ space: 12 }) {
      Text('今').width(46).height(46).textAlign(TextAlign.Center).fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor(Color.White).linearGradient({ angle: 120, colors: [['#2F6BFF', 0], ['#7A5AF8', 1]] }).borderRadius(14)
      Column({ space: 5 }) {
        Text(`今日任务 ${this.task.completedCount}/${this.task.totalCount}`).fontSize(15).fontWeight(FontWeight.Bold)
        Text(`下一项：${this.task.nextTask || '暂无待办任务'}`).fontSize(11).fontColor('#667085').maxLines(1)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('去学习 ›').fontSize(12).fontColor('#2F6BFF')
    }.padding(14).width('100%').backgroundColor(Color.White).borderRadius(17)
      .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDY_PLAN, null))
  }
}
