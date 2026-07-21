import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { Course, Paper } from '../model/DomainModels';
import { CourseService } from '../service/CourseService';
import { PaperService } from '../service/PaperService';

@Component
export struct SearchResultPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  keyword: string = '';
  @State searchText: string = '';
  @State courseResults: Course[] = [];
  @State paperResults: Paper[] = [];
  @State isSearching: boolean = false;

  aboutToAppear(): void {
    this.searchText = this.keyword;
    void this.doSearch();
  }

  private async doSearch(): Promise<void> {
    const keyword: string = this.searchText.trim();
    if (!keyword) return;
    this.isSearching = true;
    try {
      const encoded: string = encodeURIComponent(keyword);
      const courses: Course[] = await CourseService.getCourses(`?keyword=${encoded}`);
      const papers: Paper[] = await PaperService.getPapers(`?keyword=${encoded}`);
      this.courseResults = courses || [];
      this.paperResults = papers || [];
    } catch (error) {
      console.error(`搜索失败: ${JSON.stringify(error)}`);
      this.courseResults = [];
      this.paperResults = [];
    } finally {
      this.isSearching = false;
    }
  }

  private openCourse(course: Course): void {
    const param: IdRouteParam = new IdRouteParam();
    param.id = course.id;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  private openPaper(paper: Paper): void {
    const param: IdRouteParam = new IdRouteParam();
    param.id = paper.id;
    this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
  }

  @Builder
  private resultItem(title: string, subtitle: string, typeLabel: string, typeColor: string, onClick: () => void) {
    Row({ space: 12 }) {
      Text(typeLabel)
        .width(34).height(34).textAlign(TextAlign.Center).fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor(typeColor).backgroundColor(`${typeColor}1A`).borderRadius(10)
      Column({ space: 4 }) {
        Text(title).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#101828')
        Text(subtitle).fontSize(12).fontColor('#667085')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(20).fontColor('#98A2B3')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .onClick(onClick)
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          Text('<')
            .fontSize(22).fontColor('#101828').fontWeight(FontWeight.Bold)
            .onClick(() => this.appPathStack.pop())
          Text(`“${this.keyword}” 的搜索结果`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
            .layoutWeight(1)
        }.width('100%').padding(16).backgroundColor(Color.White)

        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              TextInput({ placeholder: '搜索课程或试卷名称', text: this.searchText })
                .placeholderColor('#98A2B3')
                .fontSize(14)
                .height(44)
                .layoutWeight(1)
                .backgroundColor('#F2F4F7')
                .borderRadius(12)
                .padding({ left: 16, right: 16 })
                .onChange((value: string) => this.searchText = value)
                .onSubmit(() => this.doSearch())
              Button('搜索')
                .height(44)
                .fontSize(14)
                .backgroundColor('#2F6BFF')
                .onClick(() => this.doSearch())
            }.width('100%')

            if (this.isSearching) {
              Text('搜索中...').fontSize(13).fontColor('#667085').padding(40).width('100%').textAlign(TextAlign.Center)
            } else if (this.courseResults.length === 0 && this.paperResults.length === 0) {
              Column({ space: 8 }) {
                Text('未找到相关课程或试卷').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#172033')
                Text('换个关键词试试吧').fontSize(13).fontColor('#667085')
              }.padding(40).width('100%')
            } else {
              if (this.courseResults.length > 0) {
                Text(`课程 (${this.courseResults.length})`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
                ForEach(this.courseResults, (course: Course) => {
                  this.resultItem(
                    course.name,
                    `${course.grade} · ${course.subject}`,
                    '课',
                    '#12B76A',
                    () => this.openCourse(course)
                  )
                }, (course: Course) => `course-${course.id}`)
              }
              if (this.paperResults.length > 0) {
                Text(`试卷 (${this.paperResults.length})`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
                ForEach(this.paperResults, (paper: Paper) => {
                  this.resultItem(
                    paper.name,
                    `${paper.grade} · ${paper.subject} · ${paper.questionCount}题`,
                    '卷',
                    '#2F6BFF',
                    () => this.openPaper(paper)
                  )
                }, (paper: Paper) => `paper-${paper.id}`)
              }
            }
          }.padding({ left: 16, right: 16, top: 12, bottom: 24 }).width('100%')
        }.layoutWeight(1).width('100%')
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
