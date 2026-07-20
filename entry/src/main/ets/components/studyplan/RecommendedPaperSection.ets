import { RecommendedPaper } from '../../model/StudyPlanModels';

@Component
export struct RecommendedPaperSection {
  @Prop papers: RecommendedPaper[] = [];
  @Prop isParent: boolean = true;
  @Prop addingPaperId: number = 0;
  onAdd: (paper: RecommendedPaper) => void = (_paper: RecommendedPaper): void => {};
  onDetail: (paper: RecommendedPaper) => void = (_paper: RecommendedPaper): void => {};
  onMore: () => void = (): void => {};

  build() {
    Column({ space: 11 }) {
      Row() {
        Column({ space: 3 }) {
          Text('薄弱点专项训练').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('根据学生档案推荐适合本周补充的试卷').fontSize(11).fontColor('#667085')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('更多试卷 ›').fontSize(12).fontColor('#2F6BFF').onClick(() => this.onMore())
      }.width('100%')
      if (this.papers.length === 0) {
        Text('本周暂时没有新的补充试卷').fontSize(13).fontColor('#98A2B3')
          .padding(18).width('100%').textAlign(TextAlign.Center).backgroundColor(Color.White).borderRadius(14)
      } else {
        List({ space: 10 }) {
          ForEach(this.papers, (paper: RecommendedPaper) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(paper.subject === '数学' ? '数' : '英').width(34).height(34).textAlign(TextAlign.Center)
                    .fontWeight(FontWeight.Bold).fontColor('#7A5AF8').backgroundColor('#F4F0FF').borderRadius(10)
                  Text(paper.difficulty).fontSize(10).fontColor('#F79009').margin({ left: 8 }).layoutWeight(1)
                  Text(`${paper.questionCount}题`).fontSize(10).fontColor('#667085')
                }.width('100%')
                Text(paper.name).fontSize(14).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
                Text(paper.knowledgePoints.slice(0, 2).join(' · ')).fontSize(11).fontColor('#667085').width('100%')
                Text(paper.recommendReason).fontSize(11).fontColor('#475467').maxLines(2).lineHeight(17).width('100%')
                Row({ space: 7 }) {
                  Button('详情').height(32).fontSize(11).backgroundColor('#E9EEF8').fontColor('#344054')
                    .onClick(() => this.onDetail(paper))
                  if (this.isParent) {
                    Button(this.addingPaperId === paper.id ? '添加中...' : '加入本周')
                      .height(32).fontSize(11).backgroundColor('#2F6BFF').enabled(this.addingPaperId === 0)
                      .onClick(() => this.onAdd(paper))
                  }
                }.width('100%')
              }.width(205).padding(12).backgroundColor(Color.White).borderRadius(15)
                .border({ width: 1, color: '#EAECF0' })
            }
          }, (paper: RecommendedPaper) => `${paper.id}`)
        }.listDirection(Axis.Horizontal).scrollBar(BarState.Off).height(210).width('100%')
      }
    }.width('100%')
  }
}
