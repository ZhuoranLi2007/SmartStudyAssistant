import { AppConfig } from '../common/AppConfig';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { CourseVideoResolver } from '../common/CourseVideoResolver';
import { ProfileMockData } from '../data/ProfileMockData';
import { Course, Paper } from '../model/DomainModels';
import { DataLoadResult, DataSource, FavoriteItem, FavoriteType } from '../model/ProfileModels';
import { HttpClient } from './HttpClient';

export class FavoriteService {
  private static studentId(): number {
    return AppStorage.get<number>(AppStorageKeys.STUDENT_PROFILE_ID) || 0;
  }

  private static toFavoriteType(raw: string): FavoriteType {
    const value: string = `${raw}`.toUpperCase();
    if (value === 'PAPER') return FavoriteType.PAPER;
    if (value === 'KNOWLEDGE') return FavoriteType.KNOWLEDGE;
    return FavoriteType.COURSE;
  }

  private static withCover(item: FavoriteItem): FavoriteItem {
    const type: FavoriteType = FavoriteService.toFavoriteType(`${item.type}`);
    let coverKey: string = item.coverKey || '';
    const grade: string = item.grade || '';
    const subject: string = item.subject || '';
    const level: string = item.level || item.tag || '';
    if (type === FavoriteType.COURSE && coverKey.length === 0) {
      const course: Course = {
        id: item.targetId,
        name: item.title || '',
        grade: grade,
        subject: subject,
        level: level,
        difficulty: '',
        suitableFor: '',
        knowledgePoints: [],
        description: '',
        price: 0,
        totalLessons: 0
      };
      coverKey = CourseVideoResolver.previewKey(course);
    }
    return {
      id: item.id || item.favoriteId || 0,
      favoriteId: item.favoriteId || item.id || 0,
      targetId: item.targetId,
      type: type,
      title: item.title || '',
      subtitle: item.subtitle || '',
      tag: item.tag || '',
      grade: grade,
      subject: subject,
      level: level,
      coverKey: coverKey,
      createdAt: item.createdAt || ''
    };
  }

  static async getFavorites(_context: Object, type: FavoriteType): Promise<DataLoadResult<FavoriteItem[]>> {
    if (type === FavoriteType.KNOWLEDGE) {
      return { data: [], source: DataSource.LIVE, message: '' };
    }
    const studentId: number = FavoriteService.studentId();
    if (AppConfig.USE_MOCK_DATA || studentId <= 0) {
      return { data: [], source: DataSource.LIVE, message: '请先完善学生档案' };
    }
    try {
      const apiType: string = type === FavoriteType.PAPER ? 'paper' : 'course';
      const data: FavoriteItem[] = (await HttpClient.get<FavoriteItem[]>(
        `/favorites?student_profile_id=${studentId}&type=${apiType}`
      )).data;
      const mapped: FavoriteItem[] = [];
      const source: FavoriteItem[] = data || [];
      for (let index: number = 0; index < source.length; index++) {
        mapped.push(FavoriteService.withCover(source[index]));
      }
      return { data: mapped, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`收藏接口不可用: ${JSON.stringify(error)}`);
      return { data: [], source: DataSource.LIVE, message: '收藏加载失败' };
    }
  }

  static async getCourseFavorite(_context: Object, courseId: number): Promise<FavoriteItem | null> {
    const result: DataLoadResult<FavoriteItem[]> = await FavoriteService.getFavorites(_context, FavoriteType.COURSE);
    for (let index: number = 0; index < result.data.length; index++) {
      if (result.data[index].targetId === courseId) return result.data[index];
    }
    return null;
  }

  static async getPaperFavorite(_context: Object, paperId: number): Promise<FavoriteItem | null> {
    const result: DataLoadResult<FavoriteItem[]> = await FavoriteService.getFavorites(_context, FavoriteType.PAPER);
    for (let index: number = 0; index < result.data.length; index++) {
      if (result.data[index].targetId === paperId) return result.data[index];
    }
    return null;
  }

  static async addCourseFavorite(_context: Object, course: Course): Promise<FavoriteItem> {
    const studentId: number = FavoriteService.studentId();
    if (studentId <= 0) {
      throw new Error('请先完善学生档案后再收藏');
    }
    if (AppConfig.USE_MOCK_DATA) {
      throw new Error('当前为演示模式，无法同步收藏');
    }
    const item: FavoriteItem = (await HttpClient.post<FavoriteItem>(
      `/favorites?student_profile_id=${studentId}&target_id=${course.id}&type=course`,
      new Object()
    )).data;
    if (!item || !(item.id || item.favoriteId)) {
      throw new Error('收藏接口返回异常');
    }
    return FavoriteService.withCover(item);
  }

  static async addPaperFavorite(_context: Object, paper: Paper): Promise<FavoriteItem> {
    const studentId: number = FavoriteService.studentId();
    if (studentId <= 0) {
      throw new Error('请先完善学生档案后再收藏');
    }
    if (AppConfig.USE_MOCK_DATA) {
      throw new Error('当前为演示模式，无法同步收藏');
    }
    const item: FavoriteItem = (await HttpClient.post<FavoriteItem>(
      `/favorites?student_profile_id=${studentId}&target_id=${paper.id}&type=paper`,
      new Object()
    )).data;
    if (!item || !(item.id || item.favoriteId)) {
      throw new Error('收藏接口返回异常');
    }
    return FavoriteService.withCover(item);
  }

  static async removeFavorite(_context: Object, id: number): Promise<DataSource> {
    if (AppConfig.USE_MOCK_DATA) {
      ProfileMockData.removeFavorite(id);
      return DataSource.MOCK;
    }
    if (id <= 0) {
      throw new Error('收藏记录无效');
    }
    await HttpClient.delete<boolean>(`/favorites/${id}`);
    return DataSource.LIVE;
  }
}
