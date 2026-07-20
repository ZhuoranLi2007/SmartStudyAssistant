import { PracticeQuestion } from './HomeModels';

export enum ChatRole {
  USER = 'user',
  ASSISTANT = 'assistant',
  SYSTEM = 'system'
}

export enum AiCardType {
  COURSE = 'COURSE',
  PAPER = 'PAPER',
  STUDY_PLAN = 'STUDY_PLAN',
  ORDER = 'ORDER'
}

export enum MarkdownBlockType {
  PARAGRAPH = 'PARAGRAPH',
  HEADING = 'HEADING',
  BULLET_LIST = 'BULLET_LIST',
  NUMBERED_LIST = 'NUMBERED_LIST',
  DIVIDER = 'DIVIDER',
  SPACER = 'SPACER'
}

export interface MarkdownInlineSegment {
  text: string;
  bold: boolean;
}

export interface MarkdownBlock {
  type: MarkdownBlockType;
  content: string;
  items: string[];
}

export interface QuickQuestion {
  icon: string;
  label: string;
  question: string;
}

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
  grade?: string;
  subject?: string;
  level?: string;
  difficulty?: string;
  recommendationReason?: string;
  lessonCount?: number;
  questionCount?: number;
  knowledgePoints?: string[];
  tasks?: AiPlanTask[];
  orderNo?: string;
  orderStatus?: string;
  amount?: number;
  route: string;
  routeParams: Object;
}

export interface AiPlanTask {
  id: number;
  date: string;
  title: string;
  taskType: string;
  durationMinutes: number;
  courseId?: number;
  paperId?: number;
  knowledgePoint: string;
  status: string;
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

export interface ChatMessage {
  id: string;
  role: ChatRole;
  content: string;
  createdAt: number;
  createTime: string;
  isStreaming: boolean;
  fallbackUsed: boolean;
  intent: string;
  cards: AiCard[];
  sources: AiSource[];
  errorMessage: string;
  clientMessageId: string;
  retryQuestion: string;
}

export interface AiStreamCallbacks {
  onDelta: (content: string) => void;
  onIntent: (intent: string) => void;
  onMeta: (sessionId: string, requestId: string) => void;
  onSource: (source: AiSource) => void;
}

export interface AiSsePayload {
  content?: string;
  intent?: string;
  sessionId?: string;
  requestId?: string;
  title?: string;
  sourceType?: string;
  sourceId?: string;
  score?: number;
  excerpt?: string;
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
