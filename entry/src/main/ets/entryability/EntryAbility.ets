import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { ContinuationSnapshot, ContinuationSnapshotCodec, DistributedEventCodec } from '../model/DistributedStudyModels';
import { DistributedSyncService } from '../service/DistributedStudyService';

const DOMAIN = 0x0000;
const LOG_TAG: string = 'SmartStudyEntry';
const PREFIX: string = 'smartStudyContinue';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.restoreContinuation(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      hilog.error(DOMAIN, LOG_TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(error));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) hilog.error(DOMAIN, LOG_TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(error));
    });
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void { this.restoreContinuation(want); }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const enabled: boolean = AppStorage.get<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED) || false;
    const userId: number = AppStorage.get<number>(AppStorageKeys.USER_ID) || 0;
    const snapshot: ContinuationSnapshot = DistributedSyncService.getLatestContinuation();
    if (!enabled || userId <= 0 || !ContinuationSnapshotCodec.isUsable(snapshot)) {
      return AbilityConstant.OnContinueResult.REJECT;
    }
    wantParam[`${PREFIX}Schema`] = snapshot.schemaVersion;
    wantParam[`${PREFIX}Session`] = DistributedEventCodec.sessionIdForUser(userId);
    wantParam[`${PREFIX}Route`] = snapshot.routeName;
    wantParam[`${PREFIX}EntityId`] = snapshot.entityId;
    wantParam[`${PREFIX}EntityKey`] = snapshot.entityKey;
    wantParam[`${PREFIX}ParentId`] = snapshot.parentEntityId;
    wantParam[`${PREFIX}Date`] = snapshot.selectedDate;
    wantParam[`${PREFIX}Filter`] = snapshot.filter;
    wantParam[`${PREFIX}Tab`] = snapshot.tabIndex;
    wantParam[`${PREFIX}Search`] = snapshot.searchKeyword;
    wantParam[`${PREFIX}UpdatedAt`] = snapshot.updatedAt;
    return AbilityConstant.OnContinueResult.AGREE;
  }

  private restoreContinuation(want: Want): void {
    if (want.parameters === undefined) return;
    const snapshot = new ContinuationSnapshot();
    snapshot.schemaVersion = (want.parameters[`${PREFIX}Schema`] as number) || 0;
    snapshot.routeName = (want.parameters[`${PREFIX}Route`] as string) || '';
    snapshot.entityId = (want.parameters[`${PREFIX}EntityId`] as number) || 0;
    snapshot.entityKey = (want.parameters[`${PREFIX}EntityKey`] as string) || '';
    snapshot.parentEntityId = (want.parameters[`${PREFIX}ParentId`] as number) || 0;
    snapshot.selectedDate = (want.parameters[`${PREFIX}Date`] as string) || '';
    snapshot.filter = (want.parameters[`${PREFIX}Filter`] as string) || '';
    snapshot.tabIndex = (want.parameters[`${PREFIX}Tab`] as number) || 0;
    snapshot.searchKeyword = (want.parameters[`${PREFIX}Search`] as string) || '';
    snapshot.updatedAt = (want.parameters[`${PREFIX}UpdatedAt`] as number) || 0;
    const sessionId: string = (want.parameters[`${PREFIX}Session`] as string) || '';
    DistributedSyncService.storePendingContinuation(snapshot, sessionId);
  }
}
