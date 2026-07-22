import { AppRoutes } from '../../common/AppRoutes';

@Component
export struct UserProfileCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop username: string = '';
  @Prop studentName: string = '';

  build() {
    Row({ space: 14 }) {
      Image($r('app.media.avatar')).width(66).height(66).borderRadius(33)
      Column({ space: 6 }) {
        Text(this.username || '智学用户').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#101828')
        Text('学习账号').fontSize(13).fontColor('#2F6BFF')
        Text(this.studentName ? `学习档案：${this.studentName}` : '学习档案已就绪').fontSize(12).fontColor('#667085')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(30).fontColor('#98A2B3')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
  }
}
