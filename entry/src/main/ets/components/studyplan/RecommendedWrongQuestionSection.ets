import { RecommendedWrongQuestion } from '../../model/StudyPlanModels';

@Component
export struct RecommendedWrongQuestionSection {
  @Prop questions: RecommendedWrongQuestion[] = [];
  @Prop isParent: boolean = false;
  @Prop addingQuestionId: number = 0;
  onAdd: (question: RecommendedWrongQuestion) => void = (_question: RecommendedWrongQuestion): void => {};
  onOpenWrongBook: () => void = (): void => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('错题专项训练').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
          Text('优先复测高频错题，掌握后自动移出推荐').fontSize(11).fontColor('#667085')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('查看错题本').fontSize(12).fontColor('#2F6BFF').onClick(() => this.onOpenWrongBook())
      }.width('100%')
      if (this.questions.length === 0) {
        Row({ space: 10 }) {
          Text('✓').fontSize(20).fontColor('#12B76A')
          Text('当前没有待安排的未掌握错题').fontSize(13).fontColor('#475467').layoutWeight(1)
        }.padding(14).width('100%').backgroundColor('#ECFDF3').borderRadius(14)
      } else {
        ForEach(this.questions, (item: RecommendedWrongQuestion) => {
          Column({ space: 9 }) {
            Row({ space: 9 }) {
              Text('错').width(34).height(34).textAlign(TextAlign.Center).fontWeight(FontWeight.Bold)
                .fontColor('#D92D20').backgroundColor('#FEF3F2').borderRadius(10)
              Column({ space: 3 }) {
                Text(`${item.subject} · ${item.knowledgePoint}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#172033')
                Text(`累计答错 ${item.wrongCount} 次`).fontSize(11).fontColor('#D92D20')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.isParent) {
                Button(this.addingQuestionId === item.id ? '添加中...' : '加入本周')
                  .height(32).fontSize(11).backgroundColor('#2F6BFF')
                  .enabled(this.addingQuestionId === 0)
                  .onClick(() => this.onAdd(item))
              }
            }.width('100%')
            Text(item.question).fontSize(13).fontColor('#344054').maxLines(2).width('100%')
            Text(item.recommendReason).fontSize(11).fontColor('#667085').width('100%')
          }.padding(13).width('100%').backgroundColor(Color.White).borderRadius(15)
            .border({ width: 1, color: '#EAECF0' })
        }, (item: RecommendedWrongQuestion) => `${item.id}-${item.wrongCount}`)
      }
    }.width('100%')
  }
}
