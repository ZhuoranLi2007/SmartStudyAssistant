import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { AppConfig } from '../common/AppConfig';
import { AppRoutes, ProfileSetupRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { LoginResult } from '../model/DomainModels';
import { AuthService } from '../service/AuthService';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';

@Component
export struct RegisterPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State username: string = '';
  @State phone: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;

  private async register(): Promise<void> {
    if (!this.username.trim() || !this.phone.trim() || !this.password.trim()) {
      promptAction.showToast({ message: '请完整填写注册信息' });
      return;
    }
    if (this.password.length < 6) {
      promptAction.showToast({ message: '密码至少需要6位' });
      return;
    }
    if (this.password !== this.confirmPassword) {
      promptAction.showToast({ message: '两次输入的密码不一致' });
      return;
    }
    this.isLoading = true;
    try {
      if (AppConfig.USE_MOCK_DATA) {
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 350));
        promptAction.showToast({ message: '注册成功，请登录' });
        this.appPathStack.pop();
        return;
      }
      const result: LoginResult = await AuthService.register(this.username, this.phone, this.password);
      AppStorage.setOrCreate<string>(AppStorageKeys.AUTH_TOKEN, result.accessToken);
      AppStorage.setOrCreate<number>(AppStorageKeys.USER_ID, result.user.id);
      AppStorage.setOrCreate<string>(AppStorageKeys.USERNAME, result.user.username);
      AppStorage.setOrCreate<string>(AppStorageKeys.USER_ROLE, result.user.role || 'user');
      AppStorage.setOrCreate<number>(AppStorageKeys.STUDENT_PROFILE_ID, result.studentProfileId);
      AppStorage.setOrCreate<boolean>(AppStorageKeys.PROFILE_COMPLETED, false);
      const snapshot = new SessionSnapshot();
      snapshot.token = result.accessToken;
      snapshot.userId = result.user.id;
      snapshot.username = result.user.username;
      snapshot.role = result.user.role || 'user';
      snapshot.studentProfileId = result.studentProfileId;
      snapshot.profileCompleted = false;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await SessionStorageService.save(context, snapshot);
      promptAction.showToast({ message: '注册成功，请完善学生档案' });
      this.appPathStack.clear();
      const param: ProfileSetupRouteParam = new ProfileSetupRouteParam();
      param.requireSetup = true;
      this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, param);
    } catch (error) {
      promptAction.showToast({ message: '注册失败，请稍后重试' });
      console.error(`注册失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '注册账号' })
        Scroll() {
          Column({ space: 16 }) {
            TextInput({ placeholder: '用户名', text: this.username }).onChange((value: string) => this.username = value)
            TextInput({ placeholder: '手机号', text: this.phone }).type(InputType.PhoneNumber).onChange((value: string) => this.phone = value)
            TextInput({ placeholder: '密码（至少6位）', text: this.password }).type(InputType.Password).onChange((value: string) => this.password = value)
            TextInput({ placeholder: '确认密码', text: this.confirmPassword }).type(InputType.Password).onChange((value: string) => this.confirmPassword = value)
            Text('注册成功后需先填写学生档案，完成后才能使用应用。')
              .fontSize(13).fontColor('#667085').width('100%')
            Button(this.isLoading ? '提交中...' : '注册')
              .width('100%')
              .enabled(!this.isLoading)
              .backgroundColor('#2F6BFF')
              .onClick(() => void this.register())
          }
          .padding(24)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')
    }
    .hideTitleBar(true)
  }
}
