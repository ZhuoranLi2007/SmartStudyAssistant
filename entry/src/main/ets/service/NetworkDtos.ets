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
