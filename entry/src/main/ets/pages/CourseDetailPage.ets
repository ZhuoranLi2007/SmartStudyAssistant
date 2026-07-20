import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { Course } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { StudyPlanService } from '../service/StudyPlanService';

@Component
export struct CourseDetailPage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @Prop courseId: number = 1;
  @State isAdding: boolean = false;
  private course: Course = MockDataService.getCourse(this.courseId);

  private async addTask(): Promise<void> {
    if (this.isAdding) return;
    if (this.studentProfileId <= 0) {
      promptAction.showToast({ message: '请先创建或绑定学生档案' });
      return;
    }
    this.isAdding = true;
    try {
      await StudyPlanService.addTask(this.studentProfileId, '课程', this.course.id);
      promptAction.showToast({ message: '已加入本周学习计划' });
    } catch (error) {
      const message: string = `${error}`.includes('409') ? '该课程已经在学习计划中' : '添加失败，请稍后重试';
      promptAction.showToast({ message: message });
    } finally {
      this.isAdding = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '课程详情' })
        Scroll() {
          Column({ space: 18 }) {
            Image($r('app.media.realImageGen_education_6')).width('100%').height(210).borderRadius(20).objectFit(ImageFit.Cover)
            Text(this.course.name).fontSize(26).fontWeight(FontWeight.Bold).width('100%')
            Text(`${this.course.grade} · ${this.course.subject} · ${this.course.level}`).fontColor('#2F6BFF').width('100%')
            Text(this.course.description).fontSize(16).fontColor('#475467').lineHeight(25).width('100%')
            Text(`适合人群：${this.course.suitableFor}`).width('100%')
            Text(`核心知识点：${this.course.knowledgePoints.join('、')}`).width('100%')
            Text('推荐说明：系统会结合学生成绩、薄弱点和学习目标进行规则判断，本课程展示数据为演示内容。').fontSize(14).fontColor('#667085').width('100%')
            if (this.role === 'parent') {
              Button(this.isAdding ? '添加中...' : '加入学习计划').width('100%').backgroundColor('#2F6BFF')
                .enabled(!this.isAdding).onClick(() => void this.addTask())
            } else {
              Text('课程任务由家长账号统一安排').fontSize(13).fontColor('#667085').width('100%').textAlign(TextAlign.Center)
                .padding(12).backgroundColor('#EEF4FF').borderRadius(10)
            }
          }.padding(20).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
