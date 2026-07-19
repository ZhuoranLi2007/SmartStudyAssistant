import { common } from '@kit.AbilityKit';
import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageMap } from './PageMap';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';

@Entry
@Component
struct Index {
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    AppStorage.setOrCreate<string>(AppStorageKeys.AUTH_TOKEN, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.USER_ID, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.USERNAME, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.USER_ROLE, 'parent');
    AppStorage.setOrCreate<number>(AppStorageKeys.STUDENT_PROFILE_ID, 0);
    void this.restoreSession();
  }

  private async restoreSession(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const snapshot: SessionSnapshot = await SessionStorageService.load(context);
      AppStorage.setOrCreate<string>(AppStorageKeys.AUTH_TOKEN, snapshot.token);
      AppStorage.setOrCreate<number>(AppStorageKeys.USER_ID, snapshot.userId);
      AppStorage.setOrCreate<string>(AppStorageKeys.USERNAME, snapshot.username);
      AppStorage.setOrCreate<string>(AppStorageKeys.USER_ROLE, snapshot.role);
      AppStorage.setOrCreate<number>(AppStorageKeys.STUDENT_PROFILE_ID, snapshot.studentProfileId);
      this.appPathStack.pushPathByName(snapshot.token ? AppRoutes.HOME : AppRoutes.LOGIN, null, false);
    } catch (error) {
      console.error(`恢复登录状态失败: ${JSON.stringify(error)}`);
      this.appPathStack.pushPathByName(AppRoutes.LOGIN, null, false);
    }
  }

  build() {
    Navigation(this.appPathStack) {
      Column({ space: 12 }) {
        Image($r('app.media.realImageGen_education_0')).width(120).height(120).borderRadius(24)
        Text('智学规划助手').fontSize(26).fontWeight(FontWeight.Bold)
        Text('正在加载...').fontColor('#667085')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .navDestination(PageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }
}
