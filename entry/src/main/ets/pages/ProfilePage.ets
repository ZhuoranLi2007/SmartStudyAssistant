import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes, OrderRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { MainTabBar } from '../components/MainTabBar';
import { FamilyInfoCard } from '../components/profile/FamilyInfoCard';
import { LearningOverviewCard } from '../components/profile/LearningOverviewCard';
import { QuickFunctionGrid } from '../components/profile/QuickFunctionGrid';
import { SettingListItem } from '../components/profile/SettingListItem';
import { UserProfileCard } from '../components/profile/UserProfileCard';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, MyCourse, OrderFilter, ProfileOverview } from '../model/ProfileModels';
import { AuthSessionService } from '../service/AuthSessionService';
import { CourseService } from '../service/CourseService';
import { ProfileService } from '../service/ProfileService';

@Component
export struct ProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USERNAME) username: string = '演示家长';
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @State overview: ProfileOverview = ProfileMockData.getOverview();
  @State myCourses: MyCourse[] = [];
  @State dataSource: DataSource = DataSource.MOCK;
  @State isLoading: boolean = false;

  aboutToAppear(): void { void this.loadData(); }

  private async loadData(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      const profileResult: DataLoadResult<ProfileOverview> = await ProfileService.getOverview();
      const courseResult: DataLoadResult<MyCourse[]> = await CourseService.getMyCourses();
      this.overview = profileResult.data;
      this.myCourses = courseResult.data;
      this.dataSource = profileResult.source === DataSource.MOCK || courseResult.source === DataSource.MOCK ? DataSource.MOCK : DataSource.LIVE;
    } catch (error) {
      console.error(`个人中心加载失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '个人中心加载失败，已使用演示数据' });
      this.overview = ProfileMockData.getOverview();
      this.myCourses = ProfileMockData.getCourses();
      this.dataSource = DataSource.MOCK;
    } finally {
      this.isLoading = false;
    }
  }

  private openOrders(status: OrderFilter): void {
    const param: OrderRouteParam = new OrderRouteParam();
    param.status = status;
    this.appPathStack.pushPathByName(AppRoutes.MY_ORDERS, param);
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

  @Builder
  private orderShortcut(label: string, count: number, filter: OrderFilter) {
    Column({ space: 5 }) {
      Text(`${count}`).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
      Text(label).fontSize(12).fontColor('#667085')
    }.layoutWeight(1).onClick(() => this.openOrders(filter))
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 14 }) {
            Text('我的').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#101828').width('100%')
            UserProfileCard({ username: this.username, role: this.role, studentName: this.overview.studentName, studentBound: this.overview.studentBound })
            LearningOverviewCard({ overview: this.overview.learning })
            Column({ space: 12 }) {
              Row() {
                Text('我的课程').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
                Text('查看全部 ›').fontSize(13).fontColor('#2F6BFF').onClick(() => this.appPathStack.pushPathByName(AppRoutes.MY_COURSES, null))
              }.width('100%')
              if (this.myCourses.length > 0) {
                Text(this.myCourses[0].name).fontSize(15).fontWeight(FontWeight.Medium).width('100%')
                Progress({ value: this.myCourses[0].progress.progress, total: 100, type: ProgressType.Linear }).color('#2F6BFF').width('100%')
                Text(`已完成 ${this.myCourses[0].progress.completedLessons}/${this.myCourses[0].progress.totalLessons} 课时 · 下一节：${this.myCourses[0].progress.nextLesson}`)
                  .fontSize(12).fontColor('#667085').width('100%')
              } else {
                Text('暂无正在学习的课程').fontSize(13).fontColor('#98A2B3').width('100%')
              }
            }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
            Column({ space: 13 }) {
              Row() {
                Text('我的订单').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
                Text('全部订单 ›').fontSize(13).fontColor('#2F6BFF').onClick(() => this.openOrders(OrderFilter.ALL))
              }.width('100%')
              Row() {
                this.orderShortcut('全部', 3, OrderFilter.ALL)
                this.orderShortcut('待支付', 1, OrderFilter.PENDING)
                this.orderShortcut('已支付', 1, OrderFilter.PAID)
                this.orderShortcut('已取消', 1, OrderFilter.CANCELLED)
              }.width('100%')
            }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
            QuickFunctionGrid()
            FamilyInfoCard({ role: this.role, overview: this.overview })
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
            if (this.dataSource === DataSource.MOCK) {
              Text('当前课程、订单、收藏、错题和报告为演示数据，后端接口可用后会自动切换。')
                .fontSize(11).fontColor('#98A2B3').lineHeight(18).width('100%')
            }
            Button('退出登录').width('100%').height(48).backgroundColor('#FEF3F2').fontColor('#D92D20')
              .onClick(() => this.showLogoutDialog())
          }.padding({ left: 16, right: 16, top: 12, bottom: 24 }).width('100%')
        }.layoutWeight(1).width('100%')
        MainTabBar({ activeRoute: AppRoutes.PROFILE })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
