import {
  DistributedChangeEvent,
  DistributedChangeListener,
  DistributedEventType,
  DistributedStatusListener,
  DistributedSyncStatus
} from '../model/DistributedStudyModels';
import { DistributedSyncService } from './DistributedStudyService';

export enum PageRefreshResult {
  SUCCESS = 'SUCCESS',
  BUSY = 'BUSY',
  FAILED = 'FAILED'
}

// Existing pages may return void when they call markFresh after a successful request.
export type PageRefreshCallback = () => Promise<PageRefreshResult | void>;

class PageRefreshSubscription {
  pageKey: string = '';
  eventTypes: string[] = [];
  callback: PageRefreshCallback = async (): Promise<PageRefreshResult> => PageRefreshResult.SUCCESS;
  refreshing: boolean = false;
  busySince: number = 0;
  failureCount: number = 0;
}

class RefreshCoordinator {
  private initialized: boolean = false;
  private subscriptions: PageRefreshSubscription[] = [];
  private eventVersions: Map<string, number> = new Map<string, number>();
  private pageVersions: Map<string, number> = new Map<string, number>();
  private timers: Map<string, number> = new Map<string, number>();
  private activeTargets: Map<string, number> = new Map<string, number>();
  private readonly eventListener: DistributedChangeListener = (event: DistributedChangeEvent): void => {
    this.eventVersions.set(event.eventType, event.updatedAt);
    for (let index: number = 0; index < this.subscriptions.length; index++) {
      const subscription: PageRefreshSubscription = this.subscriptions[index];
      if (subscription.eventTypes.indexOf(event.eventType) >= 0) this.schedule(subscription, 500);
    }
  };
  private readonly statusListener: DistributedStatusListener = (status: DistributedSyncStatus): void => {
    if (status === DistributedSyncStatus.CONNECTED) this.invalidateAll();
  };

  initialize(): void {
    if (this.initialized) return;
    this.initialized = true;
    DistributedSyncService.subscribeAll(this.eventListener);
    DistributedSyncService.subscribeStatus(this.statusListener);
  }

  register(pageKey: string, eventTypes: DistributedEventType[], callback: PageRefreshCallback): void {
    this.unregister(pageKey);
    const subscription = new PageRefreshSubscription();
    subscription.pageKey = pageKey;
    subscription.eventTypes = eventTypes;
    subscription.callback = callback;
    this.subscriptions.push(subscription);
    if (this.isStale(subscription)) this.schedule(subscription, 500);
  }

  unregister(pageKey: string): void {
    this.subscriptions = this.subscriptions.filter((item: PageRefreshSubscription) => item.pageKey !== pageKey);
    const timer: number | undefined = this.timers.get(pageKey);
    if (timer !== undefined) clearTimeout(timer);
    this.timers.delete(pageKey);
    this.activeTargets.delete(pageKey);
  }

  markFresh(pageKey: string): void {
    const subscription: PageRefreshSubscription | undefined = this.findSubscription(pageKey);
    const activeTarget: number | undefined = this.activeTargets.get(pageKey);
    const version: number = activeTarget !== undefined ? activeTarget :
      (subscription === undefined ? this.latestVersion() : this.relevantVersion(subscription));
    this.pageVersions.set(pageKey, version);
  }

  invalidateAll(): void {
    const version: number = Date.now();
    this.eventVersions.set('*', version);
    console.info(`分布式页面刷新：设备恢复连接，标记 ${this.subscriptions.length} 个前台页面为过期`);
    for (let index: number = 0; index < this.subscriptions.length; index++) {
      this.schedule(this.subscriptions[index], 500);
    }
  }

  private isStale(subscription: PageRefreshSubscription): boolean {
    return this.relevantVersion(subscription) > (this.pageVersions.get(subscription.pageKey) || 0);
  }

  private schedule(subscription: PageRefreshSubscription, delayMs: number): void {
    const oldTimer: number | undefined = this.timers.get(subscription.pageKey);
    if (oldTimer !== undefined) clearTimeout(oldTimer);
    const timer: number = setTimeout(() => { void this.refresh(subscription); }, delayMs);
    this.timers.set(subscription.pageKey, timer);
  }

