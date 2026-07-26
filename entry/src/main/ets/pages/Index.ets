import { common } from '@kit.AbilityKit';
import { AppRoutes, ContinuationRouteParam, ProfileSetupRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { ContinuationSnapshot } from '../model/DistributedStudyModels';
import { DistributedSyncService } from '../service/DistributedStudyService';
import { PageRefreshCoordinator } from '../service/PageRefreshCoordinator';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';
import { PageMap } from './PageMap';

@Entry
@Component
struct Index {
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.initializeStorage();
    PageRefreshCoordinator.initialize();
    void this.restoreSession();
  }

  private initializeStorage(): void {
    this.ensureString(AppStorageKeys.AUTH_TOKEN, '');
    this.ensureNumber(AppStorageKeys.USER_ID, 0);
    this.ensureString(AppStorageKeys.USERNAME, '');
    this.ensureString(AppStorageKeys.USER_ROLE, 'user');
    this.ensureNumber(AppStorageKeys.STUDENT_PROFILE_ID, 0);
    this.ensureBoolean(AppStorageKeys.PROFILE_COMPLETED, false);
    this.ensureBoolean(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
    this.ensureString(AppStorageKeys.DISTRIBUTED_SYNC_STATUS, 'DISABLED');
    this.ensureString(AppStorageKeys.DISTRIBUTED_LAST_EVENT_TYPE, '');
    this.ensureNumber(AppStorageKeys.DISTRIBUTED_LAST_EVENT_AT, 0);
  }

  private ensureString(key: string, value: string): void {
    if (!AppStorage.has(key)) AppStorage.setOrCreate<string>(key, value);
  }

  private ensureNumber(key: string, value: number): void {
    if (!AppStorage.has(key)) AppStorage.setOrCreate<number>(key, value);
  }

  private ensureBoolean(key: string, value: boolean): void {
    if (!AppStorage.has(key)) AppStorage.setOrCreate<boolean>(key, value);
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
        const param = new ProfileSetupRouteParam();
        param.requireSetup = true;
        this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, param, false);
        return;
      }
      await DistributedSyncService.restore(context, snapshot.userId);
      this.openHomeOrContinuation(snapshot.userId);
    } catch (error) {
      console.error(`恢复登录状态失败: ${JSON.stringify(error)}`);
      this.appPathStack.pushPathByName(AppRoutes.LOGIN, null, false);
    }
  }

  private openHomeOrContinuation(userId: number): void {
    const snapshot: ContinuationSnapshot | undefined = DistributedSyncService.consumePendingContinuation(userId);
    if (snapshot === undefined) {
      this.appPathStack.pushPathByName(AppRoutes.HOME, null, false);
      return;
    }
    const param = new ContinuationRouteParam();
    param.entityId = snapshot.entityId;
    param.entityKey = snapshot.entityKey;
    param.parentEntityId = snapshot.parentEntityId;
    param.selectedDate = snapshot.selectedDate;
    param.filter = snapshot.filter;
    param.tabIndex = snapshot.tabIndex;
    param.searchKeyword = snapshot.searchKeyword;
    param.updatedAt = snapshot.updatedAt;
    this.appPathStack.pushPathByName(snapshot.routeName, param, false);
  }

  build() {
    Navigation(this.appPathStack) {
      Column({ space: 12 }) {
        Image($r('app.media.realImageGen_education_0')).width(120).height(120).borderRadius(24)
        Text('智学规划助手').fontSize(26).fontWeight(FontWeight.Bold)
        Text('正在加载...').fontColor('#667085')
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    }.navDestination(PageMap).mode(NavigationMode.Stack).hideTitleBar(true)
  }
}
