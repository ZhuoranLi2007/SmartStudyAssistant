import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { AppConfig } from '../common/AppConfig';
import { PageHeader } from '../components/PageHeader';
import { Course } from '../model/DomainModels';
import { CourseService } from '../service/CourseService';
import { MockDataService } from '../service/MockDataService';

@Component
export struct CourseRecommendationPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State grade: string = '全部';
  @State subject: string = '全部';
  @State level: string = '全部';
  @State allCourses: Course[] = MockDataService.getCourses();
  @State courses: Course[] = MockDataService.getCourses();
  @State usingMockData: boolean = true;

  aboutToAppear(): void {
    void this.loadCourses();
  }

  private async loadCourses(): Promise<void> {
    if (AppConfig.USE_MOCK_DATA) {
      this.allCourses = MockDataService.getCourses();
      this.usingMockData = true;
      this.refresh();
      return;
    }
    try {
      this.allCourses = await CourseService.getCourses();
      this.usingMockData = false;
    } catch (error) {
      console.warn(`课程目录加载失败，使用演示数据: ${JSON.stringify(error)}`);
      this.allCourses = MockDataService.getCourses();
      this.usingMockData = true;
    }
    this.refresh();
  }

  private refresh(): void {
    this.courses = this.allCourses.filter((course: Course) =>
      (this.grade === '全部' || course.grade === this.grade) &&
      (this.subject === '全部' || course.subject === this.subject) &&
      (this.level === '全部' || course.level === this.level));
  }

  @Builder
  private filterButton(label: string, type: string) {
    Button(label)
      .fontSize(12)
      .height(34)
      .backgroundColor((type === 'grade' && this.grade === label) || (type === 'subject' && this.subject === label) ||
        (type === 'level' && this.level === label) ? '#2F6BFF' : '#D0D5DD')
      .onClick(() => {
        if (type === 'grade') this.grade = label;
        if (type === 'subject') this.subject = label;
        if (type === 'level') this.level = label;
        this.refresh();
      })
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '分层课程' })
        Column({ space: 8 }) {
          Scroll() { Row({ space: 8 }) {
            this.filterButton('全部', 'grade'); this.filterButton('一年级', 'grade'); this.filterButton('二年级', 'grade');
            this.filterButton('三年级', 'grade'); this.filterButton('四年级', 'grade'); this.filterButton('五年级', 'grade'); this.filterButton('六年级', 'grade')
          } }.scrollable(ScrollDirection.Horizontal)
          Scroll() { Row({ space: 8 }) {
            this.filterButton('全部', 'subject'); this.filterButton('语文', 'subject'); this.filterButton('数学', 'subject'); this.filterButton('英语', 'subject')
          } }.scrollable(ScrollDirection.Horizontal)
          Scroll() { Row({ space: 8 }) { this.filterButton('全部', 'level'); this.filterButton('基础巩固型', 'level'); this.filterButton('中等提升型', 'level'); this.filterButton('拔高拓展型', 'level') } }.scrollable(ScrollDirection.Horizontal)
          if (this.usingMockData) {
            Text('当前课程目录为演示数据').fontSize(11).fontColor('#B54708').width('100%')
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })
        List({ space: 12 }) {
          ForEach(this.courses, (course: Course) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(course.name).fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
                  Text(course.difficulty).fontSize(12).fontColor('#2F6BFF')
                }.width('100%')
                Text(`${course.grade} · ${course.subject} · ${course.level}`).fontSize(13).fontColor('#667085').width('100%')
                Text(course.description).fontSize(13).fontColor('#475467').maxLines(2).width('100%')
                Text(`知识点：${course.knowledgePoints.join('、')}`).fontSize(12).fontColor('#667085').width('100%')
              }
              .padding(16)
              .width('100%')
              .backgroundColor(Color.White)
              .borderRadius(16)
              .onClick(() => {
                const param: IdRouteParam = new IdRouteParam();
                param.id = course.id;
                this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
              })
            }
          }, (course: Course) => `${course.id}`)
        }.layoutWeight(1).width('100%').padding({ left: 16, right: 16, bottom: 20 })
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
