import { AppConfig } from '../common/AppConfig';
import { CourseDetailMockData } from '../data/CourseDetailMockData';
import { CourseDetailData } from '../model/CourseDetailModels';
import { Course } from '../model/DomainModels';
import { DataLoadResult, DataSource } from '../model/ProfileModels';
import { CourseService } from './CourseService';
import { MockDataService } from './MockDataService';

export class CourseDetailService {
  static localCourse(courseId: number): Course | null {
    const courses: Course[] = MockDataService.getCourses();
    for (let index: number = 0; index < courses.length; index++) {
      if (courses[index].id === courseId) return courses[index];
    }
    return null;
  }

  static async load(courseId: number): Promise<DataLoadResult<CourseDetailData>> {
    if (AppConfig.USE_MOCK_DATA) {
      const local: Course | null = CourseDetailService.localCourse(courseId);
      if (local === null) throw new Error('课程不存在');
      return { data: CourseDetailMockData.build(local), source: DataSource.MOCK, message: '当前课程详情包含演示数据' };
    }
    try {
      const live: Course = await CourseService.getCourse(courseId);
      return { data: CourseDetailMockData.build(live), source: DataSource.LIVE, message: '' };
    } catch (error) {
      const local: Course | null = CourseDetailService.localCourse(courseId);
      if (local === null) throw new Error(`课程加载失败：${error}`);
      console.warn(`课程详情接口不可用，使用本地数据: ${JSON.stringify(error)}`);
      return {
        data: CourseDetailMockData.build(local),
        source: DataSource.MOCK,
        message: '网络服务暂不可用，当前展示本地课程详情'
      };
    }
  }
}
