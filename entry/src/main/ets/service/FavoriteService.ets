import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { CourseVideoResolver } from '../common/CourseVideoResolver';
import { ProfileMockData } from '../data/ProfileMockData';
import { Course } from '../model/DomainModels';
import { DataLoadResult, DataSource, FavoriteItem, FavoriteType } from '../model/ProfileModels';

export class FavoriteService {
  private static readonly STORE_NAME: string = 'smartstudy_favorites';

  private static userKey(): string {
    const userId: number = AppStorage.get<number>(AppStorageKeys.USER_ID) || 0;
    return `favorites_${userId}`;
  }

  private static async writeAll(context: common.UIAbilityContext, items: FavoriteItem[]): Promise<void> {
    const store = await preferences.getPreferences(context, { name: FavoriteService.STORE_NAME });
    await store.put(FavoriteService.userKey(), JSON.stringify(items));
    await store.flush();
  }

  private static async readAll(context: common.UIAbilityContext): Promise<FavoriteItem[]> {
    const store = await preferences.getPreferences(context, { name: FavoriteService.STORE_NAME });
    const raw: string = await store.get(FavoriteService.userKey(), '') as string;
    if (!raw) {
      const initial: FavoriteItem[] = ProfileMockData.getAllFavorites();
      await FavoriteService.writeAll(context, initial);
      return initial;
    }
    try {
      return JSON.parse(raw) as FavoriteItem[];
    } catch (error) {
      console.warn(`收藏数据解析失败，恢复演示收藏: ${JSON.stringify(error)}`);
      const fallback: FavoriteItem[] = ProfileMockData.getAllFavorites();
      await FavoriteService.writeAll(context, fallback);
      return fallback;
    }
  }

  static async getFavorites(context: common.UIAbilityContext,
    type: FavoriteType): Promise<DataLoadResult<FavoriteItem[]>> {
    const items: FavoriteItem[] = await FavoriteService.readAll(context);
    return {
      data: items.filter((item: FavoriteItem) => item.type === type),
      source: DataSource.LOCAL,
      message: '收藏保存在当前设备'
    };
  }

  static async getCourseFavorite(context: common.UIAbilityContext, courseId: number): Promise<FavoriteItem | null> {
    const items: FavoriteItem[] = await FavoriteService.readAll(context);
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].type === FavoriteType.COURSE && items[index].targetId === courseId) return items[index];
    }
    return null;
  }

  static async addCourseFavorite(context: common.UIAbilityContext, course: Course): Promise<FavoriteItem> {
    const items: FavoriteItem[] = await FavoriteService.readAll(context);
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].type === FavoriteType.COURSE && items[index].targetId === course.id) return items[index];
    }
    const favoriteId: number = Date.now();
    const item: FavoriteItem = {
      id: favoriteId,
      favoriteId: favoriteId,
      targetId: course.id,
      type: FavoriteType.COURSE,
      title: course.name,
      subtitle: `${course.grade} · ${course.subject}`,
      tag: course.level,
      grade: course.grade,
      subject: course.subject,
      level: course.level,
      coverKey: CourseVideoResolver.previewKey(course),
      createdAt: `${Date.now()}`
    };
    items.push(item);
    await FavoriteService.writeAll(context, items);
    return item;
  }

  static async removeFavorite(context: common.UIAbilityContext, id: number): Promise<DataSource> {
    const items: FavoriteItem[] = await FavoriteService.readAll(context);
    const next: FavoriteItem[] = items.filter((item: FavoriteItem) => item.id !== id);
    await FavoriteService.writeAll(context, next);
    return DataSource.LOCAL;
  }
}
