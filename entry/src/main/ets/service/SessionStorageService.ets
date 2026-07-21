import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class SessionSnapshot {
  token: string = '';
  userId: number = 0;
  username: string = '';
  role: string = 'user';
  studentProfileId: number = 0;
  profileCompleted: boolean = false;
}

export class SessionStorageService {
  private static readonly STORE_NAME: string = 'smartstudy_session';

  static async save(context: common.UIAbilityContext, snapshot: SessionSnapshot): Promise<void> {
    const store = await preferences.getPreferences(context, { name: SessionStorageService.STORE_NAME });
    await store.put('token', snapshot.token);
    await store.put('userId', snapshot.userId);
    await store.put('username', snapshot.username);
    await store.put('role', snapshot.role);
    await store.put('studentProfileId', snapshot.studentProfileId);
    await store.put('profileCompleted', snapshot.profileCompleted ? 1 : 0);
    await store.flush();
  }

  static async load(context: common.UIAbilityContext): Promise<SessionSnapshot> {
    const store = await preferences.getPreferences(context, { name: SessionStorageService.STORE_NAME });
    const snapshot = new SessionSnapshot();
    snapshot.token = await store.get('token', '') as string;
    snapshot.userId = await store.get('userId', 0) as number;
    snapshot.username = await store.get('username', '') as string;
    snapshot.role = await store.get('role', 'user') as string;
    snapshot.studentProfileId = await store.get('studentProfileId', 0) as number;
    snapshot.profileCompleted = (await store.get('profileCompleted', 0) as number) === 1;
    return snapshot;
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    const store = await preferences.getPreferences(context, { name: SessionStorageService.STORE_NAME });
    await store.clear();
    await store.flush();
  }
}
