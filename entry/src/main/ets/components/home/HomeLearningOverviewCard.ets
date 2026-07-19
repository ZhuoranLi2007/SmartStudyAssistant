import { AppRoutes } from '../../common/AppRoutes';
import { HomeOverview } from '../../model/HomeModels';

@Component
export struct HomeLearningOverviewCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop overview: HomeOverview = {
    studentBound: false, studentName: '', grade: '', subject: '', recentScore: 0,
    weakPoints: [], totalTasks: 0, completedTasks: 0
  };

  build() {
    Row({ space: 12 }) {
      if (this.overview.studentBound) {
        Column({ space: 6 }) {
          Text(`${this.overview.studentName} · ${this.overview.grade}`).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#101828')
          Text(`${this.overview.subject} ${this.overview.recentScore}分`).fontSize(13).fontColor('#2F6BFF')
          Text(`薄弱点：${this.overview.weakPoints.join('、')}`).fontSize(12).fontColor('#667085').maxLines(1)
          Row({ space: 8 }) {
            Progress({ value: this.overview.completedTasks, total: this.overview.totalTasks || 1, type: ProgressType.Linear }).color('#2F6BFF').layoutWeight(1)
            Text(`本周 ${this.overview.completedTasks}/${this.overview.totalTasks}`).fontSize(11).fontColor('#667085')
          }.width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      } else {
        Column({ space: 7 }) {
          Text('尚未绑定学生档案').fontSize(17).fontWeight(FontWeight.Bold)
          Text('立即创建或绑定，获取个性化学习建议').fontSize(12).fontColor('#667085')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }
      Image($r('app.media.realImageGen_education_3')).width(82).height(82).borderRadius(16).objectFit(ImageFit.Cover)
    }.padding(15).width('100%').backgroundColor('#EEF4FF').borderRadius(18)
      .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
  }
}
