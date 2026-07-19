import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, ProfileOverview } from '../model/ProfileModels';
import { HttpClient } from './HttpClient';

class BindStudentRequest {
  bind_code: string = '';
}

interface BindStudentResult {
  studentProfileId: number;
  familyId: number;
}

export class ProfileService {
  static async getOverview(): Promise<DataLoadResult<ProfileOverview>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<ProfileOverview>(ProfileMockData.getOverview());
    try {
      const data: ProfileOverview = (await HttpClient.get<ProfileOverview>('/families/current')).data;
      if (!data || !data.learning) throw new Error('家庭接口数据结构尚未适配个人中心');
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`个人中心接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return ProfileMockData.mockResult<ProfileOverview>(ProfileMockData.getOverview());
    }
  }

  static async bindStudent(bindCode: string): Promise<number> {
    if (!AppConfig.USE_MOCK_DATA) {
      try {
        const request = new BindStudentRequest();
        request.bind_code = bindCode;
        const result: BindStudentResult = (await HttpClient.post<BindStudentResult>('/families/bind-student', request)).data;
        return result.studentProfileId;
      } catch (error) {
        console.warn(`学生绑定接口不可用，使用演示绑定: ${JSON.stringify(error)}`);
      }
    }
    return 1;
  }
}
