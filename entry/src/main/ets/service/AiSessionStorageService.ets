import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class AiSessionStorageService {
  private static readonly STORE_NAME: string = 'smartstudy_ai_session';
  private static readonly SESSION_KEY: string = 'latest_session_id';

  static async save(context: common.UIAbilityContext, sessionId: string): Promise<void> {
    const store = await preferences.getPreferences(context, { name: AiSessionStorageService.STORE_NAME });
    await store.put(AiSessionStorageService.SESSION_KEY, sessionId);
    await store.flush();
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    const store = await preferences.getPreferences(context, { name: AiSessionStorageService.STORE_NAME });
    return await store.get(AiSessionStorageService.SESSION_KEY, '') as string;
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    const store = await preferences.getPreferences(context, { name: AiSessionStorageService.STORE_NAME });
    await store.delete(AiSessionStorageService.SESSION_KEY);
    await store.flush();
  }
}
