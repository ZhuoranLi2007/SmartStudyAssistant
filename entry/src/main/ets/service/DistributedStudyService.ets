import {
  abilityAccessCtrl,
  common,
  PermissionRequestResult,
  Permissions
} from '@kit.AbilityKit';
import { distributedDataObject } from '@kit.ArkData';
import { AppStorageKeys } from '../common/AppStorageKeys';
import {
  DistributedStatusListener,
  DistributedStudyListener,
  DistributedStudySnapshot,
  DistributedStudySnapshotCodec,
  DistributedSyncStatus
} from '../model/DistributedStudyModels';

const DISTRIBUTED_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
const DISTRIBUTED_CAPABILITY: string =
  'SystemCapability.DistributedDataManager.DataObject.DistributedObject';

class DistributedStudyCoordinator {
  private dataObject: distributedDataObject.DataObject | undefined = undefined;
  private studyListeners: DistributedStudyListener[] = [];
  private statusListeners: DistributedStatusListener[] = [];
  private status: DistributedSyncStatus = DistributedSyncStatus.DISABLED;
  private userId: number = 0;
  private latestSnapshot: DistributedStudySnapshot = new DistributedStudySnapshot();
  private lastPublishedAt: number = 0;
  private lastReceivedAt: number = 0;

  async enable(context: common.UIAbilityContext, userId: number): Promise<DistributedSyncStatus> {
    if (userId <= 0) {
      this.setStatus(DistributedSyncStatus.ERROR);
      return this.status;
    }
    if (!canIUse(DISTRIBUTED_CAPABILITY)) {
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
      this.setStatus(DistributedSyncStatus.UNSUPPORTED);
      return this.status;
    }
    if (this.dataObject !== undefined && this.userId === userId) return this.status;
    await this.disable();
    this.userId = userId;
    this.setStatus(DistributedSyncStatus.WAITING_PERMISSION);
    if (!(await this.requestPermission(context))) {
      this.userId = 0;
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
      this.setStatus(DistributedSyncStatus.PERMISSION_DENIED);
      return this.status;
    }
    try {
      const source = new DistributedStudySnapshot();
      this.dataObject = distributedDataObject.create(context, source);
      this.dataObject.on('change', (sessionId: string, fields: Array<string>): void => {
        this.handleDataChange(sessionId, fields);
      });
      this.dataObject.on('status',
        (sessionId: string, networkId: string, deviceStatus: 'online' | 'offline' | 'restored'): void => {
          this.handleDeviceStatus(sessionId, networkId, deviceStatus);
        });
      await this.dataObject.setSessionId(DistributedStudySnapshotCodec.sessionIdForUser(userId));
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, true);
      this.setStatus(DistributedSyncStatus.WAITING_DEVICE);
    } catch (error) {
      console.error(`启用分布式学习接续失败: ${JSON.stringify(error)}`);
      this.dataObject = undefined;
      this.userId = 0;
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
      this.setStatus(DistributedSyncStatus.ERROR);
    }
    return this.status;
  }

  async disable(): Promise<void> {
    const activeObject: distributedDataObject.DataObject | undefined = this.dataObject;
    this.dataObject = undefined;
    if (activeObject !== undefined) {
      try {
        activeObject.off('change');
        activeObject.off('status');
        await activeObject.setSessionId();
      } catch (error) {
        console.warn(`退出分布式学习接续失败: ${JSON.stringify(error)}`);
      }
    }
    this.userId = 0;
    this.latestSnapshot = new DistributedStudySnapshot();
    this.lastPublishedAt = 0;
    this.lastReceivedAt = 0;
    AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
    this.setStatus(DistributedSyncStatus.DISABLED);
  }

  publish(source: DistributedStudySnapshot): void {
    if (this.dataObject === undefined) return;
    const snapshot: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
    if (!DistributedStudySnapshotCodec.isUsable(snapshot)) return;
    const timestamp: number = Math.max(Date.now(), this.lastPublishedAt + 1);
    snapshot.updatedAt = timestamp;
    this.latestSnapshot = snapshot;
    this.lastPublishedAt = timestamp;
    // updatedAt 最后写入，接收端以它作为整批字段已更新完成的提交标记。
    this.dataObject['schemaVersion'] = snapshot.schemaVersion;
    this.dataObject['routeName'] = snapshot.routeName;
    this.dataObject['taskId'] = snapshot.taskId;
    this.dataObject['taskStatus'] = snapshot.taskStatus;
    this.dataObject['selectedDate'] = snapshot.selectedDate;
    this.dataObject['filter'] = snapshot.filter;
    this.dataObject['updatedAt'] = snapshot.updatedAt;
  }

  subscribe(listener: DistributedStudyListener): void {
    if (this.studyListeners.indexOf(listener) < 0) this.studyListeners.push(listener);
  }

  unsubscribe(listener: DistributedStudyListener): void {
    const index: number = this.studyListeners.indexOf(listener);
    if (index >= 0) this.studyListeners.splice(index, 1);
  }

  subscribeStatus(listener: DistributedStatusListener): void {
    if (this.statusListeners.indexOf(listener) < 0) this.statusListeners.push(listener);
  }

  unsubscribeStatus(listener: DistributedStatusListener): void {
    const index: number = this.statusListeners.indexOf(listener);
    if (index >= 0) this.statusListeners.splice(index, 1);
  }

  getStatus(): DistributedSyncStatus {
    return this.status;
  }

  getLatestSnapshot(): DistributedStudySnapshot {
    return DistributedStudySnapshotCodec.normalize(this.latestSnapshot);
  }

  storePendingSnapshot(source: DistributedStudySnapshot, sessionId: string): void {
    const snapshot: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
    if (!DistributedStudySnapshotCodec.isUsable(snapshot)) return;
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID, sessionId);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE, snapshot.routeName);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_ID, snapshot.taskId);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_STATUS, snapshot.taskStatus);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE, snapshot.selectedDate);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER, snapshot.filter);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT, snapshot.updatedAt);
  }

  consumePendingSnapshot(userId: number): DistributedStudySnapshot | undefined {
    const pendingSessionId: string =
      AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID) || '';
    const expectedSessionId: string = DistributedStudySnapshotCodec.sessionIdForUser(userId);
    const snapshot = new DistributedStudySnapshot();
    snapshot.routeName = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE) || '';
    snapshot.taskId = AppStorage.get<number>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_ID) || 0;
    snapshot.taskStatus = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_STATUS) || '';
    snapshot.selectedDate = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE) || '';
    snapshot.filter = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER) || 'WEEK';
    snapshot.updatedAt = AppStorage.get<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT) || 0;
    this.clearPendingSnapshot();
    // 接续参数来自系统 Want，但仍必须匹配当前登录账号，避免串用上一账号的页面状态。
    if (pendingSessionId !== expectedSessionId) return undefined;
    const normalized: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(snapshot);
    return DistributedStudySnapshotCodec.isUsable(normalized) ? normalized : undefined;
  }

  clearPendingSnapshot(): void {
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_ID, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_TASK_STATUS, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER, 'WEEK');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT, 0);
  }

  private async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const result: PermissionRequestResult =
        await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, [DISTRIBUTED_PERMISSION]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (error) {
      console.warn(`申请分布式数据同步权限失败: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private handleDataChange(_sessionId: string, fields: Array<string>): void {
    if (this.dataObject === undefined || fields.indexOf('updatedAt') < 0) return;
    const source = new DistributedStudySnapshot();
    source.schemaVersion = this.dataObject['schemaVersion'] as number;
    source.routeName = this.dataObject['routeName'] as string;
    source.taskId = this.dataObject['taskId'] as number;
    source.taskStatus = this.dataObject['taskStatus'] as string;
    source.selectedDate = this.dataObject['selectedDate'] as string;
    source.filter = this.dataObject['filter'] as string;
    source.updatedAt = this.dataObject['updatedAt'] as number;
    const snapshot: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
    if (!DistributedStudySnapshotCodec.isUsable(snapshot) ||
      snapshot.updatedAt === this.lastPublishedAt ||
      snapshot.updatedAt <= this.lastReceivedAt) return;
    this.lastReceivedAt = snapshot.updatedAt;
    this.latestSnapshot = snapshot;
    for (let index: number = 0; index < this.studyListeners.length; index++) {
      this.studyListeners[index](snapshot);
    }
  }

  private handleDeviceStatus(
    _sessionId: string,
    _networkId: string,
    deviceStatus: 'online' | 'offline' | 'restored'
  ): void {
    if (deviceStatus === 'online' || deviceStatus === 'restored') {
      this.setStatus(DistributedSyncStatus.CONNECTED);
    } else if (this.dataObject !== undefined) {
      this.setStatus(DistributedSyncStatus.WAITING_DEVICE);
    }
  }

  private setStatus(value: DistributedSyncStatus): void {
    this.status = value;
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_SYNC_STATUS, value);
    for (let index: number = 0; index < this.statusListeners.length; index++) {
      this.statusListeners[index](value);
    }
  }
}

export const DistributedStudyService = new DistributedStudyCoordinator();
