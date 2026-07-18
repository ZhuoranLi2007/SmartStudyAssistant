import { http } from '@kit.NetworkKit';
import { AppConfig } from '../common/AppConfig';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { ApiResponse } from '../model/DomainModels';

class RequestHeaders {
  'Content-Type': string = 'application/json';
  Authorization: string = '';
}

export class HttpClient {
  static async get<T>(path: string): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(path, http.RequestMethod.GET);
  }

  static async post<T>(path: string, body: Object): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(path, http.RequestMethod.POST, body);
  }

  static async put<T>(path: string, body: Object): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(path, http.RequestMethod.PUT, body);
  }

  static async delete<T>(path: string): Promise<ApiResponse<T>> {
    return HttpClient.request<T>(path, http.RequestMethod.DELETE);
  }

  private static async request<T>(path: string, method: http.RequestMethod, body?: Object): Promise<ApiResponse<T>> {
    const client = http.createHttp();
    const token: string = AppStorage.get<string>(AppStorageKeys.AUTH_TOKEN) || '';
    const headers: RequestHeaders = new RequestHeaders();
    if (token) headers.Authorization = `Bearer ${token}`;
    try {
      const response = await client.request(`${AppConfig.API_BASE_URL}${path}`, {
        method: method,
        header: headers,
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: AppConfig.REQUEST_TIMEOUT_MS,
        readTimeout: AppConfig.REQUEST_TIMEOUT_MS
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}: ${response.result.toString()}`);
      }
      return JSON.parse(response.result.toString()) as ApiResponse<T>;
    } finally {
      client.destroy();
    }
  }
}
