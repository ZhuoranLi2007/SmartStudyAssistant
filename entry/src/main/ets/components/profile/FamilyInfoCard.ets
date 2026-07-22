import { AppRoutes } from '../../common/AppRoutes';
import { ProfileOverview } from '../../model/ProfileModels';

@Component
export struct FamilyInfoCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop overview: ProfileOverview = {
    familyCode: '', studentBindCode: '', studentName: '', studentBound: true,
    studentProfileId: 0,
    learning: { courseCount: 0, weeklyTaskCount: 0, favoriteCount: 0, wrongQuestionCount: 0 }
  };

  build() {
    Column({ space: 14 }) {
      Text('学习档案').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      Text(this.overview.studentName ? `当前档案：${this.overview.studentName}` : '注册后已自动创建空白学习档案')
        .fontSize(14).fontColor('#344054').width('100%')
      Text('课程、试卷、收藏、错题和学习计划都会记在这份档案里。')
        .fontSize(12).fontColor('#667085').width('100%')
      Button('编辑学习档案').width('100%').backgroundColor('#2F6BFF')
        .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }
}
