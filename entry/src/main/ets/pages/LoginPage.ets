import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes, ProfileSetupRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { AppConfig } from '../common/AppConfig';
import { LoginResult } from '../model/DomainModels';
import { AuthService } from '../service/AuthService';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';

@Component
export struct LoginPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State account: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;

  private async enterApp(token: string, userId: number, username: string, role: string,
    studentProfileId: number, profileCompleted: boolean): Promise<void> {
    AppStorage.setOrCreate<string>(AppStorageKeys.AUTH_TOKEN, token);
    AppStorage.setOrCreate<number>(AppStorageKeys.USER_ID, userId);
    AppStorage.setOrCreate<string>(AppStorageKeys.USERNAME, username);
    AppStorage.setOrCreate<string>(AppStorageKeys.USER_ROLE, role);
    AppStorage.setOrCreate<number>(AppStorageKeys.STUDENT_PROFILE_ID, studentProfileId);
    AppStorage.setOrCreate<boolean>(AppStorageKeys.PROFILE_COMPLETED, profileCompleted);
    const snapshot = new SessionSnapshot();
    snapshot.token = token;
    snapshot.userId = userId;
    snapshot.username = username;
    snapshot.role = role;
    snapshot.studentProfileId = studentProfileId;
    snapshot.profileCompleted = profileCompleted;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await SessionStorageService.save(context, snapshot);
    this.appPathStack.clear();
    if (!profileCompleted) {
      const param: ProfileSetupRouteParam = new ProfileSetupRouteParam();
      param.requireSetup = true;
      this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, param);
    } else {
      this.appPathStack.pushPathByName(AppRoutes.HOME, null);
    }
  }

  private async login(): Promise<void> {
    if (!this.account.trim() || !this.password.trim()) {
      promptAction.showToast({ message: '请输入账号和密码' });
      return;
    }
    this.isLoading = true;
    try {
      if (AppConfig.USE_MOCK_DATA) {
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 350));
        await this.enterApp('demo-token', 1, this.account, 'user', 1, true);
        return;
      }
      const result: LoginResult = await AuthService.login(this.account, this.password);
      if (result.studentProfileId <= 0) {
        promptAction.showToast({ message: '账号缺少学习档案，请重新注册' });
        return;
      }
      await this.enterApp(
        result.accessToken,
        result.user.id,
        result.user.username,
        result.user.role || 'user',
        result.studentProfileId,
        result.profileCompleted === true
      );
    } catch (error) {
      promptAction.showToast({ message: '登录失败，请稍后重试' });
      console.error(`登录失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          Image($r('app.media.realImageGen_education_0'))
            .width(118)
            .height(118)
            .borderRadius(28)
            .objectFit(ImageFit.Cover)
          Text('智学规划助手')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#101828')
          Text('课程 · 试卷 · 计划 · 错题，一站完成')
            .fontSize(16)
            .fontColor('#667085')
          TextInput({ placeholder: '用户名或手机号', text: this.account })
            .height(52)
            .backgroundColor('#F2F4F7')
            .borderRadius(14)
            .onChange((value: string) => this.account = value)
          TextInput({ placeholder: '密码', text: this.password })
            .type(InputType.Password)
            .height(52)
            .backgroundColor('#F2F4F7')
            .borderRadius(14)
            .onChange((value: string) => this.password = value)
          Button(this.isLoading ? '登录中...' : '登录')
            .width('100%')
            .height(52)
            .enabled(!this.isLoading)
            .backgroundColor('#2F6BFF')
            .onClick(() => void this.login())
          Row() {
            Text('还没有账号？').fontColor('#667085')
            Text('立即注册')
              .fontColor('#2F6BFF')
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.appPathStack.pushPathByName(AppRoutes.REGISTER, null))
          }
        }
        .width('100%')
        .padding({ left: 28, right: 28, top: 70, bottom: 30 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')
    }
    .hideTitleBar(true)
  }
}
