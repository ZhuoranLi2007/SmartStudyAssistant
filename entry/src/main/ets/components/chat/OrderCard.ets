import { promptAction } from '@kit.ArkUI';
import { AppRoutes, IdRouteParam } from '../../common/AppRoutes';
import { AiCard } from '../../model/AiModels';

@Component
export struct OrderCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop card: AiCard;

  private openOrder(): void {
    if (this.card.id <= 0) {
      promptAction.showToast({ message: '订单信息暂不完整' });
      return;
    }
    const param: IdRouteParam = new IdRouteParam();
    param.id = this.card.id;
    this.appPathStack.pushPathByName(AppRoutes.ORDER_DETAIL, param);
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('▤ 课程订单').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#7A5AF8')
        Blank()
        Text(this.card.orderStatus || '待支付').fontSize(11).fontColor('#B54708')
      }.width('100%')
      Text(this.card.title).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
      if (this.card.orderNo) Text(`订单号：${this.card.orderNo}`).fontSize(10).fontColor('#667085').width('100%')
      Row() {
        Text(`¥${this.card.amount !== undefined ? this.card.amount : this.card.price || 0}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#F04438')
        Blank()
        Button('查看订单').fontSize(11).height(32).backgroundColor('#7A5AF8').enabled(this.card.id > 0).onClick(() => this.openOrder())
      }.width('100%')
    }.padding(13).width('100%').backgroundColor('#FBFAFF').borderRadius(14).border({ width: 1, color: '#E5DDFB' })
  }
}
