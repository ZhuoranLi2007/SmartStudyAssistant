export enum DistributedSyncStatus {
  DISABLED = 'DISABLED',
  WAITING_PERMISSION = 'WAITING_PERMISSION',
  WAITING_DEVICE = 'WAITING_DEVICE',
  CONNECTED = 'CONNECTED',
  UNSUPPORTED = 'UNSUPPORTED',
  PERMISSION_DENIED = 'PERMISSION_DENIED',
  ERROR = 'ERROR'
}

export enum DistributedEntityType {
  AUTH = 'AUTH',
  HOME = 'HOME',
  STUDENT = 'STUDENT',
  COURSE = 'COURSE',
  PAPER = 'PAPER',
  WRONG_QUESTION = 'WRONG_QUESTION',
  STUDY_PLAN = 'STUDY_PLAN',
  STUDY_TASK = 'STUDY_TASK',
  STUDY_REPORT = 'STUDY_REPORT',
  AI_CONVERSATION = 'AI_CONVERSATION',
  SEARCH = 'SEARCH'
}

export enum DistributedEventType {
  AUTH_SESSION_CHANGED = 'AUTH_SESSION_CHANGED',
  HOME_OVERVIEW_UPDATED = 'HOME_OVERVIEW_UPDATED',
  STUDENT_PROFILE_UPDATED = 'STUDENT_PROFILE_UPDATED',
  STUDENT_BINDING_UPDATED = 'STUDENT_BINDING_UPDATED',
  COURSE_LIST_UPDATED = 'COURSE_LIST_UPDATED',
  COURSE_DETAIL_UPDATED = 'COURSE_DETAIL_UPDATED',
  COURSE_ENROLLMENT_UPDATED = 'COURSE_ENROLLMENT_UPDATED',
  COURSE_FAVORITE_UPDATED = 'COURSE_FAVORITE_UPDATED',
  COURSE_PROGRESS_UPDATED = 'COURSE_PROGRESS_UPDATED',
  MY_COURSES_UPDATED = 'MY_COURSES_UPDATED',
  PAPER_LIST_UPDATED = 'PAPER_LIST_UPDATED',
  PAPER_DETAIL_UPDATED = 'PAPER_DETAIL_UPDATED',
  PAPER_SUBMISSION_UPDATED = 'PAPER_SUBMISSION_UPDATED',
  AI_PAPER_CREATED = 'AI_PAPER_CREATED',
  AI_PAPER_DELETED = 'AI_PAPER_DELETED',
  AI_PAPER_LIBRARY_UPDATED = 'AI_PAPER_LIBRARY_UPDATED',
  WRONG_QUESTION_CREATED = 'WRONG_QUESTION_CREATED',
  WRONG_QUESTION_UPDATED = 'WRONG_QUESTION_UPDATED',
  WRONG_QUESTION_DELETED = 'WRONG_QUESTION_DELETED',
  WRONG_QUESTION_RETEST_UPDATED = 'WRONG_QUESTION_RETEST_UPDATED',
  STUDY_PLAN_UPDATED = 'STUDY_PLAN_UPDATED',
  STUDY_TASK_CREATED = 'STUDY_TASK_CREATED',
  STUDY_TASK_UPDATED = 'STUDY_TASK_UPDATED',
  STUDY_TASK_DELETED = 'STUDY_TASK_DELETED',
  STUDY_REPORT_UPDATED = 'STUDY_REPORT_UPDATED',
  AI_CONVERSATION_CREATED = 'AI_CONVERSATION_CREATED',
  AI_CONVERSATION_UPDATED = 'AI_CONVERSATION_UPDATED',
  AI_CONVERSATION_DELETED = 'AI_CONVERSATION_DELETED',
  AI_CONVERSATION_CLEARED = 'AI_CONVERSATION_CLEARED',
  AI_CONVERSATION_LIST_UPDATED = 'AI_CONVERSATION_LIST_UPDATED',
  SEARCH_HISTORY_UPDATED = 'SEARCH_HISTORY_UPDATED'
}

export class DistributedChangeEvent {
  schemaVersion: number = 2;
  eventId: string = '';
  eventType: string = '';
  entityType: string = '';
  entityId: number = 0;
  entityKey: string = '';
  parentEntityId: number = 0;
  routeName: string = '';
  sourceDeviceId: string = '';
  userId: number = 0;
  selectedDate: string = '';
  filter: string = '';
  tabIndex: number = 0;
  updatedAt: number = 0;
}

export class ContinuationSnapshot {
  schemaVersion: number = 2;
  routeName: string = '';
  entityId: number = 0;
  entityKey: string = '';
  parentEntityId: number = 0;
  selectedDate: string = '';
  filter: string = '';
  tabIndex: number = 0;
  searchKeyword: string = '';
  updatedAt: number = 0;
}

export type DistributedChangeListener = (event: DistributedChangeEvent) => void;
export type DistributedStatusListener = (status: DistributedSyncStatus) => void;

export class DistributedEventCodec {
  static readonly SCHEMA_VERSION: number = 2;

  static sessionIdForUser(userId: number): string {
    return `smartstudy_user_${Math.max(0, Math.floor(userId))}`;
  }

