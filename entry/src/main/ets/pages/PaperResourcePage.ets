import { AppConfig } from '../common/AppConfig';
import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { Paper } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';
import { PaperService } from '../service/PaperService';

@Component
export struct PaperResourcePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State searchText: string = '';
  @State allPapers: Paper[] = [];
  @State papers: Paper[] = [];
  @State usingMockData: boolean = false;
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    void this.loadPapers();
  }

  private async loadPapers(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      if (AppConfig.USE_MOCK_DATA) {
        this.allPapers = MockDataService.getPapers();
        this.usingMockData = true;
      } else {
        this.allPapers = await PaperService.getPapers();
        this.usingMockData = false;
      }
    } catch (error) {
      console.warn(`试卷目录加载失败，使用演示数据: ${JSON.stringify(error)}`);
      this.allPapers = MockDataService.getPapers();
      this.usingMockData = true;
    } finally {
      this.isLoading = false;
      this.refresh();
    }
  }

  private refresh(): void {
    const keyword: string = this.searchText.trim();
    if (!keyword) {
      this.papers = this.allPapers.slice();
      return;
    }
    const filtered: Paper[] = [];
    for (let index: number = 0; index < this.allPapers.length; index++) {
      const paper: Paper = this.allPapers[index];
      const points: string = paper.knowledgePoints.join('、');
      if (paper.name.includes(keyword) || paper.grade.includes(keyword) ||
        paper.subject.includes(keyword) || paper.difficulty.includes(keyword) ||
        points.includes(keyword)) {
        filtered.push(paper);
      }
    }
    this.papers = filtered;
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '试卷训练' })
        Search({ placeholder: '搜索试卷名称、科目或知识点', value: this.searchText })
          .height(44)
          .margin({ left: 16, right: 16, bottom: 12 })
          .backgroundColor(Color.White)
          .onChange((value: string) => {
            this.searchText = value;
            this.refresh();
          })
        if (this.isLoading && this.papers.length === 0) {
          Text('正在加载试卷...').fontColor('#667085').margin({ top: 40 })
        } else if (this.papers.length === 0) {
          EmptyStateView({
            title: this.searchText.trim() ? '未找到相关试卷' : '暂无试卷',
            description: this.searchText.trim() ? '换个关键词再试试' : '试卷目录暂时为空'
          }).margin({ left: 16, right: 16, top: 20 })
        } else {
          List({ space: 10 }) {
            ForEach(this.papers, (paper: Paper) => {
              ListItem() {
                Column({ space: 7 }) {
                  Text(paper.name).fontSize(17).fontWeight(FontWeight.Bold).width('100%')
                  Text(`${paper.grade} · ${paper.subject} · ${paper.difficulty} · ${paper.questionCount}题`)
                    .fontSize(13).fontColor('#667085').width('100%')
                  Text(`知识点：${paper.knowledgePoints.join('、')}`)
                    .fontSize(12).fontColor('#667085').width('100%')
                }
                .padding(15)
                .width('100%')
                .backgroundColor(Color.White)
                .borderRadius(15)
                .border({ width: 1.5, color: '#2F6BFF' })
                .onClick(() => {
                  const param: IdRouteParam = new IdRouteParam();
                  param.id = paper.id;
                  this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
                })
              }
            }, (paper: Paper) => `${paper.id}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
        }
        if (this.usingMockData) {
          Text('当前试卷目录为演示数据').fontSize(11).fontColor('#B54708').margin({ bottom: 10 })
        }
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
