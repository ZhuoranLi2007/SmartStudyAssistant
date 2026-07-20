import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { DataLoadResult, DataSource, MyCourse } from '../model/ProfileModels';
import { CourseService } from '../service/CourseService';

@Component
export struct MyCoursesPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State showCompleted: boolean = false;
  @State courses: MyCourse[] = [];
  @State source: DataSource = DataSource.MOCK;
  @State isLoading: boolean = false;

  aboutToAppear(): void { void this.load(); }

  private async load(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      const result: DataLoadResult<MyCourse[]> = await CourseService.getMyCourses();
      this.courses = result.data;
      this.source = result.source;
    } finally { this.isLoading = false; }
  }

  private visibleCourses(): MyCourse[] {
    return this.courses.filter((item: MyCourse) => item.completed === this.showCompleted);
  }

  private openCourse(courseId: number): void {
    const param: IdRouteParam = new IdRouteParam(); param.id = courseId;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '我的课程' })
        Row({ space: 10 }) {
          Button('学习中').layoutWeight(1).backgroundColor(!this.showCompleted ? '#2F6BFF' : '#D0D5DD').onClick(() => this.showCompleted = false)
          Button('已完成').layoutWeight(1).backgroundColor(this.showCompleted ? '#2F6BFF' : '#D0D5DD').onClick(() => this.showCompleted = true)
        }.padding({ left: 16, right: 16, bottom: 12 }).width('100%')
        if (this.isLoading) {
          Text('正在加载...').fontColor('#667085').margin({ top: 40 })
        } else if (this.visibleCourses().length === 0) {
          EmptyStateView({ title: '暂无课程', description: this.showCompleted ? '还没有已完成课程' : '选择合适课程后会显示在这里' })
            .margin({ left: 16, right: 16 })
        } else {
          List({ space: 12 }) {
            ForEach(this.visibleCourses(), (course: MyCourse) => {
              ListItem() {
                Column({ space: 10 }) {
                  Text(course.name).fontSize(17).fontWeight(FontWeight.Bold).width('100%')
                  Text(`${course.grade} · ${course.subject}`).fontSize(13).fontColor('#667085').width('100%')
                  Progress({ value: course.progress.progress, total: 100, type: ProgressType.Linear }).color('#2F6BFF').width('100%')
                  Row() {
                    Text(`已完成 ${course.progress.completedLessons}/${course.progress.totalLessons} 课时`).fontSize(12).fontColor('#667085').layoutWeight(1)
                    Text(`${course.progress.progress}%`).fontSize(12).fontColor('#2F6BFF')
                  }.width('100%')
                  Text(`下一节：${course.progress.nextLesson}`).fontSize(12).fontColor('#475467').width('100%')
                  if (!course.completed) Button('继续学习').height(38).backgroundColor('#2F6BFF').onClick(() => this.openCourse(course.courseId))
                }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
              }
            }, (course: MyCourse) => `${course.id}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
        }
        if (this.source === DataSource.MOCK) Text('当前课程为演示数据').fontSize(11).fontColor('#98A2B3').margin({ bottom: 10 })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
