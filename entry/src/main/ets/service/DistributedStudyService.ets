import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { distributedDataObject, preferences } from '@kit.ArkData';
import { AppStorageKeys } from '../common/AppStorageKeys';
import {
  ContinuationSnapshot,
  ContinuationSnapshotCodec,
  DistributedChangeEvent,
  DistributedChangeListener,
  DistributedEntityType,
  DistributedEventCodec,
  DistributedEventType,
  DistributedStatusListener,
  DistributedStudyListener,
  DistributedStudySnapshot,
  DistributedStudySnapshotCodec,
  DistributedSyncStatus
} from '../model/DistributedStudyModels';

const DISTRIBUTED_PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC';
const DISTRIBUTED_CAPABILITY: string = 'SystemCapability.DistributedDataManager.DataObject.DistributedObject';
const PREFERENCE_NAME: string = 'smartstudy_distributed_sync';
const MAX_RECENT_EVENTS: number = 200;

class EntitySubscription {
  entityType: string = '';
  listener: DistributedChangeListener = (_event: DistributedChangeEvent): void => {};
}

class DistributedSyncCoordinator {
  private dataObject: distributedDataObject.DataObject | undefined = undefined;
  private subscriptions: EntitySubscription[] = [];
  private allListeners: DistributedChangeListener[] = [];
  private statusListeners: DistributedStatusListener[] = [];
  private status: DistributedSyncStatus = DistributedSyncStatus.DISABLED;
  private context: common.UIAbilityContext | undefined = undefined;
  private userId: number = 0;
  private sourceDeviceId: string = '';
  private sequence: number = 0;
  private lastPublishedAt: number = 0;
  private recentEventIds: string[] = [];
  private entityVersions: Map<string, number> = new Map<string, number>();
  private latestContinuation: ContinuationSnapshot = new ContinuationSnapshot();
  private changeDebounceTimer: number = -1;
  private publishQueue: DistributedChangeEvent[] = [];
  private publishTimer: number = -1;

