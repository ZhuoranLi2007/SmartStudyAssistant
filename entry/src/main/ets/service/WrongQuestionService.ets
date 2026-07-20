import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, WrongQuestion } from '../model/ProfileModels';
import { WrongQuestionTraining, WrongQuestionTrainingResult } from '../model/StudyPlanModels';
import { HttpClient } from './HttpClient';
import { WrongQuestionTrainingSubmitRequest } from './NetworkDtos';

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

  static async getTraining(studentId: number, wrongQuestionId: number): Promise<WrongQuestionTraining> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.getWrongQuestionTraining(wrongQuestionId);
    try {
      const data: WrongQuestionTraining = (await HttpClient.get<WrongQuestionTraining>(
        `/students/${studentId}/wrong-questions/${wrongQuestionId}/training`
      )).data;
      data.live = true;
      return data;
    } catch (error) {
      console.warn(`错题复测接口不可用，使用演示题: ${JSON.stringify(error)}`);
      return ProfileMockData.getWrongQuestionTraining(wrongQuestionId);
    }
  }

  static async submitTraining(studentId: number, wrongQuestionId: number,
    selectedIndex: number, live: boolean): Promise<WrongQuestionTrainingResult> {
    if (AppConfig.USE_MOCK_DATA || !live) {
      return ProfileMockData.submitWrongQuestionTraining(wrongQuestionId, selectedIndex);
    }
    const request = new WrongQuestionTrainingSubmitRequest();
    request.selectedIndex = selectedIndex;
    return (await HttpClient.post<WrongQuestionTrainingResult>(
      `/students/${studentId}/wrong-questions/${wrongQuestionId}/training/submit`, request
    )).data;
  }
}
