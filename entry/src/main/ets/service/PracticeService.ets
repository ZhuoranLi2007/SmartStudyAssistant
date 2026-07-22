import { AppConfig } from '../common/AppConfig';
import { MockHomeData } from '../data/MockHomeData';
import { PaperQuestionDto, PaperQuestionsResult, PracticeAttemptResult, PracticeLoadResult } from '../model/AiModels';
import { PracticeOption, PracticeQuestion } from '../model/HomeModels';
import { MockDataService } from './MockDataService';
import { HttpClient } from './HttpClient';

class PracticeAnswerBody {
  questionId: number = 0;
  selectedIndex: number = 0;
}

class PracticeAttemptBody {
  studentProfileId: number = 0;
  answers: PracticeAnswerBody[] = [];
}

export class PracticeService {
  private static options(values: string[]): PracticeOption[] {
    const labels: string[] = ['A', 'B', 'C', 'D', 'E', 'F'];
    const result: PracticeOption[] = [];
    for (let index: number = 0; index < values.length; index++) {
      result.push({ label: labels[index], content: values[index] });
    }
    return result;
  }

  static async load(paperId: number): Promise<PracticeLoadResult> {
    if (!AppConfig.USE_MOCK_DATA) {
      try {
        const data: PaperQuestionsResult = (await HttpClient.get<PaperQuestionsResult>(`/papers/${paperId}/questions`)).data;
        const questions: PracticeQuestion[] = [];
        for (let index: number = 0; index < data.questions.length; index++) {
          const item: PaperQuestionDto = data.questions[index];
          questions.push({
            id: item.id, stem: item.stem,
            options: PracticeService.options(item.options), correctIndex: -1,
            explanation: '',
            knowledgePoint: item.knowledgePoint || '综合',
            subject: data.paper.subject || ''
          });
        }
        return { paperName: data.paper.name || '在线答题', questions: questions, live: true };
      } catch (error) {
        console.warn(`真实题目接口不可用，降级为本地题目: ${JSON.stringify(error)}`);
      }
    }
    return {
      paperName: MockDataService.getPaper(paperId).name,
      questions: MockHomeData.getPracticeQuestions(paperId),
      live: false
    };
  }

  static async submit(
    paperId: number, studentProfileId: number, questions: PracticeQuestion[], selectedAnswers: number[]
  ): Promise<PracticeAttemptResult> {
    const body = new PracticeAttemptBody();
    body.studentProfileId = studentProfileId;
    for (let index: number = 0; index < questions.length; index++) {
      const answer = new PracticeAnswerBody();
      answer.questionId = questions[index].id;
      answer.selectedIndex = selectedAnswers[index];
      body.answers.push(answer);
    }
    return (await HttpClient.post<PracticeAttemptResult>(`/papers/${paperId}/attempts`, body)).data;
  }
}
