import { AppRoutes, IdRouteParam, OnlinePracticeRouteParam } from '../../common/AppRoutes';
import { HomePaperItem } from '../../model/HomeModels';
import { CourseSectionHeader } from './CourseSectionHeader';

@Component
export struct PaperTrainingSection {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop papers: HomePaperItem[] = [];

  private openDetail(id: number): void {
    const param: IdRouteParam = new IdRouteParam(); param.id = id;
    this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
  }

  private start(id: number): void {
    const param: OnlinePracticeRouteParam = new OnlinePracticeRouteParam(); param.paperId = id;
    this.appPathStack.pushPathByName(AppRoutes.ONLINE_PRACTICE, param);
  }

  build() {
    Column({ space: 11 }) {
      CourseSectionHeader({ title: '专项训练', moreText: '试卷中心', routeName: AppRoutes.PAPERS })
      List({ space: 10 }) {
        ForEach(this.papers, (paper: HomePaperItem) => {
          ListItem() {
            Column({ space: 7 }) {
              Row() {
                Text(paper.subject === '英语' ? '英' : '数').width(36).height(36).textAlign(TextAlign.Center).fontWeight(FontWeight.Bold)
                  .fontColor('#2F6BFF').backgroundColor('#EEF4FF').borderRadius(10)
                Text(paper.difficulty).fontSize(10).fontColor('#F79009').margin({ left: 8 }).layoutWeight(1)
                Text('详情 ›').fontSize(10).fontColor('#667085').onClick(() => this.openDetail(paper.id))
              }.width('100%')
              Text(paper.name).fontSize(14).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
              Text(`${paper.grade} · ${paper.questionCount}题`).fontSize(11).fontColor('#667085').width('100%')
              Button('开始练习').height(34).fontSize(12).width('100%').backgroundColor('#2F6BFF').onClick(() => this.start(paper.id))
            }.width(202).padding(12).backgroundColor(Color.White).borderRadius(15)
          }
        }, (paper: HomePaperItem) => `${paper.id}`)
      }.listDirection(Axis.Horizontal).height(162).width('100%')
    }.width('100%')
  }
}