  async enable(
    context: common.UIAbilityContext,
    userId: number,
    requestPermission: boolean = true
  ): Promise<DistributedSyncStatus> {
    if (userId <= 0) {
      this.setStatus(DistributedSyncStatus.ERROR);
      return this.status;
    }
    if (!canIUse(DISTRIBUTED_CAPABILITY)) {
      if (requestPermission) await this.saveEnabled(context, userId, false);
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
      this.setStatus(DistributedSyncStatus.UNSUPPORTED);
      console.warn('分布式同步不可用：当前设备缺少分布式数据对象能力');
      return this.status;
    }
    if (this.dataObject !== undefined && this.userId === userId) return this.status;
    await this.disable(false);
    this.context = context;
    this.userId = userId;
    this.sourceDeviceId = await this.loadOrCreateDeviceId(context);
    this.setStatus(DistributedSyncStatus.WAITING_PERMISSION);
    console.info(`分布式同步开始启用: userId=${userId}, requestPermission=${requestPermission}`);
    const granted: boolean = requestPermission ? await this.requestPermission(context) : this.hasPermission(context);
    if (!granted) {
      await this.saveEnabled(context, userId, false);
      this.userId = 0;
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
      this.setStatus(DistributedSyncStatus.PERMISSION_DENIED);
      console.warn('分布式同步未启用：用户未授予分布式数据同步权限');
      return this.status;
    }
    try {
      this.dataObject = distributedDataObject.create(context, new DistributedChangeEvent());
      this.dataObject.on('change', (_sessionId: string, fields: Array<string>): void => {
        this.handleDataChange(fields);
      });
      this.dataObject.on('status',
        (_sessionId: string, _networkId: string, deviceStatus: 'online' | 'offline' | 'restored'): void => {
          this.handleDeviceStatus(deviceStatus);
        });
      this.setStatus(DistributedSyncStatus.WAITING_DEVICE);
      await this.dataObject.setSessionId(DistributedEventCodec.sessionIdForUser(userId));
      await this.saveEnabled(context, userId, true);
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, true);
      console.info(`分布式同步会话已加入: session=${DistributedEventCodec.sessionIdForUser(userId)}`);
    } catch (error) {
      console.error(`启用分布式同步失败: ${JSON.stringify(error)}`);
      this.dataObject = undefined;
      this.userId = 0;
      AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
      this.setStatus(DistributedSyncStatus.ERROR);
    }
    return this.status;
  }

  async restore(context: common.UIAbilityContext, userId: number): Promise<DistributedSyncStatus> {
    if (!(await this.loadEnabled(context, userId))) return DistributedSyncStatus.DISABLED;
    return this.enable(context, userId, false);
  }

  async disable(persistPreference: boolean = true): Promise<void> {
    const oldContext: common.UIAbilityContext | undefined = this.context;
    const oldUserId: number = this.userId;
    const activeObject: distributedDataObject.DataObject | undefined = this.dataObject;
    this.dataObject = undefined;
    if (this.changeDebounceTimer >= 0) clearTimeout(this.changeDebounceTimer);
    this.changeDebounceTimer = -1;
    if (this.publishTimer >= 0) clearTimeout(this.publishTimer);
    this.publishTimer = -1;
    this.publishQueue = [];
    if (activeObject !== undefined) {
      try {
        activeObject.off('change');
        activeObject.off('status');
        await activeObject.setSessionId();
      } catch (error) {
        console.warn(`退出分布式会话失败: ${JSON.stringify(error)}`);
      }
    }
    if (persistPreference && oldContext !== undefined && oldUserId > 0) {
      await this.saveEnabled(oldContext, oldUserId, false);
    }
    this.context = undefined;
    this.userId = 0;
    this.lastPublishedAt = 0;
    this.recentEventIds = [];
    this.entityVersions.clear();
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_LAST_EVENT_TYPE, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_LAST_EVENT_AT, 0);
    AppStorage.setOrCreate<boolean>(AppStorageKeys.DISTRIBUTED_SYNC_ENABLED, false);
    this.setStatus(DistributedSyncStatus.DISABLED);
  }

  publish(source: DistributedChangeEvent): void {
    if (this.dataObject === undefined || this.userId <= 0) return;
    const event: DistributedChangeEvent = DistributedEventCodec.normalize(source);
    event.schemaVersion = DistributedEventCodec.SCHEMA_VERSION;
    event.sourceDeviceId = this.sourceDeviceId;
    event.userId = this.userId;
    event.updatedAt = Math.max(Date.now(), this.lastPublishedAt + 1);
    this.sequence++;
    event.eventId = event.eventId || `${this.sourceDeviceId}_${event.updatedAt}_${this.sequence}`;
    if (!DistributedEventCodec.isUsable(event)) return;
    this.lastPublishedAt = event.updatedAt;
    this.rememberEvent(event.eventId);
    this.entityVersions.set(DistributedEventCodec.entityKey(event), event.updatedAt);
    this.publishQueue.push(event);
    if (this.publishTimer < 0) this.flushNextPublishedEvent();
  }

  private flushNextPublishedEvent(): void {
    if (this.dataObject === undefined || this.publishQueue.length === 0) {
      this.publishTimer = -1;
      return;
    }
    const event: DistributedChangeEvent = this.publishQueue[0];
    this.publishQueue.splice(0, 1);
    this.dataObject['schemaVersion'] = event.schemaVersion;
    this.dataObject['eventId'] = event.eventId;
    this.dataObject['eventType'] = event.eventType;
    this.dataObject['entityType'] = event.entityType;
    this.dataObject['entityId'] = event.entityId;
    this.dataObject['entityKey'] = event.entityKey;
    this.dataObject['parentEntityId'] = event.parentEntityId;
    this.dataObject['routeName'] = event.routeName;
    this.dataObject['sourceDeviceId'] = event.sourceDeviceId;
    this.dataObject['userId'] = event.userId;
    this.dataObject['selectedDate'] = event.selectedDate;
    this.dataObject['filter'] = event.filter;
    this.dataObject['tabIndex'] = event.tabIndex;
    // 最后写入时间戳，接收端将它视为一次事件字段写入完成的提交标记。
    this.dataObject['updatedAt'] = event.updatedAt;
    console.info(`分布式事件已发布: type=${event.eventType}, entity=${event.entityType}, id=${event.entityId}`);
    if (this.publishQueue.length > 0) {
      // 单个 DDO 事件槽按顺序提交，避免同一业务操作的多个失效事件互相覆盖。
      this.publishTimer = setTimeout((): void => {
        this.publishTimer = -1;
        this.flushNextPublishedEvent();
      }, 200);
    } else {
      this.publishTimer = -1;
    }
  }

  publishChange(
    eventType: DistributedEventType,
    entityType: DistributedEntityType,
    entityId: number = 0,
    entityKey: string = '',
    parentEntityId: number = 0,
    routeName: string = ''
  ): void {
    const event = new DistributedChangeEvent();
    event.eventType = eventType;
    event.entityType = entityType;
    event.entityId = entityId;
    event.entityKey = entityKey;
    event.parentEntityId = parentEntityId;
    event.routeName = routeName;
    this.publish(event);
  }

  subscribe(entityType: string, listener: DistributedChangeListener): void {
    for (let index: number = 0; index < this.subscriptions.length; index++) {
      const item: EntitySubscription = this.subscriptions[index];
      if (item.entityType === entityType && item.listener === listener) return;
    }
    const subscription = new EntitySubscription();
    subscription.entityType = entityType;
    subscription.listener = listener;
    this.subscriptions.push(subscription);
  }

  unsubscribe(entityType: string, listener: DistributedChangeListener): void {
    this.subscriptions = this.subscriptions.filter((item: EntitySubscription) =>
      item.entityType !== entityType || item.listener !== listener);
  }

  subscribeAll(listener: DistributedChangeListener): void {
    if (this.allListeners.indexOf(listener) < 0) this.allListeners.push(listener);
  }

  unsubscribeAll(listener: DistributedChangeListener): void {
    const index: number = this.allListeners.indexOf(listener);
    if (index >= 0) this.allListeners.splice(index, 1);
  }

  subscribeStatus(listener: DistributedStatusListener): void {
    if (this.statusListeners.indexOf(listener) < 0) this.statusListeners.push(listener);
  }

  unsubscribeStatus(listener: DistributedStatusListener): void {
    const index: number = this.statusListeners.indexOf(listener);
    if (index >= 0) this.statusListeners.splice(index, 1);
  }

  getStatus(): DistributedSyncStatus { return this.status; }

  setContinuation(source: ContinuationSnapshot): void {
    const snapshot: ContinuationSnapshot = ContinuationSnapshotCodec.normalize(source);
    if (!ContinuationSnapshotCodec.isUsable(snapshot)) return;
    this.latestContinuation = snapshot;
  }

  getLatestContinuation(): ContinuationSnapshot {
    return ContinuationSnapshotCodec.normalize(this.latestContinuation);
  }

  storePendingContinuation(source: ContinuationSnapshot, sessionId: string): void {
    const snapshot: ContinuationSnapshot = ContinuationSnapshotCodec.normalize(source);
    if (!ContinuationSnapshotCodec.isUsable(snapshot)) return;
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID, sessionId);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE, snapshot.routeName);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_ENTITY_ID, snapshot.entityId);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ENTITY_KEY, snapshot.entityKey);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_PARENT_ID, snapshot.parentEntityId);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE, snapshot.selectedDate);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER, snapshot.filter);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_TAB_INDEX, snapshot.tabIndex);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SEARCH, snapshot.searchKeyword);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT, snapshot.updatedAt);
  }

  consumePendingContinuation(userId: number): ContinuationSnapshot | undefined {
    const sessionId: string = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID) || '';
    const snapshot = new ContinuationSnapshot();
    snapshot.routeName = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE) || '';
    snapshot.entityId = AppStorage.get<number>(AppStorageKeys.DISTRIBUTED_PENDING_ENTITY_ID) || 0;
    snapshot.entityKey = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_ENTITY_KEY) || '';
    snapshot.parentEntityId = AppStorage.get<number>(AppStorageKeys.DISTRIBUTED_PENDING_PARENT_ID) || 0;
    snapshot.selectedDate = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE) || '';
    snapshot.filter = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER) || '';
    snapshot.tabIndex = AppStorage.get<number>(AppStorageKeys.DISTRIBUTED_PENDING_TAB_INDEX) || 0;
    snapshot.searchKeyword = AppStorage.get<string>(AppStorageKeys.DISTRIBUTED_PENDING_SEARCH) || '';
    snapshot.updatedAt = AppStorage.get<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT) || 0;
    this.clearPendingContinuation();
    if (sessionId !== DistributedEventCodec.sessionIdForUser(userId)) return undefined;
    const normalized: ContinuationSnapshot = ContinuationSnapshotCodec.normalize(snapshot);
    return ContinuationSnapshotCodec.isUsable(normalized) ? normalized : undefined;
  }

  clearPendingContinuation(): void {
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SESSION_ID, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ROUTE, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_ENTITY_ID, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_ENTITY_KEY, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_PARENT_ID, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_DATE, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_FILTER, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_TAB_INDEX, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_PENDING_SEARCH, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_PENDING_UPDATED_AT, 0);
  }

  private handleDataChange(_fields: Array<string>): void {
    if (this.dataObject === undefined) return;
    if (this.changeDebounceTimer >= 0) clearTimeout(this.changeDebounceTimer);
    // DDO 可能分批回调字段变化，短暂合并后再读取完整事件，避免漏掉提交标记。
    this.changeDebounceTimer = setTimeout((): void => {
      this.changeDebounceTimer = -1;
      this.processDataChange();
    }, 80);
  }

  private processDataChange(): void {
    if (this.dataObject === undefined) return;
    const source = new DistributedChangeEvent();
    source.schemaVersion = this.dataObject['schemaVersion'] as number;
    source.eventId = this.dataObject['eventId'] as string;
    source.eventType = this.dataObject['eventType'] as string;
    source.entityType = this.dataObject['entityType'] as string;
    source.entityId = this.dataObject['entityId'] as number;
    source.entityKey = this.dataObject['entityKey'] as string;
    source.parentEntityId = this.dataObject['parentEntityId'] as number;
    source.routeName = this.dataObject['routeName'] as string;
    source.sourceDeviceId = this.dataObject['sourceDeviceId'] as string;
    source.userId = this.dataObject['userId'] as number;
    source.selectedDate = this.dataObject['selectedDate'] as string;
    source.filter = this.dataObject['filter'] as string;
    source.tabIndex = this.dataObject['tabIndex'] as number;
    source.updatedAt = this.dataObject['updatedAt'] as number;
    const event: DistributedChangeEvent = DistributedEventCodec.normalize(source);
    if (!DistributedEventCodec.isUsable(event)) {
      console.warn('分布式事件已忽略：事件字段不完整');
      return;
    }
    if (event.userId !== this.userId) {
      console.warn('分布式事件已忽略：账号不匹配');
      return;
    }
    if (event.sourceDeviceId === this.sourceDeviceId || this.recentEventIds.indexOf(event.eventId) >= 0) return;
    const entityKey: string = DistributedEventCodec.entityKey(event);
    const currentVersion: number = this.entityVersions.get(entityKey) || 0;
    if (event.updatedAt <= currentVersion) return;
    this.entityVersions.set(entityKey, event.updatedAt);
    this.rememberEvent(event.eventId);
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_LAST_EVENT_TYPE, event.eventType);
    AppStorage.setOrCreate<number>(AppStorageKeys.DISTRIBUTED_LAST_EVENT_AT, event.updatedAt);
    console.info(`分布式事件已接收: type=${event.eventType}, entity=${event.entityType}, id=${event.entityId}`);
    for (let index: number = 0; index < this.subscriptions.length; index++) {
      const subscription: EntitySubscription = this.subscriptions[index];
      if (subscription.entityType === event.entityType) subscription.listener(event);
    }
    for (let index: number = 0; index < this.allListeners.length; index++) this.allListeners[index](event);
  }

  private handleDeviceStatus(deviceStatus: 'online' | 'offline' | 'restored'): void {
    console.info(`分布式可信设备状态变化: status=${deviceStatus}`);
    if (deviceStatus === 'online' || deviceStatus === 'restored') {
      this.setStatus(DistributedSyncStatus.CONNECTED);
    } else if (this.dataObject !== undefined) {
      this.setStatus(DistributedSyncStatus.WAITING_DEVICE);
    }
  }

  private rememberEvent(eventId: string): void {
    this.recentEventIds.push(eventId);
    if (this.recentEventIds.length > MAX_RECENT_EVENTS) this.recentEventIds.shift();
  }

  private hasPermission(context: common.UIAbilityContext): boolean {
    try {
      return abilityAccessCtrl.createAtManager().checkAccessTokenSync(
        context.applicationInfo.accessTokenId, DISTRIBUTED_PERMISSION) === 0;
    } catch (error) {
      console.warn(`检查分布式权限失败: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    if (this.hasPermission(context)) return true;
    try {
      const result: PermissionRequestResult = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(context, [DISTRIBUTED_PERMISSION]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (error) {
      console.warn(`申请分布式权限失败: ${JSON.stringify(error)}`);
      return false;
    }
  }

  private async loadOrCreateDeviceId(context: common.UIAbilityContext): Promise<string> {
    const store = await preferences.getPreferences(context, { name: PREFERENCE_NAME });
    let deviceId: string = await store.get('sourceDeviceId', '') as string;
    if (!deviceId) {
      deviceId = `device_${Date.now()}_${Math.floor(Math.random() * 1000000000)}`;
      await store.put('sourceDeviceId', deviceId);
      await store.flush();
    }
    return deviceId;
  }

  private async saveEnabled(context: common.UIAbilityContext, userId: number, enabled: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, { name: PREFERENCE_NAME });
    await store.put(`enabled_${userId}`, enabled ? 1 : 0);
    await store.flush();
  }

  private async loadEnabled(context: common.UIAbilityContext, userId: number): Promise<boolean> {
    const store = await preferences.getPreferences(context, { name: PREFERENCE_NAME });
    return (await store.get(`enabled_${userId}`, 0) as number) === 1;
  }

  private setStatus(value: DistributedSyncStatus): void {
    this.status = value;
    AppStorage.setOrCreate<string>(AppStorageKeys.DISTRIBUTED_SYNC_STATUS, value);
    console.info(`分布式同步状态: ${value}`);
    for (let index: number = 0; index < this.statusListeners.length; index++) this.statusListeners[index](value);
  }
}

export const DistributedSyncService = new DistributedSyncCoordinator();

class StudyListenerBinding {
  studyListener: DistributedStudyListener = (_snapshot: DistributedStudySnapshot): void => {};
  changeListener: DistributedChangeListener = (_event: DistributedChangeEvent): void => {};
}

class DistributedStudyCompatibilityService {
  private bindings: StudyListenerBinding[] = [];

  async enable(context: common.UIAbilityContext, userId: number): Promise<DistributedSyncStatus> {
    return DistributedSyncService.enable(context, userId);
  }

  async disable(): Promise<void> { await DistributedSyncService.disable(); }

  publish(source: DistributedStudySnapshot): void {
    const snapshot: DistributedStudySnapshot = DistributedStudySnapshotCodec.normalize(source);
    const event = new DistributedChangeEvent();
    event.eventType = DistributedEventType.STUDY_PLAN_UPDATED;
    event.entityType = DistributedEntityType.STUDY_PLAN;
    event.entityId = snapshot.taskId;
    event.routeName = 'StudyPlanPage';
    event.selectedDate = snapshot.selectedDate;
    event.filter = snapshot.filter;
    DistributedSyncService.publish(event);
    const continuation = new ContinuationSnapshot();
    continuation.routeName = 'StudyPlanPage';
    continuation.entityId = snapshot.taskId;
    continuation.selectedDate = snapshot.selectedDate;
    continuation.filter = snapshot.filter;
    continuation.updatedAt = Date.now();
    DistributedSyncService.setContinuation(continuation);
  }

  subscribe(listener: DistributedStudyListener): void {
    const binding = new StudyListenerBinding();
    binding.studyListener = listener;
    binding.changeListener = (event: DistributedChangeEvent): void => {
      const snapshot = new DistributedStudySnapshot();
      snapshot.taskId = event.entityId;
      snapshot.selectedDate = event.selectedDate;
      snapshot.filter = event.filter || 'WEEK';
      snapshot.updatedAt = event.updatedAt;
      listener(snapshot);
    };
    this.bindings.push(binding);
    DistributedSyncService.subscribe(DistributedEntityType.STUDY_PLAN, binding.changeListener);
  }

  unsubscribe(listener: DistributedStudyListener): void {
    for (let index: number = this.bindings.length - 1; index >= 0; index--) {
      const binding: StudyListenerBinding = this.bindings[index];
      if (binding.studyListener === listener) {
        DistributedSyncService.unsubscribe(DistributedEntityType.STUDY_PLAN, binding.changeListener);
        this.bindings.splice(index, 1);
      }
    }
  }

  subscribeStatus(listener: DistributedStatusListener): void { DistributedSyncService.subscribeStatus(listener); }
  unsubscribeStatus(listener: DistributedStatusListener): void { DistributedSyncService.unsubscribeStatus(listener); }
  getStatus(): DistributedSyncStatus { return DistributedSyncService.getStatus(); }

  getLatestSnapshot(): DistributedStudySnapshot {
    const continuation: ContinuationSnapshot = DistributedSyncService.getLatestContinuation();
    const snapshot = new DistributedStudySnapshot();
    if (continuation.routeName === 'StudyPlanPage') {
      snapshot.taskId = continuation.entityId;
      snapshot.selectedDate = continuation.selectedDate;
      snapshot.filter = continuation.filter || 'WEEK';
      snapshot.updatedAt = continuation.updatedAt;
    }
    return snapshot;
  }

  storePendingSnapshot(source: DistributedStudySnapshot, sessionId: string): void {
    const continuation = new ContinuationSnapshot();
    continuation.routeName = 'StudyPlanPage';
    continuation.entityId = source.taskId;
    continuation.selectedDate = source.selectedDate;
    continuation.filter = source.filter;
    continuation.updatedAt = source.updatedAt;
    DistributedSyncService.storePendingContinuation(continuation, sessionId);
  }

  consumePendingSnapshot(userId: number): DistributedStudySnapshot | undefined {
    const continuation: ContinuationSnapshot | undefined = DistributedSyncService.consumePendingContinuation(userId);
    if (continuation === undefined || continuation.routeName !== 'StudyPlanPage') return undefined;
    const snapshot = new DistributedStudySnapshot();
    snapshot.taskId = continuation.entityId;
    snapshot.selectedDate = continuation.selectedDate;
    snapshot.filter = continuation.filter || 'WEEK';
    snapshot.updatedAt = continuation.updatedAt;
    return snapshot;
  }

  clearPendingSnapshot(): void { DistributedSyncService.clearPendingContinuation(); }
}

export const DistributedStudyService = new DistributedStudyCompatibilityService();
