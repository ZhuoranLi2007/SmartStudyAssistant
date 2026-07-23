import { promptAction } from '@kit.ArkUI';
import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { AIGeneratedPaper, AIPaperService } from '../service/AIPaperService';

@Component
export struct MyPapersPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State papers: AIGeneratedPaper[] = [];
  @State loading: boolean = false;

  aboutToAppear(): void {
    void this.loadPapers();
  }

  private async loadPapers(): Promise<void> {
    this.loading = true;
    try {
      this.papers = await AIPaperService.getMyPapers();
    } catch (error) {
      promptAction.showToast({ message: '加载失败，请稍后重试' });
      console.error(`我的试卷加载失败: ${JSON.stringify(error)}`);
    } finally {
      this.loading = false;
    }
  }

  private openPaperDetail(paper: AIGeneratedPaper): void {
    const param: IdRouteParam = new IdRouteParam();
    param.id = paper.id;
    this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
  }

  private confirmDelete(paper: AIGeneratedPaper): void {
    AlertDialog.show({
      title: '删除试卷',
      message: `确定要删除「${paper.name}」吗？`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#D92D20',
        action: () => void this.deletePaper(paper.id)
      }
    });
  }

  private async deletePaper(paperId: number): Promise<void> {
    try {
      await AIPaperService.deleteMyPaper(paperId);
      promptAction.showToast({ message: '试卷已删除' });
      await this.loadPapers();
    } catch (error) {
      promptAction.showToast({ message: '删除失败，请稍后重试' });
      console.error(`删除试卷失败: ${JSON.stringify(error)}`);
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '我的试卷' })
        if (this.loading && this.papers.length === 0) {
          Text('正在加载...').fontColor('#667085').margin({ top: 40 })
        } else if (this.papers.length === 0) {
          EmptyStateView({
            title: '还没有 AI 组卷',
            description: '在 AI 学习顾问中点击“组卷”，生成属于你自己的专属试卷'
          }).margin({ left: 16, right: 16, top: 24 })
        } else {
          List({ space: 10 }) {
            ForEach(this.papers, (paper: AIGeneratedPaper) => {
              ListItem() {
                Row() {
                  Column({ space: 7 }) {
                    Row() {
                      Text('AI 生成').fontSize(11).fontColor('#2F6BFF').backgroundColor('#EEF4FF')
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
                      Text(paper.createdAt.split('T')[0]).fontSize(11).fontColor('#98A2B3')
                    }.width('100%')
                    Text(paper.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
                    Text(`${paper.grade} · ${paper.subject} · ${paper.difficulty} · ${paper.questionCount}题`)
                      .fontSize(13).fontColor('#667085').width('100%')
                    Text(`知识点：${paper.knowledgePoints.join('、')}`)
                      .fontSize(12).fontColor('#667085').width('100%')
                  }
                  .layoutWeight(1)
                  .padding({ right: 12 })
                  .onClick(() => this.openPaperDetail(paper))

                  Column() {
                    Text('删除')
                      .fontSize(13)
                      .fontColor('#D92D20')
                      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                      .backgroundColor('#FEF3F2')
                      .borderRadius(8)
                  }
                  .onClick(() => this.confirmDelete(paper))
                }
                .padding(15)
                .width('100%')
                .backgroundColor(Color.White)
                .borderRadius(15)
                .border({ width: 1.5, color: '#2F6BFF' })
                .alignItems(VerticalAlign.Center)
              }
            }, (paper: AIGeneratedPaper) => `${paper.id}-${paper.name}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
        }
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
