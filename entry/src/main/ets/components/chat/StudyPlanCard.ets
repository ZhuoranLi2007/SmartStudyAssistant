import { AppRoutes } from '../../common/AppRoutes';
import { AiCard, AiPlanTask } from '../../model/AiModels';

@Component
export struct StudyPlanCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop card: AiCard;

  private openPlan(): void {
    this.appPathStack.pushPathByName(AppRoutes.STUDY_PLAN, null);
  }

  private dayText(date: string): string {
    if (!date) return '任务';
    const parts: string[] = date.split('-');
    if (parts.length < 3) return date;
    return `${parts[1]}/${parts[2]}`;
  }

  build() {
    Column({ space: 9 }) {
      Row() {
        Text('▣ 学习计划（本周）').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
        Blank()
        Text(`${this.card.tasks ? this.card.tasks.length : 0}项`).fontSize(10).fontColor('#667085')
      }.width('100%')
      if (this.card.tasks && this.card.tasks.length > 0) {
        ForEach(this.card.tasks.slice(0, 4), (task: AiPlanTask) => {
          Row({ space: 9 }) {
            Text(this.dayText(task.date)).fontSize(10).fontColor('#2F6BFF').width(42).textAlign(TextAlign.Center)
              .padding({ top: 4, bottom: 4 }).backgroundColor('#EEF4FF').borderRadius(8)
            Column({ space: 2 }) {
              Text(task.title).fontSize(12).fontWeight(FontWeight.Medium).maxLines(1).width('100%')
              Text(`${task.taskType} · ${task.durationMinutes}分钟`).fontSize(10).fontColor('#667085').width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
        }, (task: AiPlanTask) => `${task.id}_${task.date}`)
      } else {
        Text(this.card.subtitle || '学习计划已生成，可进入学习计划查看').fontSize(12).fontColor('#667085').width('100%')
      }
      Button('查看完整计划').fontSize(12).height(34).width('100%').backgroundColor('#356DF3').onClick(() => this.openPlan())
    }.padding(13).width('100%').backgroundColor('#F9FBFF').borderRadius(14).border({ width: 1, color: '#DCE6FB' })
  }
}
