import { AppRoutes } from '../../common/AppRoutes';

@Component
export struct QuickFunctionGrid {
  @Consume('appPathStack') appPathStack: NavPathStack;

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
    .onClick(() => this.appPathStack.pushPathByName(routeName, null))
  }

  build() {
    Column({ space: 8 }) {
      Text('常用功能').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      Row() {
        this.item('课', '我的课程', AppRoutes.MY_COURSES)
        this.item('藏', '我的收藏', AppRoutes.MY_FAVORITES)
        this.item('错', '错题本', AppRoutes.WRONG_QUESTIONS)
        this.item('报', '学习报告', AppRoutes.LEARNING_REPORT)
      }.width('100%')
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }
}
