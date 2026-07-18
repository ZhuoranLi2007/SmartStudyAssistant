import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { Course } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';

@Component
export struct CourseDetailPage {
  @Prop courseId: number = 1;
  private course: Course = MockDataService.getCourse(this.courseId);

  private addTask(): void {
    MockDataService.addTask(this.course.name, '课程', this.course.subject, this.course.difficulty);
    promptAction.showToast({ message: '已加入学习计划' });
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
            Button('加入学习计划').width('100%').backgroundColor('#2F6BFF').onClick(() => this.addTask())
          }.padding(20).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
