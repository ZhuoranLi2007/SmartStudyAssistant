import { HttpClient } from './HttpClient';
import { ChatRequest } from './NetworkDtos';

export interface AiChatResult {
  sessionId: string;
  assistantMessage: string;
  intent: string;
  missingFields: string[];
  toolCalls: Object[];
}

export class AiService {
  static async sendMessage(studentProfileId: number, message: string, sessionId: string = ''): Promise<AiChatResult> {
    const request = new ChatRequest();
    request.student_profile_id = studentProfileId;
    request.message = message;
    request.session_id = sessionId || null;
    return (await HttpClient.post<AiChatResult>('/chat', request)).data;
  }

  static async clearConversation(sessionId: string): Promise<void> {
    await HttpClient.delete<Object>(`/chat/history/${sessionId}`);
  }
}
