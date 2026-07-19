import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes, PlatformInfoRouteParam } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { AuthSessionService } from '../service/AuthSessionService';

@Component
export struct SettingsPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State notificationEnabled: boolean = true;
  @State studyReminderEnabled: boolean = true;

  private openInfo(type: string): void {
    const param: PlatformInfoRouteParam = new PlatformInfoRouteParam(); param.type = type;
    this.appPathStack.pushPathByName(AppRoutes.PLATFORM_INFO, param);
  }

  private confirmClearCache(): void {
    AlertDialog.show({
      title: '清除缓存', message: '确定清除本地临时缓存吗？登录信息不会受到影响。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '清除', action: () => promptAction.showToast({ message: '缓存已清理' }) }
    });
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录', message: '确定要退出当前账号吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确定退出', fontColor: '#D92D20', action: () => void this.logout() }
    });
  }

  private async logout(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await AuthSessionService.clear(context);
      this.appPathStack.clear();
      this.appPathStack.pushPathByName(AppRoutes.LOGIN, null);
    } catch (error) {
      console.error(`退出失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '退出失败，请稍后重试' });
    }
  }

  @Builder
  private arrowRow(title: string, actionType: string) {
    Row() {
      Text(title).fontSize(15).layoutWeight(1)
      Text('›').fontSize(24).fontColor('#98A2B3')
    }.width('100%').height(52).onClick(() => {
      if (actionType === 'CACHE') this.confirmClearCache(); else this.openInfo(actionType);
    })
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '设置' })
        Scroll() {
          Column({ space: 14 }) {
            Column() {
              this.arrowRow('账号与安全', 'ACCOUNT')
              Divider().color('#EAECF0')
              Row() {
                Text('消息通知').fontSize(15).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled }).onChange((value: boolean) => this.notificationEnabled = value)
              }.height(52).width('100%')
              Divider().color('#EAECF0')
              Row() {
                Text('学习提醒').fontSize(15).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.studyReminderEnabled }).onChange((value: boolean) => this.studyReminderEnabled = value)
              }.height(52).width('100%')
              Divider().color('#EAECF0')
              this.arrowRow('清除缓存', 'CACHE')
            }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Color.White).borderRadius(18)
            Column() {
              this.arrowRow('隐私设置', 'PRIVACY')
              Divider().color('#EAECF0')
              this.arrowRow('用户协议', 'AGREEMENT')
              Divider().color('#EAECF0')
              this.arrowRow('隐私政策', 'PRIVACY')
              Divider().color('#EAECF0')
              this.arrowRow('关于我们', 'ABOUT')
            }.padding({ left: 16, right: 16 }).width('100%').backgroundColor(Color.White).borderRadius(18)
            Text('当前版本：1.0.0').fontSize(12).fontColor('#98A2B3').textAlign(TextAlign.Center).width('100%')
            Button('退出登录').width('100%').height(48).backgroundColor('#FEF3F2').fontColor('#D92D20').onClick(() => this.confirmLogout())
          }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