  private async refresh(subscription: PageRefreshSubscription): Promise<void> {
    this.timers.delete(subscription.pageKey);
    if (this.findSubscription(subscription.pageKey) !== subscription || !this.isStale(subscription)) return;
    if (subscription.refreshing) {
      this.schedule(subscription, 300);
      return;
    }
    const targetVersion: number = this.relevantVersion(subscription);
    subscription.refreshing = true;
    this.activeTargets.set(subscription.pageKey, targetVersion);
    console.info(`分布式页面刷新开始: page=${subscription.pageKey}, version=${targetVersion}`);
    try {
      const callbackResult: PageRefreshResult | void = await subscription.callback();
      let result: PageRefreshResult = PageRefreshResult.BUSY;
      if (callbackResult === PageRefreshResult.SUCCESS) {
        result = PageRefreshResult.SUCCESS;
      } else if (callbackResult === PageRefreshResult.FAILED) {
        result = PageRefreshResult.FAILED;
      } else if (callbackResult === PageRefreshResult.BUSY) {
        result = PageRefreshResult.BUSY;
      } else if (this.hasApplied(subscription.pageKey, targetVersion)) {
        result = PageRefreshResult.SUCCESS;
      }
      if (result === PageRefreshResult.SUCCESS) {
        this.pageVersions.set(subscription.pageKey, targetVersion);
        subscription.busySince = 0;
        subscription.failureCount = 0;
        console.info(`分布式页面刷新成功: page=${subscription.pageKey}, version=${targetVersion}`);
      } else if (result === PageRefreshResult.BUSY) {
        this.handleBusy(subscription);
      } else {
        this.retryFailure(subscription);
      }
    } catch (error) {
      console.warn(`跨设备页面刷新失败: page=${subscription.pageKey}: ${JSON.stringify(error)}`);
      this.retryFailure(subscription);
    } finally {
      subscription.refreshing = false;
      this.activeTargets.delete(subscription.pageKey);
      if (this.isStale(subscription) && !this.timers.has(subscription.pageKey) &&
        subscription.failureCount === 0 && subscription.busySince === 0) {
        this.schedule(subscription, 300);
      }
    }
  }

  private handleBusy(subscription: PageRefreshSubscription): void {
    const now: number = Date.now();
    if (subscription.busySince === 0) subscription.busySince = now;
    if (now - subscription.busySince < 10000) {
      console.info(`分布式页面正忙，稍后补刷新: page=${subscription.pageKey}`);
      this.schedule(subscription, 300);
    } else {
      console.warn(`分布式页面忙碌超过10秒，保留过期状态: page=${subscription.pageKey}`);
    }
  }

  private retryFailure(subscription: PageRefreshSubscription): void {
    subscription.busySince = 0;
    subscription.failureCount++;
    if (subscription.failureCount <= 2) {
      const delayMs: number = subscription.failureCount === 1 ? 1000 : 3000;
      console.warn(`分布式页面刷新将在 ${delayMs}ms 后重试: page=${subscription.pageKey}`);
      this.schedule(subscription, delayMs);
    } else {
      console.warn(`分布式页面刷新重试结束，保留过期状态: page=${subscription.pageKey}`);
    }
  }

  private hasApplied(pageKey: string, targetVersion: number): boolean {
    return (this.pageVersions.get(pageKey) || 0) >= targetVersion;
  }

  private findSubscription(pageKey: string): PageRefreshSubscription | undefined {
    for (let index: number = 0; index < this.subscriptions.length; index++) {
      if (this.subscriptions[index].pageKey === pageKey) return this.subscriptions[index];
    }
    return undefined;
  }

  private relevantVersion(subscription: PageRefreshSubscription): number {
    let result: number = this.eventVersions.get('*') || 0;
    for (let index: number = 0; index < subscription.eventTypes.length; index++) {
      const version: number = this.eventVersions.get(subscription.eventTypes[index]) || 0;
      if (version > result) result = version;
    }
    return result;
  }

  private latestVersion(): number {
    let result: number = 0;
    this.eventVersions.forEach((value: number): void => { if (value > result) result = value; });
    return result;
  }
}

export const PageRefreshCoordinator = new RefreshCoordinator();
