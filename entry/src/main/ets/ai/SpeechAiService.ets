import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { speechRecognizer, textToSpeech } from '@kit.CoreSpeechKit';
import { AppConfig } from '../common/AppConfig';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { audioRecorderService } from './AudioRecorderService';

export type AsrResultHandler = (text: string, isFinal: boolean, isLast: boolean) => void;
export type AsrErrorHandler = (errorCode: number, errorMessage: string) => void;
export type BackendAsrResultHandler = (text: string) => void;
export type BackendAsrErrorHandler = (message: string) => void;

interface RequestHeader {
  'Content-Type': string;
  Authorization: string;
}

interface RecognizeData {
  text: string;
  success: boolean;
}

interface RecognizeApiResponse {
  code: number;
  data: RecognizeData;
}

class SpeechAiService {
  private static instance: SpeechAiService;
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private ttsCompleteCallback: (() => void) | null = null;
  private currentTtsRequestId: string = '';
  private ttsStartTime: number = 0;
  private sessionId: string = '';
  private resultHandler: AsrResultHandler | null = null;
  private errorHandler: AsrErrorHandler | null = null;
  private backendResultHandler: BackendAsrResultHandler | null = null;
  private backendErrorHandler: BackendAsrErrorHandler | null = null;

  static getInstance(): SpeechAiService {
    if (!SpeechAiService.instance) {
      SpeechAiService.instance = new SpeechAiService();
    }
    return SpeechAiService.instance;
  }

  isAsrSupported(): boolean {
    return canIUse('SystemCapability.AI.SpeechRecognizer');
  }

  isTtsSupported(): boolean {
    return canIUse('SystemCapability.AI.TextToSpeech');
  }

