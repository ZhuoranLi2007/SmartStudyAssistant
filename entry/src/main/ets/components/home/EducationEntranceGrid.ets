import { AppRoutes, StudentRouteParam } from '../../common/AppRoutes';
import { AppStorageKeys } from '../../common/AppStorageKeys';

@Component
export struct EducationEntranceGrid {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;

  private open(routeName: string): void {
    if (routeName === AppRoutes.AI_ASSISTANT) {
      const param: StudentRouteParam = new StudentRouteParam(); param.studentProfileId = this.studentProfileId;
      this.appPathStack.pushPathByName(routeName, param);
    } else {
      this.appPathStack.pushPathByName(routeName, null);
    }
  }

  @Builder
  private item(iconText: string, title: string, routeName: string, color: string) {
    Column({ space: 7 }) {
      Text(iconText).width(44).height(44).textAlign(TextAlign.Center).fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor(color).backgroundColor('#F2F4FF').borderRadius(14)
      Text(title).fontSize(12).fontColor('#344054')
    }.width('25%').onClick(() => this.open(routeName))
  }

  build() {
    Column({ space: 13 }) {
      Row() {
        Text('课程教育入口').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
        Text('精选学习服务').fontSize(11).fontColor('#98A2B3')
      }.width('100%')
      Row() {
        this.item('类', '课程分类', AppRoutes.COURSES, '#2F6BFF')
        this.item('AI', 'AI选课', AppRoutes.AI_ASSISTANT, '#7A5AF8')
        this.item('课', '我的课程', AppRoutes.MY_COURSES, '#12B76A')
        this.item('计', '学习计划', AppRoutes.STUDY_PLAN, '#F79009')
      }.width('100%')
    }.padding(15).width('100%').backgroundColor(Color.White).borderRadius(18)
  }
}
