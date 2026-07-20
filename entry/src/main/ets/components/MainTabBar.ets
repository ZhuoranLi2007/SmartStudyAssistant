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
  private tab(icon: Resource, label: string, routeName: string) {
    Column({ space: 3 }) {
      Image(icon)
        .width(this.activeRoute === routeName ? 28 : 26)
        .height(this.activeRoute === routeName ? 28 : 26)
        .objectFit(ImageFit.Contain)
        .fillColor(this.activeRoute === routeName ? '#2F6BFF' : '#98A2B3')
      Text(label)
        .fontSize(12)
        .fontColor(this.activeRoute === routeName ? '#2F6BFF' : '#667085')
        .fontWeight(this.activeRoute === routeName ? FontWeight.Bold : FontWeight.Normal)
    }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
      .height(58)
      .onClick(() => this.open(routeName))
  }

  build() {
    Row() {
      this.tab($r('app.media.tab_home'), '首页', AppRoutes.HOME)
      this.tab($r('app.media.tab_ai'), 'AI助手', AppRoutes.AI_ASSISTANT)
      this.tab($r('app.media.tab_plan'), '学习计划', AppRoutes.STUDY_PLAN)
      this.tab($r('app.media.tab_profile'), '我的', AppRoutes.PROFILE)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#EAECF0' })
  }
}
