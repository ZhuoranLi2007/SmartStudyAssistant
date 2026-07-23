import { AppRoutes, IdRouteParam, OnlinePracticeRouteParam, PlatformInfoRouteParam, ProfileSetupRouteParam, SearchRouteParam, WrongQuestionTrainingRouteParam } from '../common/AppRoutes';
import { AiAssistantPage } from './AiAssistantPage';
import { CourseDetailPage } from './CourseDetailPage';
import { CourseRecommendationPage } from './CourseRecommendationPage';
import { HomePage } from './HomePage';
import { LoginPage } from './LoginPage';
import { PaperDetailPage } from './PaperDetailPage';
import { PaperResourcePage } from './PaperResourcePage';
import { ProfilePage } from './ProfilePage';
import { RegisterPage } from './RegisterPage';
import { SearchResultPage } from './SearchResultPage';
import { StudentProfilePage } from './StudentProfilePage';
import { GeneratePaperPage } from './GeneratePaperPage';
import { MyPapersPage } from './MyPapersPage';
import { StudyPlanPage } from './StudyPlanPage';
import { CustomerChatPage } from './CustomerChatPage';
import { CustomerServicePage } from './CustomerServicePage';
import { FeedbackPage } from './FeedbackPage';
import { LearningReportPage } from './LearningReportPage';
import { MyCoursesPage } from './MyCoursesPage';
import { MyFavoritesPage } from './MyFavoritesPage';
import { PlatformInfoPage } from './PlatformInfoPage';
import { SettingsPage } from './SettingsPage';
import { WrongQuestionsPage } from './WrongQuestionsPage';
import { OnlinePracticePage } from './OnlinePracticePage';
import { WrongQuestionTrainingPage } from './WrongQuestionTrainingPage';

function infoTypeFromParam(param: Object): string {
  if (param instanceof PlatformInfoRouteParam) return param.type;
  return 'ABOUT';
}

function requireSetupFromParam(param: Object): boolean {
  if (param instanceof ProfileSetupRouteParam) return param.requireSetup;
  return false;
}

function paperIdFromPracticeParam(param: Object): number {
  if (param instanceof OnlinePracticeRouteParam) return param.paperId;
  return 0;
}

function taskIdFromPracticeParam(param: Object): number {
  if (param instanceof OnlinePracticeRouteParam) return param.taskId;
  return 0;
}

function wrongQuestionIdFromParam(param: Object): number {
  if (param instanceof WrongQuestionTrainingRouteParam) return param.wrongQuestionId;
  return 0;
}

function wrongQuestionTaskIdFromParam(param: Object): number {
  if (param instanceof WrongQuestionTrainingRouteParam) return param.taskId;
  return 0;
}

function keywordFromSearchParam(param: Object): string {
  if (param instanceof SearchRouteParam) return param.keyword;
  return '';
}

@Builder
export function PageMap(name: string, param: Object) {
  if (name === AppRoutes.LOGIN) {
    LoginPage()
  } else if (name === AppRoutes.REGISTER) {
    RegisterPage()
  } else if (name === AppRoutes.HOME) {
    HomePage()
  } else if (name === AppRoutes.STUDENT_PROFILE) {
    StudentProfilePage({ requireSetup: requireSetupFromParam(param) })
  } else if (name === AppRoutes.AI_ASSISTANT) {
    AiAssistantPage()
  } else if (name === AppRoutes.COURSES) {
    CourseRecommendationPage()
  } else if (name === AppRoutes.COURSE_DETAIL) {
    CourseDetailPage({ courseId: (param as IdRouteParam).id })
  } else if (name === AppRoutes.PAPERS) {
    PaperResourcePage()
  } else if (name === AppRoutes.PAPER_DETAIL) {
    PaperDetailPage({ paperId: (param as IdRouteParam).id })
  } else if (name === AppRoutes.STUDY_PLAN) {
    StudyPlanPage()
  } else if (name === AppRoutes.PROFILE) {
    ProfilePage()
  } else if (name === AppRoutes.MY_COURSES) {
    MyCoursesPage()
  } else if (name === AppRoutes.MY_FAVORITES) {
    MyFavoritesPage()
  } else if (name === AppRoutes.CUSTOMER_SERVICE) {
    CustomerServicePage()
  } else if (name === AppRoutes.SETTINGS) {
    SettingsPage()
  } else if (name === AppRoutes.WRONG_QUESTIONS) {
    WrongQuestionsPage()
  } else if (name === AppRoutes.LEARNING_REPORT) {
    LearningReportPage()
  } else if (name === AppRoutes.CUSTOMER_CHAT) {
    CustomerChatPage()
  } else if (name === AppRoutes.FEEDBACK) {
    FeedbackPage()
  } else if (name === AppRoutes.PLATFORM_INFO) {
    PlatformInfoPage({ infoType: infoTypeFromParam(param) })
  } else if (name === AppRoutes.ONLINE_PRACTICE) {
    OnlinePracticePage({ paperId: paperIdFromPracticeParam(param), taskId: taskIdFromPracticeParam(param) })
  } else if (name === AppRoutes.WRONG_QUESTION_TRAINING) {
    WrongQuestionTrainingPage({
      wrongQuestionId: wrongQuestionIdFromParam(param),
      taskId: wrongQuestionTaskIdFromParam(param)
    })
  } else if (name === AppRoutes.SEARCH_RESULT) {
    SearchResultPage({ keyword: keywordFromSearchParam(param) })
  } else if (name === AppRoutes.GENERATE_PAPER) {
    GeneratePaperPage()
  } else if (name === AppRoutes.MY_PAPERS) {
    MyPapersPage()
  }
}
