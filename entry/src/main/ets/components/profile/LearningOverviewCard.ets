import { AppRoutes } from '../../common/AppRoutes';
import { LearningOverview } from '../../model/ProfileModels';

@Component
export struct LearningOverviewCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop overview: LearningOverview = { courseCount: 0, weeklyTaskCount: 0, favoriteCount: 0, wrongQuestionCount: 0 };

  @Builder
  private metric(value: number, label: string, routeName: string) {
    Column({ space: 5 }) {
      Text(`${value}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#101828')
      Text(label).fontSize(12).fontColor('#667085')
    }
    .layoutWeight(1)
    .onClick(() => this.appPathStack.pushPathByName(routeName, null))
  }

  build() {
    Column({ space: 14 }) {
      Text('学习概览').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      Row() {
        this.metric(this.overview.courseCount, '已报名课程', AppRoutes.MY_COURSES)
        this.metric(this.overview.weeklyTaskCount, '本周任务', AppRoutes.STUDY_PLAN)
        this.metric(this.overview.favoriteCount, '我的收藏', AppRoutes.MY_FAVORITES)
        this.metric(this.overview.wrongQuestionCount, '错题数量', AppRoutes.WRONG_QUESTIONS)
      }.width('100%')
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }
}
