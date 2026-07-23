import { HttpClient } from './HttpClient';

export interface AIGeneratedPaper {
  id: number;
  name: string;
  grade: string;
  subject: string;
  difficulty: string;
  knowledgePoints: string[];
  questionCount: number;
  createdAt: string;
}

export interface GeneratePaperBody {
  studentProfileId: number;
  requirement: string;
  grade: string;
  subject: string;
  basedOnWrongQuestions: boolean;
}

export interface GeneratePaperResult {
  id: number;
  name: string;
  questionCount: number;
}

export class AIPaperService {
  static async generate(body: GeneratePaperBody): Promise<GeneratePaperResult> {
    return (await HttpClient.post<GeneratePaperResult>('/papers/generate', body)).data;
  }

  static async getMyPapers(): Promise<AIGeneratedPaper[]> {
    return (await HttpClient.get<AIGeneratedPaper[]>('/papers/my/list')).data;
  }

  static async deleteMyPaper(paperId: number): Promise<void> {
    await HttpClient.delete<void>(`/papers/my/${paperId}`);
  }
}
