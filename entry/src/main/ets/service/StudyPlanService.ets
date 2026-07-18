import { StudyTask } from '../model/DomainModels';
import { HttpClient } from './HttpClient';
import { StudyTaskRequest, TaskStatusRequest } from './NetworkDtos';

export class StudyPlanService {
  static async getTasks(studentProfileId: number): Promise<StudyTask[]> {
    return (await HttpClient.get<StudyTask[]>(`/study-plans?student_profile_id=${studentProfileId}`)).data;
  }

  static async addTask(studentProfileId: number, taskType: string, targetId: number): Promise<StudyTask> {
    const request = new StudyTaskRequest();
    request.student_profile_id = studentProfileId;
    request.task_type = taskType;
    request.target_id = targetId;
    return (await HttpClient.post<StudyTask>('/study-plans', request)).data;
  }

  static async updateStatus(taskId: number, status: string): Promise<StudyTask> {
    const request = new TaskStatusRequest();
    request.status = status;
    return (await HttpClient.put<StudyTask>(`/study-plans/${taskId}/status`, request)).data;
  }
}
