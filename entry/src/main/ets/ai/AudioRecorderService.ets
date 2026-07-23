import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';

export type RecordingResultHandler = (filePath: string) => void;
export type RecordingErrorHandler = (message: string) => void;

class AudioRecorderService {
  private static instance: AudioRecorderService;
  private audioCapturer: audio.AudioCapturer | null = null;
  private outputPath: string = '';
  private outputFd: number = -1;
  private isRecordingFlag: boolean = false;
  private resultHandler: RecordingResultHandler | null = null;
  private errorHandler: RecordingErrorHandler | null = null;
  private writeTask: Promise<void> | null = null;
  private maxDurationMs: number = 60000;

  static getInstance(): AudioRecorderService {
    if (!AudioRecorderService.instance) {
      AudioRecorderService.instance = new AudioRecorderService();
    }
    return AudioRecorderService.instance;
  }

  setMaxDuration(ms: number): void {
    this.maxDurationMs = ms;
  }

  isRecordingSupported(): boolean {
    return canIUse('SystemCapability.Multimedia.Audio.Capturer');
  }

  async startRecording(context: common.UIAbilityContext, onResult: RecordingResultHandler,
    onError?: RecordingErrorHandler): Promise<boolean> {
    if (this.isRecordingFlag) return false;
    this.resultHandler = onResult;
    this.errorHandler = onError || null;
    try {
      const cacheDir: string = context.cacheDir;
      this.outputPath = `${cacheDir}/speech_${Date.now()}.wav`;
      console.info(`AudioRecorder: 输出路径=${this.outputPath}`);
      const file: fileIo.File = fileIo.openSync(this.outputPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      this.outputFd = file.fd;

      const audioStreamParams: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      // 优先使用语音识别源，降级到麦克风源
      const sourceTypes: audio.SourceType[] = [
        audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
        audio.SourceType.SOURCE_TYPE_MIC
      ];
      let capturer: audio.AudioCapturer | null = null;
      for (const sourceType of sourceTypes) {
        try {
          const capturerOptions: audio.AudioCapturerOptions = {
            streamInfo: audioStreamParams,
            capturerInfo: { source: sourceType, capturerFlags: 0 }
          };
          console.info(`AudioRecorder: 尝试创建 AudioCapturer, sourceType=${sourceType}`);
          capturer = await audio.createAudioCapturer(capturerOptions);
          console.info(`AudioRecorder: AudioCapturer 创建成功, 尝试 start()`);
          await capturer.start();
          console.info(`AudioRecorder: AudioCapturer 使用源类型 ${sourceType} 启动成功`);
          break;
        } catch (sourceError) {
          console.warn(`AudioRecorder: 源类型 ${sourceType} 启动失败: ${JSON.stringify(sourceError)}`);
          if (capturer) {
            try { capturer.release(); } catch (e) { /* ignore */ }
          }
          capturer = null;
        }
      }
      if (!capturer) throw new Error('所有音频源类型均启动失败');

      this.audioCapturer = capturer;
      this.isRecordingFlag = true;
      this.writeTask = this.writePcmToWav();
      return true;
    } catch (error) {
      const err: Error = error as Error;
      console.error(`启动录音失败: ${err.message}`);
      this.releaseCapturer();
      if (this.errorHandler) this.errorHandler(`启动录音失败: ${err.message}`);
      return false;
    }
  }

  private async writePcmToWav(): Promise<void> {
    if (!this.audioCapturer) return;
    const bufferSize: number = 3200; // 100ms @ 16kHz 16bit mono
    const sampleRate: number = 16000;
    const channels: number = 1;
    const bitsPerSample: number = 16;
    const pcmChunks: ArrayBuffer[] = [];
    let totalBytes: number = 0;
    let readCount: number = 0;
    const maxBytes: number = Math.floor(this.maxDurationMs / 1000 * sampleRate * channels * bitsPerSample / 8);

    try {
      while (this.isRecordingFlag && totalBytes < maxBytes) {
        const chunk: ArrayBuffer = await this.audioCapturer.read(bufferSize, true);
        if (chunk && chunk.byteLength > 0) {
          pcmChunks.push(chunk);
          totalBytes += chunk.byteLength;
          readCount++;
        }
      }
    } catch (error) {
      const err: Error = error as Error;
      if (this.isRecordingFlag) {
        console.error(`读取PCM数据失败: ${err.message}`);
      }
    }

    if (totalBytes === 0) {
      if (this.errorHandler) this.errorHandler('录音数据为空，请检查麦克风是否正常');
      return;
    }
    if (totalBytes < 3200) {
      if (this.errorHandler) this.errorHandler('录音时间过短，请说话至少1秒');
      return;
    }

    // 检查音频能量，判断是否录制到有效声音
    let maxAmplitude: number = 0;
    for (const chunk of pcmChunks) {
      const dv: DataView = new DataView(chunk);
      for (let i: number = 0; i < dv.byteLength - 1; i += 2) {
        const sample: number = dv.getInt16(i, true);
        const abs: number = sample < 0 ? -sample : sample;
        if (abs > maxAmplitude) maxAmplitude = abs;
      }
    }
    console.info(`录音完成: ${totalBytes} 字节, ${readCount} 次读取, 最大振幅=${maxAmplitude}`);
    if (maxAmplitude < 50) {
      if (this.errorHandler) this.errorHandler('检测到声音过小，请靠近麦克风大声说话');
      return;
    }

    // 写入 WAV 文件
    const dataSize: number = totalBytes;
    const fileSize: number = 44 + dataSize;
    const wavBuffer: ArrayBuffer = new ArrayBuffer(fileSize);
    const wavView: DataView = new DataView(wavBuffer);
    this.writeWavHeader(wavView, sampleRate, channels, bitsPerSample, dataSize);
    let offset: number = 44;
    for (const chunk of pcmChunks) {
      const src: Uint8Array = new Uint8Array(chunk);
      const dst: Uint8Array = new Uint8Array(wavBuffer);
      dst.set(src, offset);
      offset += chunk.byteLength;
    }

    try {
      fileIo.writeSync(this.outputFd, wavBuffer);
      fileIo.closeSync(this.outputFd);
      this.outputFd = -1;
    } catch (error) {
      const err: Error = error as Error;
      console.error(`写入WAV文件失败: ${err.message}`);
      this.deleteOutputFile();
      return;
    }

    const path: string = this.outputPath;
    this.outputPath = '';
    if (this.resultHandler) {
      this.resultHandler(path);
    }
  }

  private writeWavHeader(view: DataView, sampleRate: number, channels: number,
    bitsPerSample: number, dataSize: number): void {
    const byteRate: number = sampleRate * channels * bitsPerSample / 8;
    const blockAlign: number = channels * bitsPerSample / 8;
    this.writeString(view, 0, 'RIFF');
    view.setUint32(4, 36 + dataSize, true);
    this.writeString(view, 8, 'WAVE');
    this.writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, channels, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, byteRate, true);
    view.setUint16(32, blockAlign, true);
    view.setUint16(34, bitsPerSample, true);
    this.writeString(view, 36, 'data');
    view.setUint32(40, dataSize, true);
  }

