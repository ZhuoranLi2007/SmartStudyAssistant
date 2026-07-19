import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class SessionSnapshot {
  token: string = '';
  userId: number = 0;
  username: string = '';
  role: string = 'parent';
  studentProfileId: number = 0;
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
    await store.flush();
  }

  static async load(context: common.UIAbilityContext): Promise<SessionSnapshot> {
    const store = await preferences.getPreferences(context, { name: SessionStorageService.STORE_NAME });
    const snapshot = new SessionSnapshot();
    snapshot.token = await store.get('token', '') as string;
    snapshot.userId = await store.get('userId', 0) as number;
    snapshot.username = await store.get('username', '') as string;
    snapshot.role = await store.get('role', 'parent') as string;
    snapshot.studentProfileId = await store.get('studentProfileId', 0) as number;
    return snapshot;
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    const store = await preferences.getPreferences(context, { name: SessionStorageService.STORE_NAME });
    await store.clear();
    await store.flush();
  }
}
