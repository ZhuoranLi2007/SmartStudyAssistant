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
}

export class IdRouteParam {
  id: number = 0;
}

export class StudentRouteParam {
  studentProfileId: number = 1;
  sessionId: string = '';
}
