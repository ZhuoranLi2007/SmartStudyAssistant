import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, FavoriteItem, FavoriteType } from '../model/ProfileModels';
import { HttpClient } from './HttpClient';

export class FavoriteService {
  static async getFavorites(type: FavoriteType): Promise<DataLoadResult<FavoriteItem[]>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<FavoriteItem[]>(ProfileMockData.getFavorites(type));
    try {
      const data: FavoriteItem[] = (await HttpClient.get<FavoriteItem[]>(`/favorites?type=${type}`)).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`收藏接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return ProfileMockData.mockResult<FavoriteItem[]>(ProfileMockData.getFavorites(type));
    }
  }

  static async removeFavorite(id: number): Promise<DataSource> {
    if (!AppConfig.USE_MOCK_DATA) {
      try {
        await HttpClient.delete<Object>(`/favorites/${id}`);
        return DataSource.LIVE;
      } catch (error) {
        console.warn(`取消收藏接口不可用，执行本地演示操作: ${JSON.stringify(error)}`);
      }
    }
    ProfileMockData.removeFavorite(id);
    return DataSource.MOCK;
  }
}
