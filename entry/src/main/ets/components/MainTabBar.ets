import { AppRoutes } from '../common/AppRoutes';

@Component
export struct MainTabBar {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop activeRoute: string = AppRoutes.HOME;

  private open(routeName: string): void {
    if (routeName !== this.activeRoute) {
      this.appPathStack.pushPathByName(routeName, null);
    }
  }

  @Builder
  private tab(label: string, routeName: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.activeRoute === routeName ? '#2F6BFF' : '#667085')
      .fontWeight(this.activeRoute === routeName ? FontWeight.Bold : FontWeight.Normal)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ top: 14, bottom: 14 })
      .onClick(() => this.open(routeName))
  }

  build() {
    Row() {
      this.tab('首页', AppRoutes.HOME)
      this.tab('AI助手', AppRoutes.AI_ASSISTANT)
      this.tab('学习计划', AppRoutes.STUDY_PLAN)
      this.tab('我的', AppRoutes.PROFILE)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#EAECF0' })
  }
}
