export enum HomeDataSource {
  LIVE = 'LIVE',
  MOCK = 'MOCK'
}

export interface HomeBanner {
  id: number;
  title: string;
  subtitle: string;
  actionText: string;
  routeName: string;
  imageKey: string;
}

export interface HomeOverview {
  studentBound: boolean;
  studentName: string;
  grade: string;
  subject: string;
  recentScore: number;
  weakPoints: string[];
  totalTasks: number;
  completedTasks: number;
}

export interface HomeCourseItem {
  id: number;
  name: string;
  grade: string;
  subject: string;
  difficulty: string;
  courseType: string;
  priceText: string;
  imageKey: string;
  recommendReason: string;
}

export interface HomePaperItem {
  id: number;
  name: string;
  grade: string;
  subject: string;
  difficulty: string;
  questionCount: number;
  imageKey: string;
}

export interface TodayTaskSummary {
  totalCount: number;
  completedCount: number;
  nextTask: string;
}

export interface HomeData {
  studentProfileId: number;
  banners: HomeBanner[];
  overview: HomeOverview;
  recommendedCourse: HomeCourseItem;
  popularCourses: HomeCourseItem[];
  latestCourses: HomeCourseItem[];
  recommendedPapers: HomePaperItem[];
  todayTask: TodayTaskSummary;
}

export interface PracticeOption {
  label: string;
  content: string;
}

export interface PracticeQuestion {
  id: number;
  stem: string;
  options: PracticeOption[];
  correctIndex: number;
  explanation: string;
  knowledgePoint?: string;
  subject?: string;
}

export interface HomeLoadResult {
  data: HomeData;
  source: HomeDataSource;
  message: string;
}
