import { Course, RecommendationResult } from '../model/DomainModels';
import { HttpClient } from './HttpClient';
import { RecommendationRequest } from './NetworkDtos';
import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, MyCourse } from '../model/ProfileModels';

export class CourseService {
  static async getMyCourses(): Promise<DataLoadResult<MyCourse[]>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<MyCourse[]>(ProfileMockData.getCourses());
    try {
      const data: MyCourse[] = (await HttpClient.get<MyCourse[]>('/courses/my')).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`我的课程接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return ProfileMockData.mockResult<MyCourse[]>(ProfileMockData.getCourses());
    }
  }

  static async getCourses(query: string = ''): Promise<Course[]> {
    return (await HttpClient.get<Course[]>(`/courses${query}`)).data;
  }

  static async getCourse(id: number): Promise<Course> {
    return (await HttpClient.get<Course>(`/courses/${id}`)).data;
  }

  static async recommend(studentProfileId: number, subject: string): Promise<RecommendationResult> {
    const request = new RecommendationRequest();
    request.student_profile_id = studentProfileId;
    request.subject = subject;
    return (await HttpClient.post<RecommendationResult>('/courses/recommend', request)).data;
  }
}
