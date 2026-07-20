import { promptAction } from '@kit.ArkUI';
import { AppRoutes, IdRouteParam, OnlinePracticeRouteParam } from '../../common/AppRoutes';
import { AiCard } from '../../model/AiModels';

@Component
export struct PaperRecommendationCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop card: AiCard;

  private openDetail(): void {
    if (this.card.id <= 0) {
      promptAction.showToast({ message: '试卷信息暂不完整' });
      return;
    }
    const param: IdRouteParam = new IdRouteParam();
    param.id = this.card.id;
    this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
  }

  private startPractice(): void {
    if (this.card.id <= 0) {
      promptAction.showToast({ message: '当前试卷暂不能练习' });
      return;
    }
    const param: OnlinePracticeRouteParam = new OnlinePracticeRouteParam();
    param.paperId = this.card.id;
    this.appPathStack.pushPathByName(AppRoutes.ONLINE_PRACTICE, param);
  }

  private knowledgeText(): string {
    if (!this.card.knowledgePoints || this.card.knowledgePoints.length === 0) return '专项训练';
    return this.card.knowledgePoints.join('、');
  }

  build() {
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        Column() {
          Text('ABC').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#12A878')
          Text('✓').fontSize(20).fontColor('#12A878')
        }.width(54).height(58).justifyContent(FlexAlign.Center).backgroundColor('#E8FFF7').borderRadius(12)
        Column({ space: 5 }) {
          Text(this.card.title).fontSize(15).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
          Row({ space: 6 }) {
            Text(this.card.difficulty || '中等').fontSize(10).fontColor('#087E5B').padding({ left: 7, right: 7, top: 2, bottom: 2 }).backgroundColor('#DDF8EF').borderRadius(7)
            if (this.card.questionCount !== undefined) Text(`${this.card.questionCount}题`).fontSize(11).fontColor('#667085')
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Text(this.knowledgeText()).fontSize(11).fontColor('#667085').maxLines(2).width('100%')
      Row({ space: 8 }) {
        Button('查看详情').fontSize(11).height(32).backgroundColor('#EEF4FF').fontColor('#2F6BFF').enabled(this.card.id > 0)
          .onClick(() => this.openDetail())
        Button('开始练习').fontSize(11).height(32).backgroundColor('#356DF3').enabled(this.card.id > 0)
          .onClick(() => this.startPractice())
      }.width('100%').justifyContent(FlexAlign.End)
    }.padding(13).width('100%').backgroundColor('#F9FBFF').borderRadius(14).border({ width: 1, color: '#DCE6FB' })
  }
}
