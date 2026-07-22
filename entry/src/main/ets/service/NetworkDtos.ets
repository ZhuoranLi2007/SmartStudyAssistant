export class LoginRequest {
  account: string = '';
  password: string = '';
}

export class RegisterRequest {
  username: string = '';
  phone: string = '';
  password: string = '';
  role: string = 'parent';
}

export class ChatRequest {
  session_id: string | null = null;
  student_profile_id: number = 0;
  message: string = '';
}

export class RecommendationRequest {
  student_profile_id: number = 0;
  subject: string | null = null;
}

export class PaperAnalyzeRequest {
  text: string = '';
  grade: string | null = null;
}

export class StudyTaskRequest {
  student_profile_id: number = 0;
  task_type: string = '课程';
  target_id: number = 1;
}

export class TaskStatusRequest {
  status: string = '未开始';
}

export class WrongQuestionTrainingSubmitRequest {
  selectedIndex: number = -1;
}

export class WrongQuestionMasteryRequest {
  mastered: boolean = true;
}

export class WrongQuestionBatchItemRequest {
  paperId: number = 0;
  questionId: number = 0;
  subject: string = '';
  knowledgePoint: string = '';
  questionText: string = '';
  userAnswer: string = '';
  correctAnswer: string = '';
  explanation: string = '';
}

export class WrongQuestionBatchRequest {
  items: WrongQuestionBatchItemRequest[] = [];
}

export interface WrongQuestionBatchResult {
  savedCount: number;
}

export class OrderCreateRequest {
  student_profile_id: number = 0;
  course_id: number = 0;
}
