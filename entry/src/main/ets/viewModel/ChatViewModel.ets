import { common } from '@kit.AbilityKit';
import { AppConfig } from '../common/AppConfig';
import { AiChatHistory, AiChatResult, AiStreamCallbacks } from '../model/AiModels';
import { AiService } from '../service/AiService';
import { AiSessionStorageService } from '../service/AiSessionStorageService';

export class ChatViewModel {
  static readonly QUICK_QUESTIONS: string[] = [
    '六年级数学82分，应用题较弱，适合什么课程？',
    '推荐几份英语阅读专项试卷',
    '帮我生成七天学习计划',
    '分析一下最近的错题和薄弱点'
  ];

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
    callbacks: AiStreamCallbacks
  ): Promise<AiChatResult> {
    const clientMessageId: string = AiService.createClientMessageId();
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
}
