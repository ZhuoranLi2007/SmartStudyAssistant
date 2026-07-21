import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { MainTabBar } from '../components/MainTabBar';
import { QuickFunctionGrid } from '../components/profile/QuickFunctionGrid';
import { SettingListItem } from '../components/profile/SettingListItem';
import { UserProfileCard } from '../components/profile/UserProfileCard';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, ProfileOverview } from '../model/ProfileModels';
import { AuthSessionService } from '../service/AuthSessionService';
import { ProfileService } from '../service/ProfileService';

@Component
export struct ProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USERNAME) username: string = '智学用户';
  @State overview: ProfileOverview = ProfileMockData.getOverview();
  @State isLoading: boolean = false;

  aboutToAppear(): void { void this.loadData(); }

  private async loadData(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      const profileResult: DataLoadResult<ProfileOverview> = await ProfileService.getOverview();
      this.overview = profileResult.data;
    } catch (error) {
      console.error(`个人中心加载失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '个人中心加载失败' });
      this.overview = {
        familyCode: '', studentBindCode: '', studentName: '', studentBound: false, studentProfileId: 0,
        learning: { courseCount: 0, weeklyTaskCount: 0, favoriteCount: 0, wrongQuestionCount: 0 }
      };
    } finally {
      this.isLoading = false;
    }
  }

  private showLogoutDialog(): void {
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
      console.error(`退出登录失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '退出失败，请稍后重试' });
    }
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 14 }) {
            Row() {
              Text('我的').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#101828').layoutWeight(1)
              Text(this.isLoading ? '加载中' : '刷新').fontSize(13).fontColor('#2F6BFF')
                .onClick(() => { if (!this.isLoading) void this.loadData(); })
            }.width('100%')
            UserProfileCard({
              username: this.username,
              studentName: this.overview.studentName
            })
            Button('修改学生档案')
              .width('100%')
              .height(48)
              .backgroundColor('#2F6BFF')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
            QuickFunctionGrid()
            Column() {
              Text('其他服务').fontSize(17).fontWeight(FontWeight.Bold).width('100%').margin({ bottom: 6 })
              SettingListItem({ title: '客服中心', subtitle: '常见问题与在线咨询', routeName: AppRoutes.CUSTOMER_SERVICE })
              Divider().color('#EAECF0')
              SettingListItem({ title: '意见反馈', routeName: AppRoutes.FEEDBACK })
              Divider().color('#EAECF0')
              SettingListItem({ title: '关于平台', routeName: AppRoutes.PLATFORM_INFO, infoType: 'ABOUT' })
              Divider().color('#EAECF0')
              SettingListItem({ title: '设置', routeName: AppRoutes.SETTINGS })
            }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
            Button('退出登录').width('100%').height(48).backgroundColor('#FEF3F2').fontColor('#D92D20')
              .onClick(() => this.showLogoutDialog())
          }.padding({ left: 16, right: 16, top: 12, bottom: 24 }).width('100%')
        }.layoutWeight(1).width('100%')
        MainTabBar({ activeRoute: AppRoutes.PROFILE })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
