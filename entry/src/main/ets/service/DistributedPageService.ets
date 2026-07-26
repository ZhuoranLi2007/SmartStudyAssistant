import {
  ContinuationSnapshot,
  DistributedEntityType,
  DistributedEventType
} from '../model/DistributedStudyModels';
import { DistributedSyncService } from './DistributedStudyService';
import { PageRefreshCallback, PageRefreshCoordinator } from './PageRefreshCoordinator';

export class DistributedPageService {
  static activate(
    pageKey: string,
    eventTypes: DistributedEventType[],
    callback: PageRefreshCallback,
    continuation: ContinuationSnapshot
  ): void {
    PageRefreshCoordinator.initialize();
    PageRefreshCoordinator.register(pageKey, eventTypes, callback);
    continuation.updatedAt = Date.now();
    DistributedSyncService.setContinuation(continuation);
  }

  static deactivate(pageKey: string): void { PageRefreshCoordinator.unregister(pageKey); }

  static markFresh(pageKey: string): void { PageRefreshCoordinator.markFresh(pageKey); }

  static updateContinuation(continuation: ContinuationSnapshot): void {
    continuation.updatedAt = Date.now();
    DistributedSyncService.setContinuation(continuation);
  }

  static publish(
    eventType: DistributedEventType,
    entityType: DistributedEntityType,
    entityId: number = 0,
    entityKey: string = '',
    parentEntityId: number = 0,
    routeName: string = ''
  ): void {
    DistributedSyncService.publishChange(eventType, entityType, entityId, entityKey, parentEntityId, routeName);
  }
}
