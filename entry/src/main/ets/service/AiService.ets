import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { AppConfig } from '../common/AppConfig';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { AiChatHistory, AiChatResult, AiSource, AiSsePayload, AiStreamCallbacks } from '../model/AiModels';
import { HttpClient } from './HttpClient';

class AiChatRequestBody {
  userId: number | null = null;
  studentProfileId: number = 0;
  message: string = '';
  sessionId: string | null = null;
  clientMessageId: string = '';
}

class AiRequestHeaders {
  'Content-Type': string = 'application/json';
  Accept: string = 'text/event-stream';
  Authorization: string = '';
}

export class AiService {
  static createClientMessageId(): string {
    return `msg_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }

  private static body(studentProfileId: number, message: string, sessionId: string, clientMessageId: string): AiChatRequestBody {
    const request = new AiChatRequestBody();
    const userId: number = AppStorage.get<number>(AppStorageKeys.USER_ID) || 0;
    request.userId = userId > 0 ? userId : null;
    request.studentProfileId = studentProfileId;
    request.message = message;
    request.sessionId = sessionId || null;
    request.clientMessageId = clientMessageId;
    return request;
  }

  static async sendMessage(
    studentProfileId: number,
    message: string,
    sessionId: string = '',
    clientMessageId: string = AiService.createClientMessageId()
  ): Promise<AiChatResult> {
    const response = await HttpClient.post<AiChatResult>(
      '/ai/chat', AiService.body(studentProfileId, message, sessionId, clientMessageId)
    );
    if (response.code !== 0 && response.code !== 200) {
      throw new Error(response.message || 'AI 服务返回异常');
    }
    return response.data;
  }

  static async getHistory(sessionId: string): Promise<AiChatHistory> {
    return (await HttpClient.get<AiChatHistory>(`/ai/sessions/${sessionId}/messages`)).data;
  }

  static async clearConversation(sessionId: string): Promise<void> {
    await HttpClient.delete<Object>(`/ai/sessions/${sessionId}`);
  }

  static async sendMessageStream(
    studentProfileId: number,
    message: string,
    sessionId: string,
    clientMessageId: string,
    callbacks: AiStreamCallbacks
  ): Promise<AiChatResult> {
    const client = http.createHttp();
    const decoder = util.TextDecoder.create('utf-8');
    const headers = new AiRequestHeaders();
    const token: string = AppStorage.get<string>(AppStorageKeys.AUTH_TOKEN) || '';
    if (token) headers.Authorization = `Bearer ${token}`;
    let buffer: string = '';
    let finalResult: AiChatResult | null = null;
    let receivedDelta: boolean = false;
    let settled: boolean = false;

    return new Promise<AiChatResult>((resolve: (value: AiChatResult) => void, reject: (reason: Error) => void) => {
      const fail = (message: string): void => {
        if (settled) return;
        settled = true;
        client.destroy();
        reject(new Error(`${receivedDelta ? 'PARTIAL:' : 'EMPTY:'}${message}`));
      };

      const processBuffer = (): void => {
        let boundary: number = buffer.indexOf('\n\n');
        while (boundary >= 0) {
          const block: string = buffer.substring(0, boundary).replace(/\r/g, '');
          buffer = buffer.substring(boundary + 2);
          let eventName: string = 'message';
          let dataText: string = '';
          const lines: string[] = block.split('\n');
          for (let index: number = 0; index < lines.length; index++) {
            if (lines[index].startsWith('event:')) eventName = lines[index].substring(6).trim();
            if (lines[index].startsWith('data:')) dataText += lines[index].substring(5).trim();
          }
          if (dataText) {
            try {
              if (eventName === 'done') {
                finalResult = JSON.parse(dataText) as AiChatResult;
              } else if (eventName === 'delta') {
                const payload = JSON.parse(dataText) as AiSsePayload;
                if (payload.content) {
                  receivedDelta = true;
                  callbacks.onDelta(payload.content);
                }
              } else if (eventName === 'intent') {
                const payload = JSON.parse(dataText) as AiSsePayload;
                callbacks.onIntent(payload.intent || 'UNKNOWN');
              } else if (eventName === 'meta') {
                const payload = JSON.parse(dataText) as AiSsePayload;
                callbacks.onMeta(payload.sessionId || '', payload.requestId || '');
              } else if (eventName === 'source') {
                const payload = JSON.parse(dataText) as AiSsePayload;
                const source: AiSource = {
                  title: payload.title || '参考资料',
                  sourceType: payload.sourceType || '',
                  sourceId: payload.sourceId || '',
                  score: payload.score || 0,
                  excerpt: payload.excerpt || ''
                };
                callbacks.onSource(source);
              } else if (eventName === 'error') {
                fail('AI 流式响应失败');
              }
            } catch (error) {
              console.warn(`忽略无法解析的 SSE 事件: ${JSON.stringify(error)}`);
            }
          }
          boundary = buffer.indexOf('\n\n');
        }
      };

      client.on('dataReceive', (data: ArrayBuffer) => {
        buffer += decoder.decodeToString(new Uint8Array(data), { stream: true });
        processBuffer();
      });
      client.on('dataEnd', () => {
        if (settled) return;
        buffer += decoder.decodeToString(new Uint8Array(0));
        processBuffer();
        if (settled) return;
        client.destroy();
        settled = true;
        if (finalResult) resolve(finalResult);
        else reject(new Error(`${receivedDelta ? 'PARTIAL:' : 'EMPTY:'}${receivedDelta ? '流式响应未正常结束' : '流式响应未返回内容'}`));
      });
      client.requestInStream(`${AppConfig.API_BASE_URL}/ai/chat/stream`, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(AiService.body(studentProfileId, message, sessionId, clientMessageId)),
        connectTimeout: AppConfig.REQUEST_TIMEOUT_MS,
        readTimeout: AppConfig.REQUEST_TIMEOUT_MS
      }).then((responseCode: number) => {
        if (responseCode < 200 || responseCode >= 300) fail(`HTTP ${responseCode}`);
      }).catch((error: Error) => fail(error.message || 'AI 流式连接失败'));
    });
  }
}
