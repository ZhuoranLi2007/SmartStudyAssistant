export enum StudyPlanFilter {
  TODAY = 'TODAY',
  WEEK = 'WEEK',
  COMPLETED = 'COMPLETED'
}

export interface RecommendedPaper {
  id: number;
  name: string;
  grade: string;
  subject: string;
  difficulty: string;
  knowledgePoints: string[];
  questionCount: number;
  recommendReason: string;
}

export interface RecommendedWrongQuestion {
  id: number;
  subject: string;
  knowledgePoint: string;
  question: string;
  wrongCount: number;
  recommendReason: string;
}

export interface WrongQuestionTraining {
  id: number;
  questionId: number;
  subject: string;
  knowledgePoint: string;
  question: string;
  options: string[];
  previousAnswer: string;
  wrongCount: number;
  mastered: boolean;
  live: boolean;
}

export interface WrongQuestionTrainingResult {
  correct: boolean;
  correctIndex: number;
  explanation: string;
  mastered: boolean;
  wrongCount: number;
}

export interface StudyPlanSummary {
  totalCount: number;
  completedCount: number;
  courseCount: number;
  paperCount: number;
  wrongQuestionCount: number;
  unmasteredWrongQuestionCount: number;
  totalMinutes: number;
  progress: number;
}

export interface WeekDayItem {
  date: string;
  dayLabel: string;
  dateLabel: string;
  isToday: boolean;
}
