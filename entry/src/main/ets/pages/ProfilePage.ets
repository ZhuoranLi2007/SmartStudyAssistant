import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { MainTabBar } from '../components/MainTabBar';
import { SessionStorageService } from '../service/SessionStorageService';

@Component
export struct ProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USERNAME) username: string = '演示家长';
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @State bindCode: string = '';

  private async logout(): Promise<void> {
    AppStorage.setOrCreate<string>(AppStorageKeys.AUTH_TOKEN, '');
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await SessionStorageService.clear(context);
    this.appPathStack.clear();
    this.appPathStack.pushPathByName(AppRoutes.LOGIN, null);
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 18 }) {
            Text('我的').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
            Row({ space: 16 }) {
              Image($r('app.media.avatar')).width(72).height(72).borderRadius(36)
              Column({ space: 6 }) {
                Text(this.username || '演示用户').fontSize(22).fontWeight(FontWeight.Bold)
                Text(this.role === 'student' ? '学生账号' : '家长账号').fontColor('#667085')
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(18)
            Button('查看学生档案').width('100%').backgroundColor('#2F6BFF').onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
            if (this.role === 'student') {
              TextInput({ placeholder: '输入一次性学生绑定码', text: this.bindCode }).onChange((value: string) => this.bindCode = value)
              Button('绑定家庭').width('100%').onClick(() => promptAction.showToast({ message: this.bindCode ? '绑定成功（演示模式）' : '请输入绑定码' }))
            } else {
              Text('家庭邀请码：FAM-2026').width('100%').fontColor('#2F6BFF')
              Text('学生档案绑定码：STU-6A8K').width('100%').fontColor('#2F6BFF')
            }
            Button('退出登录').width('100%').backgroundColor('#F04438').onClick(() => void this.logout())
            Text('当前为本地演示数据；关闭模拟开关后使用 FastAPI 账号和家庭数据。').fontSize(12).fontColor('#98A2B3')
          }.padding(20).width('100%')
        }.layoutWeight(1)
        MainTabBar({ activeRoute: AppRoutes.PROFILE })
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