  async requestMicrophonePermission(context: common.UIAbilityContext): Promise<boolean> {
    const permission: Permissions = 'ohos.permission.MICROPHONE';
    const manager = abilityAccessCtrl.createAtManager();
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    const tokenId: number = bundleInfo.appInfo.accessTokenId;
    const status = await manager.checkAccessToken(tokenId, permission);
    if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
      return true;
    }
    const result = await manager.requestPermissionsFromUser(context, [permission]);
    return result.authResults.length > 0 && result.authResults[0] === 0;
  }

  private async ensureAsrEngine(): Promise<boolean> {
    if (this.asrEngine) return true;
    if (!this.isAsrSupported()) return false;
    try {
      this.asrEngine = await speechRecognizer.createEngine({ language: 'zh-CN', online: 1 });
    } catch (error) {
      console.warn(`在线 ASR 引擎初始化失败，尝试离线: ${JSON.stringify(error)}`);
      try {
        this.asrEngine = await speechRecognizer.createEngine({ language: 'zh-CN', online: 0 });
      } catch (offlineError) {
        console.error(`离线 ASR 引擎初始化失败: ${JSON.stringify(offlineError)}`);
        this.asrEngine = null;
        return false;
      }
    }
    try {
      this.asrEngine.setListener({
        onStart: (sessionId: string, eventMessage: string): void => {
          console.info(`ASR onStart: ${sessionId}, ${eventMessage}`);
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {
          console.info(`ASR onEvent: ${sessionId}, code=${eventCode}, ${eventMessage}`);
        },
        onResult: (_sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
          console.info(`ASR onResult: ${JSON.stringify(result)}`);
          if (this.resultHandler) this.resultHandler(result.result, result.isFinal, result.isLast);
        },
        onComplete: (sessionId: string, eventMessage: string): void => {
          console.info(`ASR onComplete: ${sessionId}, ${eventMessage}`);
        },
        onError: (_sessionId: string, errorCode: number, errorMessage: string): void => {
          console.error(`ASR onError: ${errorCode}, ${errorMessage}`);
          if (this.errorHandler) this.errorHandler(errorCode, errorMessage);
        }
      });
      return true;
    } catch (error) {
      console.error(`设置 ASR 监听器失败: ${JSON.stringify(error)}`);
      this.asrEngine = null;
      return false;
    }
  }

  async startListening(onResult: AsrResultHandler, onError?: AsrErrorHandler): Promise<boolean> {
    if (!(await this.ensureAsrEngine()) || !this.asrEngine) return false;
    this.resultHandler = onResult;
    this.errorHandler = onError ? onError : null;
    this.sessionId = `asr_${Date.now()}`;
    const params: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: { audioType: 'pcm', sampleRate: 16000, soundChannel: 1, sampleBit: 16 }
    };
    try {
      await this.asrEngine.startListening(params);
      console.info(`ASR startListening success: ${this.sessionId}`);
      return true;
    } catch (error) {
      console.error(`启动语音识别失败: ${JSON.stringify(error)}`);
      this.sessionId = '';
      return false;
    }
  }

  stopListening(): void {
    if (this.asrEngine && this.sessionId) {
      try { this.asrEngine.finish(this.sessionId); } catch (error) { console.error(`结束识别失败: ${JSON.stringify(error)}`); }
    }
  }

  cancelListening(): void {
    if (this.asrEngine && this.sessionId) {
      try { this.asrEngine.cancel(this.sessionId); } catch (error) { console.error(`取消识别失败: ${JSON.stringify(error)}`); }
    }
  }

  // ====== 后端语音识别（通过 AudioCapturer 录音 + 后端 API 识别）======

  isBackendAsrSupported(): boolean {
    return audioRecorderService.isRecordingSupported();
  }

  async startBackendRecording(context: common.UIAbilityContext, onResult: BackendAsrResultHandler,
    onError?: BackendAsrErrorHandler): Promise<boolean> {
    this.backendResultHandler = onResult;
    this.backendErrorHandler = onError || null;
    audioRecorderService.setMaxDuration(60000);
    console.info('SpeechAiService: 尝试启动后端录音');
    const started: boolean = await audioRecorderService.startRecording(context,
      (filePath: string): void => {
        void this.handleRecordingComplete(filePath);
      },
      (message: string): void => {
        if (this.backendErrorHandler) this.backendErrorHandler(message);
      }
    );
    console.info(`SpeechAiService: 后端录音启动${started ? '成功' : '失败'}`);
    return started;
  }

  private async handleRecordingComplete(filePath: string): Promise<void> {
    try {
      const text: string = await this.uploadAudioToBackend(filePath);
      if (text) {
        if (this.backendResultHandler) this.backendResultHandler(text);
      } else {
        if (this.backendErrorHandler) this.backendErrorHandler('未能识别出语音内容，请靠近麦克风清晰说话后重试');
      }
    } catch (error) {
      const err: Error = error as Error;
      console.error(`后端语音识别失败: ${err.message}`);
      if (this.backendErrorHandler) this.backendErrorHandler(`语音识别失败: ${err.message}`);
    } finally {
      this.deleteAudioFile(filePath);
    }
  }

  private async uploadAudioToBackend(filePath: string): Promise<string> {
    const client = http.createHttp();
    try {
      const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(filePath);
      const fileBuffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, fileBuffer);
      fileIo.closeSync(file.fd);

      const boundary: string = `Boundary_${Date.now()}`;
      const fileName: string = 'audio.wav';
      const token: string = AppStorage.get<string>(AppStorageKeys.AUTH_TOKEN) || '';
      const header: RequestHeader = {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Authorization': token ? `Bearer ${token}` : ''
      } as RequestHeader;

      // 构造 multipart 请求体
      const encoder = new util.TextEncoder();
      const headerPart: string = `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${fileName}"\r\nContent-Type: audio/wav\r\n\r\n`;
      const footerPart: string = `\r\n--${boundary}--\r\n`;
      const headerBytes: Uint8Array = encoder.encodeInto(headerPart);
      const footerBytes: Uint8Array = encoder.encodeInto(footerPart);
      const totalSize: number = headerBytes.byteLength + fileBuffer.byteLength + footerBytes.byteLength;
      const requestBody: ArrayBuffer = new ArrayBuffer(totalSize);
      const bodyView: Uint8Array = new Uint8Array(requestBody);
      let offset: number = 0;
      bodyView.set(headerBytes, offset);
      offset += headerBytes.byteLength;
      bodyView.set(new Uint8Array(fileBuffer), offset);
      offset += fileBuffer.byteLength;
      bodyView.set(footerBytes, offset);

      const response = await client.request(`${AppConfig.API_BASE_URL}/speech/recognize`, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: requestBody,
        connectTimeout: AppConfig.REQUEST_TIMEOUT_MS,
        readTimeout: 30000
      });

      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }

      const bodyStr: string = response.result.toString();
      const result: RecognizeApiResponse = JSON.parse(bodyStr) as RecognizeApiResponse;
      if (result.data && result.data.success) {
        return result.data.text;
      }
      return '';
    } finally {
      client.destroy();
    }
  }

  stopBackendRecording(): void {
    void audioRecorderService.stopRecording();
  }

  cancelBackendRecording(): void {
    audioRecorderService.cancelRecording();
  }

  private deleteAudioFile(filePath: string): void {
    try { fileIo.unlinkSync(filePath); } catch (error) { /* ignore */ }
  }

  private async ensureTtsEngine(): Promise<boolean> {
    if (this.ttsEngine) return true;
    if (!this.isTtsSupported()) return false;
    try {
      this.ttsEngine = await textToSpeech.createEngine({ language: 'zh-CN', person: 0, online: 1 });
      this.ttsEngine.setListener({
        onStart: (_requestId: string, _response: textToSpeech.StartResponse): void => {},
        onComplete: (requestId: string, _response: textToSpeech.CompleteResponse): void => {
          this.handleTtsComplete(requestId);
        },
        onStop: (requestId: string, _response: textToSpeech.StopResponse): void => {
          this.handleTtsComplete(requestId);
        },
        onError: (requestId: string, errorCode: number, errorMessage: string): void => {
          console.error(`语音播报失败 ${errorCode}: ${errorMessage}`);
          this.handleTtsComplete(requestId);
        }
      });
      return true;
    } catch (error) {
      console.error(`初始化语音播报失败: ${JSON.stringify(error)}`);
      this.ttsEngine = null;
      return false;
    }
  }

  private handleTtsComplete(requestId: string): void {
    // 忽略 1 秒内的提前回调（部分引擎/模拟器会立即触发 onComplete/onStop）
    if (requestId !== this.currentTtsRequestId) return;
    if (Date.now() - this.ttsStartTime < 1000) return;
    if (this.ttsCompleteCallback) {
      this.ttsCompleteCallback();
      this.ttsCompleteCallback = null;
    }
  }

  async speak(text: string, onComplete?: () => void): Promise<boolean> {
    const content: string = text.trim();
    if (!content || !(await this.ensureTtsEngine()) || !this.ttsEngine) return false;
    try {
      this.currentTtsRequestId = `tts_${Date.now()}`;
      this.ttsStartTime = Date.now();
      this.ttsCompleteCallback = onComplete ? onComplete : null;
      this.ttsEngine.speak(content, { requestId: this.currentTtsRequestId });
      return true;
    } catch (error) {
      console.error(`语音播报失败: ${JSON.stringify(error)}`);
      if (onComplete) onComplete();
      return false;
    }
  }

  stopSpeak(): void {
    // 清空回调避免旧播报的 onStop/onComplete 误触 UI 重置
    this.ttsCompleteCallback = null;
    if (this.ttsEngine) {
      try { this.ttsEngine.stop(); } catch (error) { console.error(`停止播报失败: ${JSON.stringify(error)}`); }
    }
  }

  release(): void {
    if (this.asrEngine) this.asrEngine.shutdown();
    if (this.ttsEngine) this.ttsEngine.shutdown();
    this.asrEngine = null;
    this.ttsEngine = null;
  }
}

export const speechAiService: SpeechAiService = SpeechAiService.getInstance();
