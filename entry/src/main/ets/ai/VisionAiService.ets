import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';

export interface VisionOcrResult {
  success: boolean;
  text: string;
  lineCount: number;
  message: string;
}

export class VisionAiService {
  private static initialized: boolean = false;

  static isSupported(): boolean {
    return canIUse('SystemCapability.AI.OCR.TextRecognition');
  }

  private static async ensureInitialized(): Promise<boolean> {
    if (VisionAiService.initialized) return true;
    if (!VisionAiService.isSupported()) return false;
    try {
      VisionAiService.initialized = await textRecognition.init();
      return VisionAiService.initialized;
    } catch (error) {
      console.error(`OCR 初始化失败: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async recognizeText(imageUri: string): Promise<VisionOcrResult> {
    if (!imageUri.trim()) return { success: false, text: '', lineCount: 0, message: '请先选择图片' };
    if (!(await VisionAiService.ensureInitialized())) return { success: false, text: '', lineCount: 0, message: '当前设备不支持 OCR' };
    let source: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      source = image.createImageSource(imageUri);
      pixelMap = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888, editable: false });
      const result = await textRecognition.recognizeText({ pixelMap: pixelMap }, { isDirectionDetectionSupported: true });
      const text: string = result.value.trim();
      const lines: string[] = text ? text.split('\n').filter((line: string) => line.trim().length > 0) : [];
      return text ? { success: true, text: text, lineCount: lines.length, message: `识别成功，共 ${lines.length} 行` } :
        { success: false, text: '', lineCount: 0, message: '未识别到清晰文字，请重新选择图片' };
    } catch (error) {
      console.error(`OCR 识别失败: ${JSON.stringify(error)}`);
      return { success: false, text: '', lineCount: 0, message: '图片读取或 OCR 识别失败' };
    } finally {
      if (pixelMap) await pixelMap.release();
      if (source) await source.release();
    }
  }
}
