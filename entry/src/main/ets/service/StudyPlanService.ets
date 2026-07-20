import { AppConfig } from '../common/AppConfig';
import { StudyTask } from '../model/DomainModels';
import { DataLoadResult, DataSource } from '../model/ProfileModels';
import { RecommendedPaper } from '../model/StudyPlanModels';
import { RecommendedWrongQuestion } from '../model/StudyPlanModels';
import { ProfileMockData } from '../data/ProfileMockData';
import { HttpClient } from './HttpClient';
import { MockDataService } from './MockDataService';
import { StudyTaskRequest, TaskStatusRequest } from './NetworkDtos';

export class StudyPlanService {
  private static isProtectedError(error: Object): boolean {
    const message: string = `${error}`;
    return message.includes('HTTP 401') || message.includes('HTTP 403') ||
      message.includes('HTTP 404') || message.includes('HTTP 409') || message.includes('HTTP 422');
  }

  static async getTasks(studentProfileId: number): Promise<DataLoadResult<StudyTask[]>> {
    if (AppConfig.USE_MOCK_DATA) {
      return { data: MockDataService.getTasks(), source: DataSource.MOCK, message: '当前学习计划为演示数据' };
    }
    try {
      const data: StudyTask[] = (await HttpClient.get<StudyTask[]>(`/study-plans?student_profile_id=${studentProfileId}`)).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`学习计划接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return { data: MockDataService.getTasks(), source: DataSource.MOCK, message: '网络服务暂不可用，当前展示演示计划' };
    }
  }

  static async getRecommendedPapers(studentProfileId: number): Promise<DataLoadResult<RecommendedPaper[]>> {
    if (AppConfig.USE_MOCK_DATA) {
      return { data: MockDataService.getRecommendedPapers(), source: DataSource.MOCK, message: '当前推荐为演示数据' };
    }
    try {
      const data: RecommendedPaper[] = (await HttpClient.get<RecommendedPaper[]>(
        `/study-plans/recommended-papers?student_profile_id=${studentProfileId}&limit=3`
      )).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`推荐试卷接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return { data: MockDataService.getRecommendedPapers(), source: DataSource.MOCK, message: '推荐服务暂不可用，当前展示演示试卷' };
    }
  }

  static async getRecommendedWrongQuestions(studentProfileId: number): Promise<DataLoadResult<RecommendedWrongQuestion[]>> {
    if (AppConfig.USE_MOCK_DATA) {
      const plannedIds: number[] = MockDataService.getTasks().filter((task: StudyTask) => task.taskType === '错题')
        .map((task: StudyTask) => task.targetId);
      const data: RecommendedWrongQuestion[] = ProfileMockData.getRecommendedWrongQuestions()
        .filter((item: RecommendedWrongQuestion) => plannedIds.indexOf(item.id) < 0);
      return { data: data, source: DataSource.MOCK,
        message: '当前错题推荐为演示数据' };
    }
    try {
      const data: RecommendedWrongQuestion[] = (await HttpClient.get<RecommendedWrongQuestion[]>(
        `/study-plans/recommended-wrong-questions?student_profile_id=${studentProfileId}&limit=4`
      )).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`错题推荐接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      const plannedIds: number[] = MockDataService.getTasks().filter((task: StudyTask) => task.taskType === '错题')
        .map((task: StudyTask) => task.targetId);
      const data: RecommendedWrongQuestion[] = ProfileMockData.getRecommendedWrongQuestions()
        .filter((item: RecommendedWrongQuestion) => plannedIds.indexOf(item.id) < 0);
      return { data: data, source: DataSource.MOCK,
        message: '错题推荐服务暂不可用，当前展示演示数据' };
    }
  }

  static async addTask(studentProfileId: number, taskType: string, targetId: number): Promise<StudyTask> {
    if (AppConfig.USE_MOCK_DATA) {
      if (taskType === '错题') {
        const wrong = ProfileMockData.getWrongQuestionTraining(targetId);
        return MockDataService.addTask(`${wrong.knowledgePoint}错题复测`, taskType, wrong.subject, '错题巩固', targetId);
      }
      if (taskType === '试卷') {
        const paper = MockDataService.getPaper(targetId);
        return MockDataService.addTask(paper.name, taskType, paper.subject, paper.difficulty, targetId);
      }
      const course = MockDataService.getCourse(targetId);
      return MockDataService.addTask(course.name, taskType, course.subject, course.difficulty, targetId);
    }
    const request = new StudyTaskRequest();
    request.student_profile_id = studentProfileId;
    request.task_type = taskType;
    request.target_id = targetId;
    try {
      return (await HttpClient.post<StudyTask>('/study-plans', request)).data;
    } catch (error) {
      if (StudyPlanService.isProtectedError(error)) throw new Error(`${error}`);
      if (taskType === '错题') {
        const wrong = ProfileMockData.getWrongQuestionTraining(targetId);
        return MockDataService.addTask(`${wrong.knowledgePoint}错题复测`, taskType, wrong.subject, '错题巩固', targetId);
      }
      if (taskType === '试卷') {
        const paper = MockDataService.getPaper(targetId);
        return MockDataService.addTask(paper.name, taskType, paper.subject, paper.difficulty, targetId);
      }
      const course = MockDataService.getCourse(targetId);
      return MockDataService.addTask(course.name, taskType, course.subject, course.difficulty, targetId);
    }
  }

  static async updateStatus(taskId: number, status: string): Promise<StudyTask> {
    if (AppConfig.USE_MOCK_DATA) {
      MockDataService.updateTaskStatus(taskId, status);
      return MockDataService.getTasks().filter((item: StudyTask) => item.id === taskId)[0];
    }
    const request = new TaskStatusRequest();
    request.status = status;
    try {
      return (await HttpClient.put<StudyTask>(`/study-plans/${taskId}/status`, request)).data;
    } catch (error) {
      if (StudyPlanService.isProtectedError(error)) throw new Error(`${error}`);
      MockDataService.updateTaskStatus(taskId, status);
      return MockDataService.getTasks().filter((item: StudyTask) => item.id === taskId)[0];
    }
  }

  static async deleteTask(taskId: number): Promise<void> {
    if (AppConfig.USE_MOCK_DATA) {
      MockDataService.removeTask(taskId);
      return;
    }
    try {
      await HttpClient.delete<boolean>(`/study-plans/${taskId}`);
    } catch (error) {
      if (StudyPlanService.isProtectedError(error)) throw new Error(`${error}`);
      MockDataService.removeTask(taskId);
    }
  }
}
