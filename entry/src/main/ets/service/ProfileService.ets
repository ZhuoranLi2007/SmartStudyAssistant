import { AppConfig } from '../common/AppConfig';
import { AppStorageKeys } from '../common/AppStorageKeys';
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
      const data: ProfileOverview | null = (await HttpClient.get<ProfileOverview | null>('/families/current')).data;
      if (!data || !data.learning) {
        return {
          data: {
            familyCode: '',
            studentBindCode: '',
            studentName: '',
            studentBound: false,
            studentProfileId: 0,
            learning: { courseCount: 0, weeklyTaskCount: 0, favoriteCount: 0, wrongQuestionCount: 0 }
          },
          source: DataSource.LIVE,
          message: '尚未加入家庭'
        };
      }
      if (data.studentProfileId > 0) {
        AppStorage.setOrCreate(AppStorageKeys.STUDENT_PROFILE_ID, data.studentProfileId);
      }
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
