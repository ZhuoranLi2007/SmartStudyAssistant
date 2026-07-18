import { Paper } from '../model/DomainModels';
import { HttpClient } from './HttpClient';
import { PaperAnalyzeRequest } from './NetworkDtos';

export interface PaperAnalysis {
  subject: string;
  grade: string;
  knowledgePoints: string[];
  difficulty: string;
  needsConfirmation: boolean;
}

export class PaperService {
  static async getPapers(query: string = ''): Promise<Paper[]> {
    return (await HttpClient.get<Paper[]>(`/papers${query}`)).data;
  }

  static async getPaper(id: number): Promise<Paper> {
    return (await HttpClient.get<Paper>(`/papers/${id}`)).data;
  }

  static async analyze(text: string, grade: string = ''): Promise<PaperAnalysis> {
    const request = new PaperAnalyzeRequest();
    request.text = text;
    request.grade = grade || null;
    return (await HttpClient.post<PaperAnalysis>('/papers/analyze', request)).data;
  }
}
