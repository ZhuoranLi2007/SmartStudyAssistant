export class AppConfig {
  static readonly API_BASE_URL: string =
    'http://10.130.24.179:8001/api';

  static readonly USE_MOCK_DATA: boolean = false;
  static readonly ENABLE_SSE: boolean = false;
  static readonly REQUEST_TIMEOUT_MS: number = 10000;
}