  private writeString(view: DataView, offset: number, str: string): void {
    for (let i: number = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  }

  async stopRecording(): Promise<string> {
    if (!this.isRecordingFlag) return '';
    this.isRecordingFlag = false;
    try {
      if (this.audioCapturer) {
        await this.audioCapturer.stop();
      }
      if (this.writeTask) {
        await this.writeTask;
        this.writeTask = null;
      }
      if (this.audioCapturer) {
        await this.audioCapturer.release();
        this.audioCapturer = null;
      }
      if (this.outputFd >= 0) {
        fileIo.closeSync(this.outputFd);
        this.outputFd = -1;
      }
      return this.outputPath;
    } catch (error) {
      const err: Error = error as Error;
      console.error(`停止录音失败: ${err.message}`);
      this.releaseCapturer();
      return '';
    }
  }

  cancelRecording(): void {
    if (!this.isRecordingFlag) return;
    this.isRecordingFlag = false;
    try {
      if (this.audioCapturer) {
        this.audioCapturer.stop();
        this.audioCapturer.release();
        this.audioCapturer = null;
      }
    } catch (error) {
      const err: Error = error as Error;
      console.error(`取消录音失败: ${err.message}`);
    }
    this.releaseCapturer();
    this.deleteOutputFile();
  }

  private releaseCapturer(): void {
    if (this.audioCapturer) {
      try { this.audioCapturer.release(); } catch (error) { /* ignore */ }
      this.audioCapturer = null;
    }
    if (this.outputFd >= 0) {
      try { fileIo.closeSync(this.outputFd); } catch (error) { /* ignore */ }
      this.outputFd = -1;
    }
    this.writeTask = null;
  }

  private deleteOutputFile(): void {
    if (this.outputPath) {
      try { fileIo.unlinkSync(this.outputPath); } catch (error) { /* ignore */ }
      this.outputPath = '';
    }
  }
}

export const audioRecorderService: AudioRecorderService = AudioRecorderService.getInstance();