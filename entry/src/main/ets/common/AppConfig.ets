export class AppConfig {
  static readonly API_BASE_URL: string =
    'http://10.132.159.6:8000/api';

  static readonly USE_MOCK_DATA: boolean = false;
  static readonly ENABLE_SSE: boolean = true;
  static readonly REQUEST_TIMEOUT_MS: number = 10000;
}
