import { common } from '@kit.AbilityKit';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { SessionStorageService } from './SessionStorageService';

export class AuthSessionService {
  static async clear(context: common.UIAbilityContext): Promise<void> {
    AppStorage.setOrCreate<string>(AppStorageKeys.AUTH_TOKEN, '');
    AppStorage.setOrCreate<number>(AppStorageKeys.USER_ID, 0);
    AppStorage.setOrCreate<string>(AppStorageKeys.USERNAME, '');
    AppStorage.setOrCreate<string>(AppStorageKeys.USER_ROLE, 'parent');
    AppStorage.setOrCreate<number>(AppStorageKeys.STUDENT_PROFILE_ID, 0);
    await SessionStorageService.clear(context);
  }
}
