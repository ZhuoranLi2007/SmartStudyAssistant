export enum UserRole {
  PARENT = 'parent',
  STUDENT = 'student'
}

export enum CourseLevel {
  FOUNDATION = '基础巩固型',
  IMPROVEMENT = '中等提升型',
  EXTENSION = '拔高拓展型'
}

export enum TaskStatus {
  NOT_STARTED = '未开始',
  IN_PROGRESS = '学习中',
  COMPLETED = '已完成'
}

export enum ChatRole {
  USER = 'user',
  ASSISTANT = 'assistant'
}

export interface UserInfo {
  id: number;
  username: string;
  phone: string;
  role: string;
}

export interface StudentProfile {
  id: number;
  name: string;
  grade: string;
  subject: string;
  recentScore: number;
  weakPoints: string[];
  learningGoal: string;
  weeklyStudyMinutes: number;
  bindCode: string;
}

export interface Course {
  id: number;
  name: string;
  grade: string;
  subject: string;
  level: string;
  difficulty: string;
  suitableFor: string;
  knowledgePoints: string[];
  description: string;
}

export interface Paper {
  id: number;
  name: string;
  grade: string;
  subject: string;
  difficulty: string;
  knowledgePoints: string[];
  questionCount: number;
  suitableCourseLevel: string;
  ocrText: string;
}

export interface StudyTask {
  id: number;
  name: string;
  taskType: string;
  subject: string;
  difficulty: string;
  createDate: string;
  status: string;
}

export interface ChatMessage {
  id: string;
  role: string;
  content: string;
  createTime: string;
}

export interface RecommendationResult {
  level: string;
  reason: string;
  courseIds: number[];
  paperIds: number[];
}

export interface LoginResult {
  accessToken: string;
  user: UserInfo;
  studentProfileId: number;
}

export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
  requestId: string;
}
