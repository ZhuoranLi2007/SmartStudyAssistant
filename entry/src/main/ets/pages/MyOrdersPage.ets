import { promptAction } from '@kit.ArkUI';
import { AppRoutes } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { CourseOrder, DataLoadResult, DataSource, OrderFilter, OrderStatus } from '../model/ProfileModels';
import { OrderService } from '../service/OrderService';

@Component
export struct MyOrdersPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop initialFilter: string = OrderFilter.ALL;
  @State currentFilter: OrderFilter = OrderFilter.ALL;
  @State orders: CourseOrder[] = [];
  @State source: DataSource = DataSource.MOCK;
  @State isLoading: boolean = false;
  @State payingId: number = 0;

  aboutToAppear(): void {
    this.currentFilter = this.parseFilter(this.initialFilter);
    void this.load();
  }

  private parseFilter(value: string): OrderFilter {
    if (value === OrderFilter.PENDING) return OrderFilter.PENDING;
    if (value === OrderFilter.PAID) return OrderFilter.PAID;
    if (value === OrderFilter.CANCELLED) return OrderFilter.CANCELLED;
    return OrderFilter.ALL;
  }

  private async load(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      const result: DataLoadResult<CourseOrder[]> = await OrderService.getOrders(this.currentFilter);
      this.orders = result.data; this.source = result.source;
    } finally { this.isLoading = false; }
  }

  private select(filter: OrderFilter): void { this.currentFilter = filter; void this.load(); }

  private statusLabel(status: OrderStatus): string {
    if (status === OrderStatus.PENDING) return '待支付';
    if (status === OrderStatus.PAID) return '已支付';
    return '已取消';
  }

  private confirmPay(order: CourseOrder): void {
    AlertDialog.show({
      title: '模拟支付', message: `确认支付 ¥${order.amount.toFixed(2)} 吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确认支付', action: () => void this.pay(order.id) }
    });
  }

  private async pay(orderId: number): Promise<void> {
    if (this.payingId > 0) return;
    this.payingId = orderId;
    try {
      const result: DataLoadResult<CourseOrder> = await OrderService.payOrder(orderId);
      this.source = result.source;
      promptAction.showToast({ message: '支付成功（演示）' });
      await this.load();
    } finally { this.payingId = 0; }
  }

  @Builder
  private filterButton(label: string, filter: OrderFilter) {
    Button(label).fontSize(12).height(36).backgroundColor(this.currentFilter === filter ? '#2F6BFF' : '#D0D5DD')
      .onClick(() => this.select(filter))
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '我的订单' })
        Scroll() { Row({ space: 8 }) {
          this.filterButton('全部', OrderFilter.ALL); this.filterButton('待支付', OrderFilter.PENDING)
          this.filterButton('已支付', OrderFilter.PAID); this.filterButton('已取消', OrderFilter.CANCELLED)
        } }.scrollable(ScrollDirection.Horizontal).padding({ left: 16, right: 16, bottom: 12 }).width('100%')
        if (!this.isLoading && this.orders.length === 0) {
          EmptyStateView({ title: '暂无订单', description: '当前分类下还没有课程订单' }).margin({ left: 16, right: 16 })
        } else {
          List({ space: 12 }) {
            ForEach(this.orders, (order: CourseOrder) => {
              ListItem() {
                Column({ space: 9 }) {
                  Row() {
                    Text(`订单号：${order.orderNo}`).fontSize(11).fontColor('#98A2B3').layoutWeight(1)
                    Text(this.statusLabel(order.status)).fontSize(13).fontColor(order.status === OrderStatus.PENDING ? '#F79009' : order.status === OrderStatus.PAID ? '#12B76A' : '#98A2B3')
                  }.width('100%')
                  Text(order.courseName).fontSize(16).fontWeight(FontWeight.Bold).width('100%')
                  Text(`下单时间：${order.createTime}`).fontSize(12).fontColor('#667085').width('100%')
                  Row() {
                    Text(`¥${order.amount.toFixed(2)}`).fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
                    if (order.status === OrderStatus.PENDING) Button(this.payingId === order.id ? '处理中...' : '继续支付').height(36).enabled(this.payingId === 0).onClick(() => this.confirmPay(order))
                    if (order.status === OrderStatus.PAID) Button('查看课程').height(36).backgroundColor('#2F6BFF').onClick(() => this.appPathStack.pushPathByName(AppRoutes.MY_COURSES, null))
                  }.width('100%')
                }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
              }
            }, (order: CourseOrder) => `${order.id}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
        }
        if (this.source === DataSource.MOCK) Text('订单操作为演示数据').fontSize(11).fontColor('#98A2B3').margin({ bottom: 10 })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
