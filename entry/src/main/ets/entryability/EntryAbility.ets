import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import {
  DistributedStudySnapshot,
  DistributedStudySnapshotCodec
} from '../model/DistributedStudyModels';
import { DistributedStudyService } from '../service/DistributedStudyService';

const DOMAIN = 0x0000;
const CONTINUE_SCHEMA_VERSION: string = 'smartStudySchemaVersion';
const CONTINUE_SESSION_ID: string = 'smartStudySessionId';
const CONTINUE_ROUTE: string = 'smartStudyRoute';
const CONTINUE_TASK_ID: string = 'smartStudyTaskId';
const CONTINUE_TASK_STATUS: string = 'smartStudyTaskStatus';
const CONTINUE_DATE: string = 'smartStudySelectedDate';
const CONTINUE_FILTER: string = 'smartStudyFilter';
const CONTINUE_UPDATED_AT: string = 'smartStudyUpdatedAt';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.restoreContinuation(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.restoreContinuation(want);
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const enabled: boolean =
      AppStorage.get<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED) || false;
    const snapshot: DistributedStudySnapshot = DistributedStudyService.getLatestSnapshot();
    if (!enabled || !DistributedStudySnapshotCodec.isUsable(snapshot)) {
      return AbilityConstant.OnContinueResult.REJECT;
    }
    wantParam[CONTINUE_SCHEMA_VERSION] = snapshot.schemaVersion;
    const userId: number = AppStorage.get<number>(AppStorageKeys.USER_ID) || 0;
    wantParam[CONTINUE_SESSION_ID] = DistributedStudySnapshotCodec.sessionIdForUser(userId);
    wantParam[CONTINUE_ROUTE] = snapshot.routeName;
    wantParam[CONTINUE_TASK_ID] = snapshot.taskId;
    wantParam[CONTINUE_TASK_STATUS] = snapshot.taskStatus;
    wantParam[CONTINUE_DATE] = snapshot.selectedDate;
    wantParam[CONTINUE_FILTER] = snapshot.filter;
    wantParam[CONTINUE_UPDATED_AT] = snapshot.updatedAt;
    return AbilityConstant.OnContinueResult.AGREE;
  }

  private restoreContinuation(want: Want): void {
    if (want.parameters === undefined) return;
    const sessionId: string = (want.parameters[CONTINUE_SESSION_ID] as string) || '';
    const snapshot = new DistributedStudySnapshot();
    snapshot.schemaVersion = (want.parameters[CONTINUE_SCHEMA_VERSION] as number) || 0;
    snapshot.routeName = (want.parameters[CONTINUE_ROUTE] as string) || '';
    snapshot.taskId = (want.parameters[CONTINUE_TASK_ID] as number) || 0;
    snapshot.taskStatus = (want.parameters[CONTINUE_TASK_STATUS] as string) || '';
    snapshot.selectedDate = (want.parameters[CONTINUE_DATE] as string) || '';
    snapshot.filter = (want.parameters[CONTINUE_FILTER] as string) || 'WEEK';
    snapshot.updatedAt = (want.parameters[CONTINUE_UPDATED_AT] as number) || 0;
    DistributedStudyService.storePendingSnapshot(snapshot, sessionId);
  }
}
