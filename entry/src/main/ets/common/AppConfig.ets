export class AppConfig {
  static readonly API_BASE_URL: string =
    'http://10.136.23.214:8000/api';

  static readonly USE_MOCK_DATA: boolean = false;
  static readonly ENABLE_SSE: boolean = true;
  static readonly REQUEST_TIMEOUT_MS: number = 30000;
  static readonly AI_STREAM_CONNECT_TIMEOUT_MS: number = 10000;
  static readonly AI_STREAM_READ_TIMEOUT_MS: number = 60000;
}
