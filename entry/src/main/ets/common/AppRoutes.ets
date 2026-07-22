export class AppRoutes {
  static readonly LOGIN: string = 'LoginPage';
  static readonly REGISTER: string = 'RegisterPage';
  static readonly HOME: string = 'HomePage';
  static readonly STUDENT_PROFILE: string = 'StudentProfilePage';
  static readonly AI_ASSISTANT: string = 'AiAssistantPage';
  static readonly COURSES: string = 'CourseRecommendationPage';
  static readonly COURSE_DETAIL: string = 'CourseDetailPage';
  static readonly PAPERS: string = 'PaperResourcePage';
  static readonly PAPER_DETAIL: string = 'PaperDetailPage';
  static readonly STUDY_PLAN: string = 'StudyPlanPage';
  static readonly PROFILE: string = 'ProfilePage';
  static readonly MY_COURSES: string = 'MyCoursesPage';
  static readonly MY_FAVORITES: string = 'MyFavoritesPage';
  static readonly CUSTOMER_SERVICE: string = 'CustomerServicePage';
  static readonly SETTINGS: string = 'SettingsPage';
  static readonly WRONG_QUESTIONS: string = 'WrongQuestionsPage';
  static readonly LEARNING_REPORT: string = 'LearningReportPage';
  static readonly CUSTOMER_CHAT: string = 'CustomerChatPage';
  static readonly FEEDBACK: string = 'FeedbackPage';
  static readonly PLATFORM_INFO: string = 'PlatformInfoPage';
  static readonly ONLINE_PRACTICE: string = 'OnlinePracticePage';
  static readonly WRONG_QUESTION_TRAINING: string = 'WrongQuestionTrainingPage';
  static readonly SEARCH_RESULT: string = 'SearchResultPage';
}

export class IdRouteParam {
  id: number = 0;
}

export class SearchRouteParam {
  keyword: string = '';
}

export class StudentRouteParam {
  studentProfileId: number = 0;
  sessionId: string = '';
}

export class ProfileSetupRouteParam {
  requireSetup: boolean = false;
}

export class PlatformInfoRouteParam {
  type: string = 'ABOUT';
}

export class OnlinePracticeRouteParam {
  paperId: number = 0;
  taskId: number = 0;
}

export class WrongQuestionTrainingRouteParam {
  wrongQuestionId: number = 0;
  taskId: number = 0;
}
