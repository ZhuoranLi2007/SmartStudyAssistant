import { PracticeQuestion } from './HomeModels';

export interface AiToolCall {
  name: string;
  arguments: Object;
  result: Object;
}

export interface AiCard {
  type: string;
  id: number;
  title: string;
  subtitle: string;
  price?: number;
  route: string;
  routeParams: Object;
}

export interface AiSource {
  title: string;
  sourceType: string;
  sourceId: string;
  score: number;
  excerpt: string;
}

export interface AiChatResult {
  sessionId: string;
  intent: string;
  confidence: number;
  answer: string;
  assistantMessage: string;
  missingFields: string[];
  clarificationQuestion?: string;
  toolCalls: AiToolCall[];
  cards: AiCard[];
  sources: AiSource[];
  fallbackUsed: boolean;
  requestId: string;
}

export interface AiHistoryMessage {
  id: number;
  role: string;
  content: string;
  intent: string;
  createTime: string;
}

export interface AiChatHistory {
  sessionId: string;
  studentProfileId: number;
  summary: string;
  messages: AiHistoryMessage[];
}

export interface AiStreamCallbacks {
  onDelta: (content: string) => void;
  onIntent: (intent: string) => void;
}

export interface AiSsePayload {
  content?: string;
  intent?: string;
}

export interface PaperQuestionDto {
  id: number;
  sequence: number;
  stem: string;
  options: string[];
  knowledgePoint: string;
}

export interface PaperQuestionsResult {
  paper: PaperSummary;
  questions: PaperQuestionDto[];
}

export interface PaperSummary {
  id: number;
  name: string;
}

export interface PracticeAttemptResult {
  attemptId: number;
  paperId: number;
  score: number;
  correctCount: number;
  questionCount: number;
  results: PracticeQuestionResult[];
}

export interface PracticeQuestionResult {
  questionId: number;
  selectedIndex: number;
  correctIndex: number;
  correct: boolean;
  explanation: string;
}

export interface PracticeLoadResult {
  paperName: string;
  questions: PracticeQuestion[];
  live: boolean;
}
