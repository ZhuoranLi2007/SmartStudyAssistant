import { AppRoutes, PlatformInfoRouteParam } from '../../common/AppRoutes';

@Component
export struct SettingListItem {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop routeName: string = '';
  @Prop infoType: string = '';

  private open(): void {
    if (!this.routeName) return;
    if (this.routeName === AppRoutes.PLATFORM_INFO) {
      const param: PlatformInfoRouteParam = new PlatformInfoRouteParam();
      param.type = this.infoType;
      this.appPathStack.pushPathByName(this.routeName, param);
    } else {
      this.appPathStack.pushPathByName(this.routeName, null);
    }
  }

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.title).fontSize(15).fontColor('#344054')
        if (this.subtitle) Text(this.subtitle).fontSize(11).fontColor('#98A2B3')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text('›').fontSize(24).fontColor('#98A2B3')
    }
    .width('100%').height(this.subtitle ? 58 : 50)
    .onClick(() => this.open())
  }
}
