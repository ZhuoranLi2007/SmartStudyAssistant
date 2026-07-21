import { promptAction } from '@kit.ArkUI';
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
  @State source: DataSource = DataSource.LIVE;
  @State isLoading: boolean = false;
  @State busyCourseId: number = 0;

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      const result: DataLoadResult<MyCourse[]> = await CourseService.getMyCourses();
      this.courses = result.data;
      this.source = result.source;
    } finally {
      this.isLoading = false;
    }
  }

  private visibleCourses(): MyCourse[] {
    return this.courses.filter((item: MyCourse) => item.completed === this.showCompleted);
  }

  private openCourse(courseId: number): void {
    const param: IdRouteParam = new IdRouteParam();
    param.id = courseId;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  private async markCompleted(course: MyCourse): Promise<void> {
    if (this.busyCourseId > 0 || course.completed) return;
    this.busyCourseId = course.courseId;
    try {
      await CourseService.complete(course.courseId);
      const next: MyCourse[] = [];
      for (let index: number = 0; index < this.courses.length; index++) {
        const item: MyCourse = this.courses[index];
        if (item.id === course.id) {
          next.push({
            id: item.id,
            courseId: item.courseId,
            name: item.name,
            grade: item.grade,
            subject: item.subject,
            completed: true,
            progress: item.progress
          });
        } else {
          next.push(item);
        }
      }
      this.courses = next;
      promptAction.showToast({ message: '已移到「已完成」' });
    } catch (error) {
      promptAction.showToast({ message: '标记完成失败，请稍后重试' });
      console.error(`标记课程完成失败: ${error}`);
    } finally {
      this.busyCourseId = 0;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '我的课程' })
        Row({ space: 10 }) {
          Button('学习中').layoutWeight(1).backgroundColor(!this.showCompleted ? '#2F6BFF' : '#D0D5DD')
            .onClick(() => this.showCompleted = false)
          Button('已完成').layoutWeight(1).backgroundColor(this.showCompleted ? '#2F6BFF' : '#D0D5DD')
            .onClick(() => this.showCompleted = true)
        }.padding({ left: 16, right: 16, bottom: 12 }).width('100%')
        if (this.isLoading && this.courses.length === 0) {
          Text('正在加载...').fontColor('#667085').margin({ top: 40 })
        } else if (this.visibleCourses().length === 0) {
          EmptyStateView({
            title: this.showCompleted ? '暂无已完成课程' : '还没有课程',
            description: '可从首页「查看课程」加入课程后，会出现在这里'
          }).margin({ left: 16, right: 16 })
        } else {
          List({ space: 12 }) {
            ForEach(this.visibleCourses(), (course: MyCourse) => {
              ListItem() {
                Column({ space: 10 }) {
                  Text(course.name).fontSize(17).fontWeight(FontWeight.Bold).width('100%')
                  Text(`${course.grade} · ${course.subject}`).fontSize(13).fontColor('#667085').width('100%')
                  if (!course.completed) {
                    Row({ space: 10 }) {
                      Button('继续学习').layoutWeight(1).height(38).backgroundColor('#2F6BFF')
                        .enabled(this.busyCourseId === 0)
                        .onClick(() => this.openCourse(course.courseId))
                      Button(this.busyCourseId === course.courseId ? '处理中...' : '已完成')
                        .layoutWeight(1).height(38).backgroundColor('#12B76A')
                        .enabled(this.busyCourseId === 0)
                        .onClick(() => void this.markCompleted(course))
                    }.width('100%')
                  } else {
                    Button('查看课程').width('100%').height(38).backgroundColor('#2F6BFF')
                      .onClick(() => this.openCourse(course.courseId))
                  }
                }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
              }
            }, (course: MyCourse) => `${course.id}-${course.completed ? 1 : 0}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
