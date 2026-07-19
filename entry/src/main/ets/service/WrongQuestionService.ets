import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, WrongQuestion } from '../model/ProfileModels';
import { HttpClient } from './HttpClient';

export class WrongQuestionService {
  static async getQuestions(studentId: number, subject: string): Promise<DataLoadResult<WrongQuestion[]>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<WrongQuestion[]>(ProfileMockData.getWrongQuestions(subject));
    try {
      const data: WrongQuestion[] = (await HttpClient.get<WrongQuestion[]>(`/students/${studentId}/wrong-questions?subject=${subject}`)).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`错题接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return ProfileMockData.mockResult<WrongQuestion[]>(ProfileMockData.getWrongQuestions(subject));
    }
  }

  static masterQuestion(id: number): void { ProfileMockData.masterQuestion(id); }
}
