import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { AppConfig } from '../common/AppConfig';
import { CourseVideoResolver } from '../common/CourseVideoResolver';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { Course } from '../model/DomainModels';
import { CourseService } from '../service/CourseService';
import { MockDataService } from '../service/MockDataService';

@Component
export struct CourseRecommendationPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State allCourses: Course[] = [];
  @State courses: Course[] = [];
  @State searchText: string = '';
  @State isLoading: boolean = false;
  @State usingMockData: boolean = false;

  aboutToAppear(): void {
    void this.loadCourses();
  }

  private async loadCourses(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      if (AppConfig.USE_MOCK_DATA) {
        this.allCourses = MockDataService.getCourses();
        this.usingMockData = true;
      } else {
        this.allCourses = await CourseService.getCourses();
        this.usingMockData = false;
      }
    } catch (error) {
      console.warn(`课程目录加载失败，使用演示数据: ${JSON.stringify(error)}`);
      this.allCourses = MockDataService.getCourses();
      this.usingMockData = true;
    } finally {
      this.isLoading = false;
      this.refresh();
    }
  }

  private refresh(): void {
    const keyword: string = this.searchText.trim();
    if (!keyword) {
      this.courses = this.allCourses.slice();
      return;
    }
    const filtered: Course[] = [];
    for (let index: number = 0; index < this.allCourses.length; index++) {
      const course: Course = this.allCourses[index];
      const points: string = course.knowledgePoints.join('、');
      if (course.name.includes(keyword) || course.grade.includes(keyword) ||
        course.subject.includes(keyword) || course.level.includes(keyword) ||
        course.description.includes(keyword) || points.includes(keyword)) {
        filtered.push(course);
      }
    }
    this.courses = filtered;
  }

  private openCourse(courseId: number): void {
    const param: IdRouteParam = new IdRouteParam();
    param.id = courseId;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '查看课程' })
        Search({ placeholder: '搜索课程名称、科目或知识点', value: this.searchText })
          .height(44)
          .margin({ left: 16, right: 16, bottom: 12 })
          .backgroundColor(Color.White)
          .onChange((value: string) => {
            this.searchText = value;
            this.refresh();
          })
        if (this.isLoading && this.courses.length === 0) {
          Text('正在加载课程...').fontColor('#667085').margin({ top: 40 })
        } else if (this.courses.length === 0) {
          EmptyStateView({
            title: this.searchText.trim() ? '未找到相关课程' : '暂无课程',
            description: this.searchText.trim() ? '换个关键词再试试' : '课程目录暂时为空，请稍后重试'
          }).margin({ left: 16, right: 16, top: 20 })
        } else {
          List({ space: 12 }) {
            ForEach(this.courses, (course: Course) => {
              ListItem() {
                Row({ space: 12 }) {
                  Image(CourseVideoResolver.resolvePreview(course))
                    .width(88).height(66).objectFit(ImageFit.Cover).borderRadius(12)
                  Column({ space: 6 }) {
                    Text(course.name).fontSize(16).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
                    Text(`${course.grade} · ${course.subject} · ${course.level}`)
                      .fontSize(12).fontColor('#667085').width('100%')
                    Text(course.description).fontSize(12).fontColor('#475467').maxLines(2).width('100%')
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }
                .padding(14)
                .width('100%')
                .backgroundColor(Color.White)
                .borderRadius(16)
                .onClick(() => this.openCourse(course.id))
              }
            }, (course: Course) => `${course.id}`)
          }.layoutWeight(1).width('100%').padding({ left: 16, right: 16, bottom: 20 })
        }
        if (this.usingMockData) {
          Text('当前课程目录为演示数据').fontSize(11).fontColor('#B54708').margin({ bottom: 10 })
        }
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
