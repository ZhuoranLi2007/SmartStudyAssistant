import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { AppConfig } from '../common/AppConfig';
import { AuthService } from '../service/AuthService';

@Component
export struct RegisterPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State username: string = '';
  @State phone: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State role: string = 'parent';
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
      } else {
        await AuthService.register(this.username, this.phone, this.password, this.role);
      }
      promptAction.showToast({ message: '注册成功，请登录' });
      this.appPathStack.pop();
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
            Text('选择账号角色').width('100%').fontWeight(FontWeight.Medium)
            Row({ space: 12 }) {
              Button('家长账号').layoutWeight(1).backgroundColor(this.role === 'parent' ? '#2F6BFF' : '#D0D5DD').onClick(() => this.role = 'parent')
              Button('学生账号').layoutWeight(1).backgroundColor(this.role === 'student' ? '#2F6BFF' : '#D0D5DD').onClick(() => this.role = 'student')
            }
            if (this.role === 'student') {
              Text('学生注册后可在“我的”页面使用一次性绑定码关联家庭。').fontSize(13).fontColor('#667085')
            }
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
