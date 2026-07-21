import { LoginResult } from '../model/DomainModels';
import { HttpClient } from './HttpClient';
import { LoginRequest, RegisterRequest } from './NetworkDtos';

export class AuthService {
  static async login(account: string, password: string): Promise<LoginResult> {
    const request = new LoginRequest();
    request.account = account;
    request.password = password;
    return (await HttpClient.post<LoginResult>('/auth/login', request)).data;
  }

  static async register(username: string, phone: string, password: string): Promise<LoginResult> {
    const request = new RegisterRequest();
    request.username = username;
    request.phone = phone;
    request.password = password;
    request.role = 'user';
    return (await HttpClient.post<LoginResult>('/auth/register', request)).data;
  }
}
