import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, WrongQuestion } from '../model/ProfileModels';
import { WrongQuestionTraining, WrongQuestionTrainingResult } from '../model/StudyPlanModels';
import { HttpClient } from './HttpClient';
import { WrongQuestionMasteryRequest, WrongQuestionBatchItemRequest, WrongQuestionBatchRequest, WrongQuestionBatchResult, WrongQuestionTrainingSubmitRequest } from './NetworkDtos';

export class WrongQuestionService {
  static async getQuestions(studentId: number, subject: string): Promise<DataLoadResult<WrongQuestion[]>> {
    if (studentId <= 0) {
      return { data: [], source: DataSource.LIVE, message: '请先绑定学生档案' };
    }
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<WrongQuestion[]>(ProfileMockData.getWrongQuestions(subject));
    try {
      const query: string = (!subject || subject === '全部') ? '' : `?subject=${subject}`;
      const data: WrongQuestion[] = (await HttpClient.get<WrongQuestion[]>(
        `/students/${studentId}/wrong-questions${query}`
      )).data;
      return { data: data || [], source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`错题接口不可用: ${JSON.stringify(error)}`);
      return { data: [], source: DataSource.LIVE, message: '错题加载失败' };
    }
  }

  static async addBatch(studentId: number, items: WrongQuestionBatchItemRequest[]): Promise<number> {
    if (studentId <= 0 || items.length === 0) {
      return 0;
    }
    if (AppConfig.USE_MOCK_DATA) {
      return items.length;
    }
    const request = new WrongQuestionBatchRequest();
    request.items = items;
    const data: WrongQuestionBatchResult = (await HttpClient.post<WrongQuestionBatchResult>(
      `/students/${studentId}/wrong-questions/batch`, request
    )).data;
    if (data && data.savedCount > 0) {
      return data.savedCount;
    }
    return items.length;
  }

  static async masterQuestion(studentId: number, id: number, mastered: boolean = true): Promise<void> {
    if (AppConfig.USE_MOCK_DATA || studentId <= 0) {
      ProfileMockData.masterQuestion(id);
      return;
    }
    const request = new WrongQuestionMasteryRequest();
    request.mastered = mastered;
    await HttpClient.put<Object>(`/students/${studentId}/wrong-questions/${id}/mastered`, request);
  }

  static async deleteQuestion(studentId: number, id: number): Promise<void> {
    if (AppConfig.USE_MOCK_DATA || studentId <= 0) {
      ProfileMockData.removeWrongQuestion(id);
      return;
    }
    // 优先用 POST remove，避免部分设备 DELETE 请求异常
    try {
      await HttpClient.post<Object>(`/students/${studentId}/wrong-questions/${id}/remove`, new Object());
    } catch (error) {
      await HttpClient.delete<Object>(`/students/${studentId}/wrong-questions/${id}`);
    }
  }

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
