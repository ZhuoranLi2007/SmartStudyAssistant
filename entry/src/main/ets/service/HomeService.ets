import { AppConfig } from '../common/AppConfig';
import { MockHomeData } from '../data/MockHomeData';
import { HomeData, HomeDataSource, HomeLoadResult } from '../model/HomeModels';
import { HttpClient } from './HttpClient';

export class HomeService {
  static async getHomeData(studentProfileId: number): Promise<HomeLoadResult> {
    if (AppConfig.USE_MOCK_DATA) {
      return { data: MockHomeData.getHomeData(), source: HomeDataSource.MOCK, message: '当前首页内容为演示数据' };
    }
    try {
      const path: string = studentProfileId > 0 ? `/home?student_profile_id=${studentProfileId}` : '/home';
      const data: HomeData = (await HttpClient.get<HomeData>(path)).data;
      if (!data || !data.banners || !data.popularCourses || !data.recommendedPapers) {
        throw new Error('首页接口数据结构无效');
      }
      return { data: data, source: HomeDataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`首页接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return { data: MockHomeData.getHomeData(), source: HomeDataSource.MOCK, message: '网络服务暂不可用，已展示本地演示内容' };
    }
  }
}
