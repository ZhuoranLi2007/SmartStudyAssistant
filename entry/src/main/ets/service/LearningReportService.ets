import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, LearningReport } from '../model/ProfileModels';
import { HttpClient } from './HttpClient';

export class LearningReportService {
  static async getReport(studentId: number): Promise<DataLoadResult<LearningReport>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<LearningReport>(ProfileMockData.getReport());
    try {
      const data: LearningReport = (await HttpClient.get<LearningReport>(`/students/${studentId}/learning-report`)).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`学习报告接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return ProfileMockData.mockResult<LearningReport>(ProfileMockData.getReport());
    }
  }
}