  static normalize(source: DistributedChangeEvent): DistributedChangeEvent {
    const event = new DistributedChangeEvent();
    event.schemaVersion = Number.isInteger(source.schemaVersion) ? source.schemaVersion : 0;
    event.eventId = DistributedEventCodec.safeText(source.eventId, 120);
    event.eventType = DistributedEventCodec.safeText(source.eventType, 60);
    event.entityType = DistributedEventCodec.safeText(source.entityType, 40);
    event.entityId = Math.max(0, Math.floor(source.entityId));
    event.entityKey = DistributedEventCodec.safeText(source.entityKey, 80);
    event.parentEntityId = Math.max(0, Math.floor(source.parentEntityId));
    event.routeName = DistributedEventCodec.safeText(source.routeName, 60);
    event.sourceDeviceId = DistributedEventCodec.safeText(source.sourceDeviceId, 80);
    event.userId = Math.max(0, Math.floor(source.userId));
    event.selectedDate = DistributedEventCodec.normalizeDate(source.selectedDate);
    event.filter = DistributedEventCodec.safeText(source.filter, 30);
    event.tabIndex = Math.max(0, Math.min(20, Math.floor(source.tabIndex)));
    event.updatedAt = Math.max(0, Math.floor(source.updatedAt));
    return event;
  }

  static isUsable(source: DistributedChangeEvent): boolean {
    return source.schemaVersion === DistributedEventCodec.SCHEMA_VERSION &&
      source.eventId.length > 0 && source.eventType.length > 0 && source.entityType.length > 0 &&
      source.sourceDeviceId.length > 0 && source.userId > 0 && source.updatedAt > 0;
  }

  static entityKey(source: DistributedChangeEvent): string {
    const identity: string = source.entityKey || `${source.entityId}`;
    return `${source.entityType}:${identity}`;
  }

  private static safeText(value: string, maximum: number): string {
    if (!value) return '';
    return value.trim().substring(0, maximum);
  }

  private static normalizeDate(value: string): string {
    if (!value || value.length !== 10 || value.charAt(4) !== '-' || value.charAt(7) !== '-') return '';
    const year: number = Number(value.substring(0, 4));
    const month: number = Number(value.substring(5, 7));
    const day: number = Number(value.substring(8, 10));
    if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) return '';
    if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) return '';
    return value;
  }
}

export class ContinuationSnapshotCodec {
  static readonly SCHEMA_VERSION: number = 2;
  private static readonly ROUTES: string[] = [
    'HomePage', 'StudentProfilePage', 'AiAssistantPage', 'CourseRecommendationPage',
    'CourseDetailPage', 'PaperResourcePage', 'PaperDetailPage', 'StudyPlanPage',
    'ProfilePage', 'MyCoursesPage', 'MyFavoritesPage', 'WrongQuestionsPage',
    'LearningReportPage', 'WrongQuestionTrainingPage', 'SearchResultPage', 'MyPapersPage'
  ];

  static normalize(source: ContinuationSnapshot): ContinuationSnapshot {
    const snapshot = new ContinuationSnapshot();
    snapshot.schemaVersion = Number.isInteger(source.schemaVersion) ? source.schemaVersion : 0;
    snapshot.routeName = ContinuationSnapshotCodec.ROUTES.indexOf(source.routeName) >= 0 ? source.routeName : '';
    snapshot.entityId = Math.max(0, Math.floor(source.entityId));
    snapshot.entityKey = (source.entityKey || '').trim().substring(0, 80);
    snapshot.parentEntityId = Math.max(0, Math.floor(source.parentEntityId));
    const selectedDate = (source.selectedDate || '').trim();
    snapshot.selectedDate = /^\d{4}-\d{2}-\d{2}$/.test(selectedDate) ? selectedDate : '';
    snapshot.filter = (source.filter || '').trim().substring(0, 30);
    snapshot.tabIndex = Math.max(0, Math.min(20, Math.floor(source.tabIndex)));
    snapshot.searchKeyword = (source.searchKeyword || '').trim().substring(0, 80);
    snapshot.updatedAt = Math.max(0, Math.floor(source.updatedAt));
    return snapshot;
  }

  static isUsable(source: ContinuationSnapshot): boolean {
    return source.schemaVersion === ContinuationSnapshotCodec.SCHEMA_VERSION &&
      source.routeName.length > 0 && source.updatedAt > 0;
  }
}

// 兼容原学习计划调用方；真实任务状态仍由目标设备重新请求后端。
export class DistributedStudySnapshot {
  schemaVersion: number = 1;
  routeName: string = 'StudyPlanPage';
  taskId: number = 0;
  taskStatus: string = '';
  selectedDate: string = '';
  filter: string = 'WEEK';
  updatedAt: number = 0;
}

export type DistributedStudyListener = (snapshot: DistributedStudySnapshot) => void;

export class DistributedStudySnapshotCodec {
  static readonly SCHEMA_VERSION: number = 1;

  static sessionIdForUser(userId: number): string {
    return DistributedEventCodec.sessionIdForUser(userId);
  }

  static normalize(source: DistributedStudySnapshot): DistributedStudySnapshot {
    const snapshot = new DistributedStudySnapshot();
    snapshot.routeName = source.routeName === 'StudyPlanPage' ? source.routeName : '';
    snapshot.taskId = Math.max(0, Math.floor(source.taskId));
    snapshot.taskStatus = source.taskStatus === '未开始' || source.taskStatus === '学习中' || source.taskStatus === '已完成' ? source.taskStatus : '';
    const event = new DistributedChangeEvent();
    event.selectedDate = source.selectedDate;
    snapshot.selectedDate = DistributedEventCodec.normalize(event).selectedDate;
    snapshot.filter = source.filter === 'TODAY' || source.filter === 'COMPLETED' ? source.filter : 'WEEK';
    snapshot.updatedAt = Math.max(0, Math.floor(source.updatedAt));
    return snapshot;
  }

  static isUsable(source: DistributedStudySnapshot): boolean {
    return source.routeName === 'StudyPlanPage' && source.updatedAt > 0;
  }
}
