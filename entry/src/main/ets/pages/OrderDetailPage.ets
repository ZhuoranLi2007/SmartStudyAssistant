import { PageHeader } from '../components/PageHeader';
import { CourseOrder, DataLoadResult, DataSource, OrderStatus } from '../model/ProfileModels';
import { OrderService } from '../service/OrderService';

@Component
export struct OrderDetailPage {
  @Prop orderId: number = 0;
  @State order: CourseOrder | null = null;
  @State loading: boolean = true;
  @State source: DataSource = DataSource.LIVE;

  aboutToAppear(): void {
    void this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      const result: DataLoadResult<CourseOrder> = await OrderService.getOrder(this.orderId);
      this.order = result.data;
      this.source = result.source;
    } finally {
      this.loading = false;
    }
  }

  private statusText(status: OrderStatus): string {
    if (status === OrderStatus.PENDING) return '待支付';
    if (status === OrderStatus.PAID) return '已支付';
    return '已取消';
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '订单详情' })
        if (this.loading) {
          Text('正在加载...').margin({ top: 40 }).fontColor('#667085')
        } else if (this.order) {
          Column({ space: 14 }) {
            Text(this.statusText(this.order.status)).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#2F6BFF').width('100%')
            Text(this.order.courseName).fontSize(18).fontWeight(FontWeight.Bold).width('100%')
            Text(`订单编号：${this.order.orderNo}`).fontSize(13).fontColor('#667085').width('100%')
            Text(`下单时间：${this.order.createTime}`).fontSize(13).fontColor('#667085').width('100%')
            Text(`订单金额：¥${this.order.amount}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#F04438').width('100%')
            if (this.source === DataSource.MOCK) {
              Text('当前订单详情为演示数据').fontSize(11).fontColor('#B54708').width('100%')
            }
          }.margin(16).padding(18).backgroundColor(Color.White).borderRadius(18).width('calc(100% - 32vp)')
        } else {
          Text('订单不存在').margin({ top: 40 }).fontColor('#667085')
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
