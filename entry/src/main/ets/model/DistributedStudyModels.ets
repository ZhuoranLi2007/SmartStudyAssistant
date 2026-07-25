export enum DistributedSyncStatus {
  DISABLED = 'DISABLED',
  WAITING_PERMISSION = 'WAITING_PERMISSION',
  WAITING_DEVICE = 'WAITING_DEVICE',
  CONNECTED = 'CONNECTED',
  UNSUPPORTED = 'UNSUPPORTED',
  PERMISSION_DENIED = 'PERMISSION_DENIED',
  ERROR = 'ERROR'
}

export class DistributedStudySnapshot {
  schemaVersion: number = 1;
  routeName: string = '';
  taskId: number = 0;
  taskStatus: string = '';
  selectedDate: string = '';
  filter: string = '';
  updatedAt: number = 0;
}

export type DistributedStudyListener = (snapshot: DistributedStudySnapshot) => void;
export type DistributedStatusListener = (status: DistributedSyncStatus) => void;

export class DistributedStudySnapshotCodec {
  static readonly SCHEMA_VERSION: number = 1;

  static sessionIdForUser(userId: number): string {
    const safeUserId: number = Math.max(0, Math.floor(userId));
    return `smartstudy_user_${safeUserId}`;
  }

  static normalize(source: DistributedStudySnapshot): DistributedStudySnapshot {
    const snapshot = new DistributedStudySnapshot();
    snapshot.schemaVersion = Number.isInteger(source.schemaVersion) ? source.schemaVersion : 0;
    snapshot.routeName = source.routeName === 'StudyPlanPage' ? source.routeName : '';
    snapshot.taskId = Math.max(0, Math.floor(source.taskId));
    snapshot.taskStatus = DistributedStudySnapshotCodec.normalizeTaskStatus(source.taskStatus);
    snapshot.selectedDate = DistributedStudySnapshotCodec.normalizeDate(source.selectedDate);
    snapshot.filter = DistributedStudySnapshotCodec.normalizeFilter(source.filter);
    snapshot.updatedAt = Math.max(0, Math.floor(source.updatedAt));
    return snapshot;
  }

  static isUsable(source: DistributedStudySnapshot): boolean {
    return source.schemaVersion === DistributedStudySnapshotCodec.SCHEMA_VERSION &&
      source.routeName === 'StudyPlanPage' &&
      source.updatedAt > 0;
  }

  private static normalizeTaskStatus(value: string): string {
    if (value === '未开始' || value === '学习中' || value === '已完成') return value;
    return '';
  }

  private static normalizeFilter(value: string): string {
    if (value === 'TODAY' || value === 'WEEK' || value === 'COMPLETED') return value;
    return 'WEEK';
  }

  private static normalizeDate(value: string): string {
    if (value.length !== 10 || value.charAt(4) !== '-' || value.charAt(7) !== '-') return '';
    const year: number = Number(value.substring(0, 4));
    const month: number = Number(value.substring(5, 7));
    const day: number = Number(value.substring(8, 10));
    if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) return '';
    if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) return '';
    return value;
  }
}
