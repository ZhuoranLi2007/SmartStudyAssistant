import { common } from '@kit.AbilityKit';
import { AppRoutes, DistributedStudyRouteParam, ProfileSetupRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { DistributedStudySnapshot } from '../model/DistributedStudyModels';
import { DistributedStudyService } from '../service/DistributedStudyService';
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
    AppStorage.setOrCreate<string>(AppStorageKeys.USER_ROLE, 'user');
    AppStorage.setOrCreate<number>(AppStorageKeys.STUDENT_PROFILE_ID, 0);
    AppStorage.setOrCreate<boolean>(AppStorageKeys.PROFILE_COMPLETED, false);
    AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_SYNC_STATUS, 'DISABLED');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_ID, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_STATUS, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER, 'WEEK');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT, 0);
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
      AppStorage.setOrCreate<boolean>(AppStorageKeys.PROFILE_COMPLETED, snapshot.profileCompleted);
      if (!snapshot.token) {
        this.appPathStack.pushPathByName(AppRoutes.LOGIN, null, false);
        return;
      }
      if (!snapshot.profileCompleted) {
        const param: ProfileSetupRouteParam = new ProfileSetupRouteParam();
        param.requireSetup = true;
        this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, param, false);
        return;
      }
      this.openHomeOrContinuation(snapshot.userId);
    } catch (error) {
      console.error(`恢复登录状态失败: ${JSON.stringify(error)}`);
      this.appPathStack.pushPathByName(AppRoutes.LOGIN, null, false);
    }
  }

  private openHomeOrContinuation(userId: number): void {
    const snapshot: DistributedStudySnapshot | undefined =
      DistributedStudyService.consumePendingSnapshot(userId);
    if (snapshot !== undefined && snapshot.routeName === AppRoutes.STUDY_PLAN) {
      const param = new DistributedStudyRouteParam();
      param.taskId = snapshot.taskId;
      param.taskStatus = snapshot.taskStatus;
      param.selectedDate = snapshot.selectedDate;
      param.filter = snapshot.filter;
      param.updatedAt = snapshot.updatedAt;
      this.appPathStack.pushPathByName(AppRoutes.STUDY_PLAN, param, false);
      return;
    }
    this.appPathStack.pushPathByName(AppRoutes.HOME, null, false);
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
