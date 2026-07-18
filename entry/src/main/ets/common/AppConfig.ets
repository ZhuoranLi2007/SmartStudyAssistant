export class AppConfig {
  // 模拟器访问电脑后端时，请改为电脑当前局域网 IP。
  static readonly API_BASE_URL: string = 'http://127.0.0.1:8000/api';
  static readonly USE_MOCK_DATA: boolean = true;
  static readonly ENABLE_SSE: boolean = false;
  static readonly REQUEST_TIMEOUT_MS: number = 10000;
}
