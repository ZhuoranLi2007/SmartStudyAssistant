import { Course, RecommendationResult } from '../model/DomainModels';
import { HttpClient } from './HttpClient';
import { RecommendationRequest } from './NetworkDtos';
import { AppConfig } from '../common/AppConfig';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, MyCourse } from '../model/ProfileModels';

interface EnrollResult {
  enrolled: boolean;
  created: boolean;
  courseId: number;
  enrollmentId: number;
  name: string;
}

interface EnrolledCheck {
  enrolled: boolean;
  enrollmentId: number;
}

export class CourseService {
  private static studentId(): number {
    return AppStorage.get<number>(AppStorageKeys.STUDENT_PROFILE_ID) || 0;
  }

  static async getMyCourses(): Promise<DataLoadResult<MyCourse[]>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<MyCourse[]>(ProfileMockData.getCourses());
    try {
      const studentId: number = CourseService.studentId();
      const path: string = studentId > 0 ? `/courses/my?student_profile_id=${studentId}` : '/courses/my';
      const data: MyCourse[] = (await HttpClient.get<MyCourse[]>(path)).data;
      return { data: data || [], source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`我的课程接口不可用: ${JSON.stringify(error)}`);
      return { data: [], source: DataSource.LIVE, message: '课程加载失败' };
    }
  }

  static async getCourses(query: string = ''): Promise<Course[]> {
    return (await HttpClient.get<Course[]>(`/courses${query}`)).data;
  }

  static async getCourse(id: number): Promise<Course> {
    return (await HttpClient.get<Course>(`/courses/${id}`)).data;
  }

  static async isEnrolled(courseId: number): Promise<boolean> {
    const studentId: number = CourseService.studentId();
    if (AppConfig.USE_MOCK_DATA || studentId <= 0) return false;
    try {
      const data: EnrolledCheck = (await HttpClient.get<EnrolledCheck>(
        `/courses/${courseId}/enrolled?student_profile_id=${studentId}`
      )).data;
      return data.enrolled;
    } catch (error) {
      return false;
    }
  }

  static async enroll(courseId: number): Promise<EnrollResult> {
    const studentId: number = CourseService.studentId();
    if (studentId <= 0) throw new Error('请先创建或绑定学生档案');
    return (await HttpClient.post<EnrollResult>(
      `/courses/${courseId}/enroll?student_profile_id=${studentId}`,
      new Object()
    )).data;
  }

  static async complete(courseId: number): Promise<void> {
    const studentId: number = CourseService.studentId();
    if (studentId <= 0) throw new Error('请先创建或绑定学生档案');
    if (AppConfig.USE_MOCK_DATA) {
      ProfileMockData.completeCourse(courseId);
      return;
    }
    await HttpClient.post<Object>(
      `/courses/${courseId}/complete?student_profile_id=${studentId}`,
      new Object()
    );
  }

  static async recommend(studentProfileId: number, subject: string): Promise<RecommendationResult> {
    const request = new RecommendationRequest();
    request.student_profile_id = studentProfileId;
    request.subject = subject;
    return (await HttpClient.post<RecommendationResult>('/courses/recommend', request)).data;
  }
}
