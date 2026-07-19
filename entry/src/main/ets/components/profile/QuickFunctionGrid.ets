import { AppRoutes, OrderRouteParam } from '../../common/AppRoutes';

@Component
export struct QuickFunctionGrid {
  @Consume('appPathStack') appPathStack: NavPathStack;

  private open(routeName: string): void {
    if (routeName === AppRoutes.MY_ORDERS) {
      this.appPathStack.pushPathByName(routeName, new OrderRouteParam());
    } else {
      this.appPathStack.pushPathByName(routeName, null);
    }
  }

  @Builder
  private item(iconText: string, title: string, routeName: string) {
    Column({ space: 8 }) {
      Text(iconText)
        .width(42).height(42).textAlign(TextAlign.Center).fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor('#2F6BFF').backgroundColor('#EEF4FF').borderRadius(12)
      Text(title).fontSize(12).fontColor('#344054')
    }
    .width('25%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => this.open(routeName))
  }

  build() {
    Column({ space: 8 }) {
      Text('常用功能').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      Row() {
        this.item('课', '我的课程', AppRoutes.MY_COURSES)
        this.item('单', '我的订单', AppRoutes.MY_ORDERS)
        this.item('藏', '我的收藏', AppRoutes.MY_FAVORITES)
        this.item('错', '错题本', AppRoutes.WRONG_QUESTIONS)
      }.width('100%')
      Row() {
        this.item('报', '学习报告', AppRoutes.LEARNING_REPORT)
        this.item('档', '学生档案', AppRoutes.STUDENT_PROFILE)
        this.item('服', '客服中心', AppRoutes.CUSTOMER_SERVICE)
        this.item('设', '设置', AppRoutes.SETTINGS)
      }.width('100%')
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }
}
