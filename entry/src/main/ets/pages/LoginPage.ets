import { common } from '@kit.AbilityKit';
import { AppRoutes, ContinuationRouteParam, ProfileSetupRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { AppConfig } from '../common/AppConfig';
import { ContinuationSnapshot } from '../model/DistributedStudyModels';
import { LoginResult } from '../model/DomainModels';
import { AuthService } from '../service/AuthService';
import { DistributedSyncService } from '../service/DistributedStudyService';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';

@Component
export struct LoginPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State account: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private getLoginErrorMessage(error: Object): string {
    const errorMessage: string = (error as Error).message || '';
    const errorDetail: string = `${errorMessage} ${JSON.stringify(error)}`;
    if (errorDetail.includes('HTTP 401')) {
      return '账号或密码错误';
    }
    const normalizedDetail: string = errorDetail.toLowerCase();
    if (errorDetail.includes('2300028') ||
      errorDetail.includes('2300007') ||
      normalizedDetail.includes('timeout') ||
      normalizedDetail.includes('connect') ||
      normalizedDetail.includes('network')) {
      return '无法连接服务器，请检查后端和网络';
    }
    return '登录失败，请稍后重试';
  }

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
    await DistributedSyncService.restore(context, userId);
    this.appPathStack.clear();
    if (!profileCompleted) {
      const param: ProfileSetupRouteParam = new ProfileSetupRouteParam();
      param.requireSetup = true;
      this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, param);
    } else {
      const continuation: ContinuationSnapshot | undefined =
        DistributedSyncService.consumePendingContinuation(userId);
      if (continuation !== undefined) {
        const param = new ContinuationRouteParam();
        param.entityId = continuation.entityId;
        param.entityKey = continuation.entityKey;
        param.parentEntityId = continuation.parentEntityId;
        param.selectedDate = continuation.selectedDate;
        param.filter = continuation.filter;
        param.tabIndex = continuation.tabIndex;
        param.searchKeyword = continuation.searchKeyword;
        param.updatedAt = continuation.updatedAt;
        this.appPathStack.pushPathByName(continuation.routeName, param);
      } else {
        this.appPathStack.pushPathByName(AppRoutes.HOME, null);
      }
    }
  }

  private async login(): Promise<void> {
    if (!this.account.trim() || !this.password.trim()) {
      this.showToast('请输入账号和密码');
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
        this.showToast('账号缺少学习档案，请重新注册');
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
      this.showToast(this.getLoginErrorMessage(error as Object));
      console.error(`登录失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 18 }) {
          Image($r('app.media.icon'))
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
