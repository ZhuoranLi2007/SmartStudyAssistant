import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes, PlatformInfoRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { DistributedStatusListener, DistributedSyncStatus } from '../model/DistributedStudyModels';
import { AuthSessionService } from '../service/AuthSessionService';
import { DistributedSyncService } from '../service/DistributedStudyService';

@Component
export struct SettingsPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USER_ID) userId: number = 0;
  @StorageLink(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED) distributedSyncEnabled: boolean = false;
  @StorageLink(AppStorageKeys.DISTRIBUTED_LAST_EVENT_TYPE) distributedLastEventType: string = '';
  @StorageLink(AppStorageKeys.DISTRIBUTED_LAST_EVENT_AT) distributedLastEventAt: number = 0;
  @State notificationEnabled: boolean = true;
  @State studyReminderEnabled: boolean = true;
  @State distributedStatus: DistributedSyncStatus = DistributedSyncStatus.DISABLED;
  private readonly distributedStatusListener: DistributedStatusListener =
    (status: DistributedSyncStatus): void => {
      this.distributedStatus = status;
      this.distributedSyncEnabled =
        status === DistributedSyncStatus.WAITING_DEVICE || status === DistributedSyncStatus.CONNECTED;
    };

  aboutToAppear(): void {
    this.distributedStatus = DistributedSyncService.getStatus();
    DistributedSyncService.subscribeStatus(this.distributedStatusListener);
  }

  aboutToDisappear(): void {
    DistributedSyncService.unsubscribeStatus(this.distributedStatusListener);
  }

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

  private distributedStatusText(): string {
    if (this.distributedStatus === DistributedSyncStatus.WAITING_PERMISSION) return '等待授权';
    if (this.distributedStatus === DistributedSyncStatus.WAITING_DEVICE) return '已开启，等待可信设备';
    if (this.distributedStatus === DistributedSyncStatus.CONNECTED) return '已连接可信设备';
    if (this.distributedStatus === DistributedSyncStatus.UNSUPPORTED) return '当前设备不支持';
    if (this.distributedStatus === DistributedSyncStatus.PERMISSION_DENIED) return '未授权';
    if (this.distributedStatus === DistributedSyncStatus.ERROR) return '同步异常';
    return '未开启';
  }

  private distributedStatusDescription(): string {
    if (this.distributedStatus === DistributedSyncStatus.WAITING_PERMISSION) return '请在系统弹窗中允许分布式数据同步权限';
    if (this.distributedStatus === DistributedSyncStatus.WAITING_DEVICE) return '权限已授予，请确认两台手机已建立可信设备关系';
    if (this.distributedStatus === DistributedSyncStatus.CONNECTED) return '远端业务变化会在当前页面自动刷新';
    if (this.distributedStatus === DistributedSyncStatus.UNSUPPORTED) return '当前系统版本或设备不支持分布式数据对象';
    if (this.distributedStatus === DistributedSyncStatus.PERMISSION_DENIED) return '请重新打开开关，并在系统弹窗中选择允许';
    if (this.distributedStatus === DistributedSyncStatus.ERROR) return '初始化失败，请关闭开关后重试';
    return '开启后，同账号可信设备可以同步学习状态';
  }

  private distributedStatusColor(): string {
    if (this.distributedStatus === DistributedSyncStatus.CONNECTED) return '#027A48';
    if (this.distributedStatus === DistributedSyncStatus.WAITING_DEVICE ||
      this.distributedStatus === DistributedSyncStatus.WAITING_PERMISSION) return '#B54708';
    if (this.distributedStatus === DistributedSyncStatus.PERMISSION_DENIED ||
      this.distributedStatus === DistributedSyncStatus.ERROR) return '#D92D20';
    return '#667085';
  }

  private formatSyncTime(value: number): string {
    if (value <= 0) return '';
    const date = new Date(value);
    const hour: string = `${date.getHours()}`.padStart(2, '0');
    const minute: string = `${date.getMinutes()}`.padStart(2, '0');
    const second: string = `${date.getSeconds()}`.padStart(2, '0');
    return `${hour}:${minute}:${second}`;
  }

  private async toggleDistributedSync(enabled: boolean): Promise<void> {
    if (!enabled) {
      await DistributedSyncService.disable(true);
      this.getUIContext().getPromptAction().showToast({ message: '跨设备学习接续已关闭' });
      return;
    }
    if (this.userId <= 0) {
      this.distributedSyncEnabled = false;
      this.getUIContext().getPromptAction().showToast({ message: '请先登录后再开启跨设备学习接续' });
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const status: DistributedSyncStatus = await DistributedSyncService.enable(context, this.userId);
    if (status === DistributedSyncStatus.WAITING_DEVICE) {
      this.getUIContext().getPromptAction().showToast({ message: '已开启，正在等待可信鸿蒙设备' });
    } else if (status === DistributedSyncStatus.CONNECTED) {
      this.getUIContext().getPromptAction().showToast({ message: '跨设备学习接续已连接' });
    } else if (status === DistributedSyncStatus.UNSUPPORTED) {
      this.getUIContext().getPromptAction().showToast({ message: '当前模拟器或设备不支持分布式数据同步' });
    } else if (status === DistributedSyncStatus.PERMISSION_DENIED) {
      this.getUIContext().getPromptAction().showToast({ message: '未获得分布式数据同步权限' });
    } else {
      this.getUIContext().getPromptAction().showToast({ message: '跨设备学习接续初始化失败' });
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
            Column({ space: 12 }) {
              Row() {
                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text('跨设备学习接续').fontSize(15).fontWeight(FontWeight.Medium)
                    Text('实验').fontSize(10).fontColor('#6941C6').padding({ left: 7, right: 7, top: 3, bottom: 3 })
                      .backgroundColor('#F4EBFF').borderRadius(8)
                  }
                  Text('通过鸿蒙分布式数据对象同步学习计划状态')
                    .fontSize(12).fontColor('#667085')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.distributedSyncEnabled })
                  .onChange((value: boolean) => { void this.toggleDistributedSync(value); })
              }.width('100%')
              Row({ space: 10 }) {
                Text('●').fontSize(13).fontColor(this.distributedStatusColor())
                Column({ space: 3 }) {
                  Text(this.distributedStatusText()).fontSize(14).fontWeight(FontWeight.Medium)
                    .fontColor(this.distributedStatusColor())
                  Text(this.distributedStatusDescription()).fontSize(12).fontColor('#667085')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#F8FAFC')
              .borderRadius(12)
              if (this.distributedLastEventAt > 0) {
                Text(`最近同步：${this.distributedLastEventType} · ${this.formatSyncTime(this.distributedLastEventAt)}`)
                  .fontSize(11).fontColor('#475467').width('100%')
              }
              Text('受设备条件限制时会提示不支持，不影响普通学习功能。')
                .fontSize(11).fontColor('#98A2B3').width('100%')
            }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
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
