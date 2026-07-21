import { AppRoutes, StudentRouteParam } from '../../common/AppRoutes';
import { AppStorageKeys } from '../../common/AppStorageKeys';

@Component
export struct EducationEntranceGrid {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;

  private open(routeName: string): void {
    if (routeName === AppRoutes.AI_ASSISTANT) {
      const param: StudentRouteParam = new StudentRouteParam();
      param.studentProfileId = this.studentProfileId;
      this.appPathStack.pushPathByName(routeName, param);
    } else {
      this.appPathStack.pushPathByName(routeName, null);
    }
  }

  @Builder
  private item(iconText: string, title: string, subtitle: string, routeName: string, color: string, bg: string) {
    Row({ space: 14 }) {
      Text(iconText)
        .width(48).height(48).textAlign(TextAlign.Center).fontSize(18).fontWeight(FontWeight.Bold)
        .fontColor(color).backgroundColor(bg).borderRadius(14)
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#101828')
        Text(subtitle).fontSize(12).fontColor('#667085')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(22).fontColor('#98A2B3')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => this.open(routeName))
  }

  build() {
    Column({ space: 12 }) {
      Text('学习入口').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      this.item('课', '查看课程', '在线观看课程', AppRoutes.COURSES, '#12B76A', '#ECFDF3')
      this.item('卷', '试卷训练', '在线做题、收藏并加入计划', AppRoutes.PAPERS, '#2F6BFF', '#EEF4FF')
      this.item('AI', 'AI选课', '跳转 AI 助手获取选课建议', AppRoutes.AI_ASSISTANT, '#7A5AF8', '#F4EBFF')
      this.item('计', '学习计划', '查看本周课程、试卷与错题任务', AppRoutes.STUDY_PLAN, '#F79009', '#FFFAEB')
    }.width('100%')
  }
}
