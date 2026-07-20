import { common } from '@kit.AbilityKit';
import { AppConfig } from '../common/AppConfig';
import { AiChatHistory, AiChatResult, AiStreamCallbacks, ChatMessage, ChatRole, QuickQuestion } from '../model/AiModels';
import { AiService } from '../service/AiService';
import { AiSessionStorageService } from '../service/AiSessionStorageService';
import { MockDataService } from '../service/MockDataService';

export class ChatViewModel {
  static readonly QUICK_QUESTIONS: QuickQuestion[] = [
    { icon: '▣', label: '推荐适合课程', question: '请根据当前学生档案推荐合适的课程。' },
    { icon: '▤', label: '找专项试卷', question: '请根据学生薄弱知识点推荐专项试卷。' },
    { icon: '✓', label: '生成学习计划', question: '请根据学生档案和近期学习情况生成一周计划。' },
    { icon: '▥', label: '分析学习情况', question: '请分析当前学生最近的学习情况和薄弱点。' }
  ];

  static welcomeMessages(): ChatMessage[] {
    return MockDataService.welcomeMessages();
  }

  static createMessage(role: ChatRole, content: string, clientMessageId: string = ''): ChatMessage {
    return {
      id: `${role}_${Date.now()}_${Math.floor(Math.random() * 10000)}`,
      revision: 0,
      role: role,
      content: content,
      createdAt: Date.now(),
      createTime: '现在',
      isStreaming: false,
      fallbackUsed: false,
      intent: '',
      cards: [],
      sources: [],
      errorMessage: '',
      clientMessageId: clientMessageId,
      retryQuestion: ''
    };
  }

  static async restore(context: common.UIAbilityContext): Promise<AiChatHistory | null> {
    const sessionId: string = await AiSessionStorageService.load(context);
    if (!sessionId) return null;
    try {
      return await AiService.getHistory(sessionId);
    } catch (error) {
      console.warn(`AI 历史恢复失败: ${JSON.stringify(error)}`);
      await AiSessionStorageService.clear(context);
      return null;
    }
  }

  static async send(
    context: common.UIAbilityContext,
    studentProfileId: number,
    question: string,
    sessionId: string,
    callbacks: AiStreamCallbacks,
    clientMessageId: string = AiService.createClientMessageId()
  ): Promise<AiChatResult> {
    let result: AiChatResult;
    if (AppConfig.USE_MOCK_DATA) {
      result = {
        sessionId: sessionId || `mock_${Date.now()}`,
        intent: 'GENERAL_CHAT', confidence: 1,
        answer: '当前使用前端演示模式。启动 FastAPI 后端后，可以体验课程查询、RAG、多轮记忆和工具调用。',
        assistantMessage: '当前使用前端演示模式。启动 FastAPI 后端后，可以体验课程查询、RAG、多轮记忆和工具调用。',
        missingFields: [], toolCalls: [], cards: [], sources: [], fallbackUsed: true, requestId: clientMessageId
      };
    } else if (AppConfig.ENABLE_SSE) {
      try {
        result = await AiService.sendMessageStream(studentProfileId, question, sessionId, clientMessageId, callbacks);
      } catch (streamError) {
        if (streamError instanceof Error && streamError.message.startsWith('PARTIAL:')) {
          throw streamError;
        }
        console.warn(`SSE 不可用，使用相同消息ID降级: ${JSON.stringify(streamError)}`);
        result = await AiService.sendMessage(studentProfileId, question, sessionId, clientMessageId);
      }
    } else {
      result = await AiService.sendMessage(studentProfileId, question, sessionId, clientMessageId);
    }
    await AiSessionStorageService.save(context, result.sessionId);
    return result;
  }

  static async clear(context: common.UIAbilityContext, sessionId: string): Promise<void> {
    if (sessionId) await AiService.clearConversation(sessionId);
    await AiSessionStorageService.clear(context);
  }

  static async startNewConversation(context: common.UIAbilityContext): Promise<void> {
    await AiSessionStorageService.clear(context);
  }
}
