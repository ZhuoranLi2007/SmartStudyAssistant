import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { AiAssistantPage } from './AiAssistantPage';
import { CourseDetailPage } from './CourseDetailPage';
import { CourseRecommendationPage } from './CourseRecommendationPage';
import { HomePage } from './HomePage';
import { LoginPage } from './LoginPage';
import { PaperDetailPage } from './PaperDetailPage';
import { PaperResourcePage } from './PaperResourcePage';
import { ProfilePage } from './ProfilePage';
import { RegisterPage } from './RegisterPage';
import { StudentProfilePage } from './StudentProfilePage';
import { StudyPlanPage } from './StudyPlanPage';

@Builder
export function PageMap(name: string, param: Object) {
  if (name === AppRoutes.LOGIN) {
    LoginPage()
  } else if (name === AppRoutes.REGISTER) {
    RegisterPage()
  } else if (name === AppRoutes.HOME) {
    HomePage()
  } else if (name === AppRoutes.STUDENT_PROFILE) {
    StudentProfilePage()
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
  }
}
