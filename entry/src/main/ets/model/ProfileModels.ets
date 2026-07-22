export enum OrderStatus {
  PENDING = 'PENDING',
  PAID = 'PAID',
  CANCELLED = 'CANCELLED'
}

export enum OrderFilter {
  ALL = 'ALL',
  PENDING = 'PENDING',
  PAID = 'PAID',
  CANCELLED = 'CANCELLED'
}

export enum FavoriteType {
  COURSE = 'COURSE',
  PAPER = 'PAPER',
  KNOWLEDGE = 'KNOWLEDGE'
}

export enum DataSource {
  LIVE = 'LIVE',
  LOCAL = 'LOCAL',
  MOCK = 'MOCK'
}

export interface DataLoadResult<T> {
  data: T;
  source: DataSource;
  message: string;
}

export interface LearningOverview {
  courseCount: number;
  weeklyTaskCount: number;
  favoriteCount: number;
  wrongQuestionCount: number;
}

export interface ProfileOverview {
  familyCode: string;
  studentBindCode: string;
  studentName: string;
  studentBound: boolean;
  studentProfileId: number;
  learning: LearningOverview;
}

export interface CourseProgress {
  completedLessons: number;
  totalLessons: number;
  progress: number;
  nextLesson: string;
}

export interface MyCourse {
  id: number;
  courseId: number;
  name: string;
  grade: string;
  subject: string;
  completed: boolean;
  progress: CourseProgress;
}

export interface CourseOrder {
  id: number;
  orderNo: string;
  courseId: number;
  courseName: string;
  amount: number;
  createTime: string;
  status: OrderStatus;
}

export interface FavoriteItem {
  id: number;
  favoriteId: number;
  targetId: number;
  type: FavoriteType;
  title: string;
  subtitle: string;
  tag: string;
  grade: string;
  subject: string;
  level: string;
  coverKey: string;
  createdAt: string;
}

export interface WrongQuestion {
  id: number;
  questionNo: number;
  subject: string;
  knowledgePoint: string;
  question: string;
  userAnswer: string;
  correctAnswer: string;
  explanation: string;
  mastered: boolean;
  wrongCount: number;
}

export interface LearningReport {
  completedCourseCount: number;
  completedPaperCount: number;
  averageAccuracy: number;
  taskCompletionRate: number;
  improvedPoints: string[];
  weakPoints: string[];
  aiSuggestion: string;
}

export interface FaqItem {
  id: number;
  question: string;
  answer: string;
}

export interface CustomerMessage {
  id: string;
  fromUser: boolean;
  content: string;
  createTime: string;
}

export interface QuickFunctionItem {
  title: string;
  iconText: string;
  routeName: string;
}
