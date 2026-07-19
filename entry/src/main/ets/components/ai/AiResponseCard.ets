import { AppRoutes, IdRouteParam } from '../../common/AppRoutes';
import { AiCard } from '../../model/AiModels';

@Component
export struct AiResponseCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop card: AiCard;

  private open(): void {
    if (this.card.type === 'STUDY_PLAN') {
      this.appPathStack.pushPathByName(AppRoutes.STUDY_PLAN, new Object());
      return;
    }
    const param: IdRouteParam = new IdRouteParam();
    param.id = this.card.id;
    if (this.card.type === 'COURSE') this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
    else if (this.card.type === 'PAPER') this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
    else if (this.card.type === 'ORDER') this.appPathStack.pushPathByName(AppRoutes.ORDER_DETAIL, param);
  }

  private typeText(): string {
    if (this.card.type === 'COURSE') return '课程';
    if (this.card.type === 'PAPER') return '试卷';
    if (this.card.type === 'ORDER') return '订单';
    return '学习计划';
  }

  build() {
    Column({ space: 7 }) {
      Row() {
        Text(this.typeText()).fontSize(10).fontColor('#2F6BFF').backgroundColor('#EEF4FF').borderRadius(8).padding({ left: 7, right: 7, top: 3, bottom: 3 })
        Blank()
        Text('查看 ›').fontSize(11).fontColor('#667085')
      }.width('100%')
      Text(this.card.title).fontSize(14).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
      Text(this.card.subtitle).fontSize(11).fontColor('#667085').maxLines(2).width('100%')
      if (this.card.price !== undefined) {
        Text(`¥${this.card.price}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#F04438').width('100%')
      }
    }.width(178).height(126).padding(12).backgroundColor(Color.White).borderRadius(14).onClick(() => this.open())
  }
}
