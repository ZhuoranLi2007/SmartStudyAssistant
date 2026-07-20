import { AppRoutes } from '../../common/AppRoutes';

@Component
export struct UserProfileCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop username: string = '';
  @Prop role: string = 'parent';
  @Prop studentName: string = '小明';
  @Prop studentBound: boolean = true;

  build() {
    Row({ space: 14 }) {
      Image($r('app.media.avatar')).width(66).height(66).borderRadius(33)
      Column({ space: 6 }) {
        Text(this.username || '智学用户').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#101828')
        Text(this.role === 'student' ? '学生账号' : '家长账号').fontSize(13).fontColor('#2F6BFF')
        Text(this.studentBound ? `已关联学生：${this.studentName}` : '暂未绑定学生档案').fontSize(12).fontColor('#667085')
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
