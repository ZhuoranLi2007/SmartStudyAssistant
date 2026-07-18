import { Course, RecommendationResult } from '../model/DomainModels';
import { HttpClient } from './HttpClient';
import { RecommendationRequest } from './NetworkDtos';

export class CourseService {
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
