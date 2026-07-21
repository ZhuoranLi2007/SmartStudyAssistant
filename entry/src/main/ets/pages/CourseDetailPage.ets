import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { CourseBasicInfo } from '../components/course/CourseBasicInfo';
import { CourseBottomBar } from '../components/course/CourseBottomBar';
import { CourseContentSections } from '../components/course/CourseContentSections';
import { CourseDetailHeader } from '../components/course/CourseDetailHeader';
import { CourseOutline } from '../components/course/CourseOutline';
import { CourseReviews } from '../components/course/CourseReviews';
import { CourseTeacherCard } from '../components/course/CourseTeacherCard';
import { CourseVideoSection } from '../components/course/CourseVideoSection';
import { CourseDetailMockData } from '../data/CourseDetailMockData';
import { CourseDetailData } from '../model/CourseDetailModels';
import { Course, StudyTask } from '../model/DomainModels';
import { DataLoadResult, DataSource, FavoriteItem } from '../model/ProfileModels';
import { CourseDetailService } from '../service/CourseDetailService';
import { FavoriteService } from '../service/FavoriteService';
import { MockDataService } from '../service/MockDataService';
import { StudyPlanService } from '../service/StudyPlanService';

@Component
export struct CourseDetailPage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @Prop courseId: number = 1;
  @State detail: CourseDetailData = CourseDetailMockData.build(MockDataService.getCourse(1));
  @State dataSource: DataSource = DataSource.MOCK;
  @State isLoading: boolean = false;
  @State loadError: string = '';
  @State outlineExpanded: boolean = false;
  @State isFavorite: boolean = false;
  @State favoriteId: number = 0;
  @State favoriteBusy: boolean = false;
  @State isAdding: boolean = false;
  @State isAdded: boolean = false;

  aboutToAppear(): void {
    void this.initialize();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async initialize(): Promise<void> {
    if (this.isLoading) return;
    const local: Course | null = CourseDetailService.localCourse(this.courseId);
    if (local === null) {
      this.loadError = '课程信息不存在或路由参数无效';
      return;
    }
    this.detail = CourseDetailMockData.build(local);
    this.loadError = '';
    this.isLoading = true;
    try {
      const result: DataLoadResult<CourseDetailData> = await CourseDetailService.load(this.courseId);
      this.detail = result.data;
      this.dataSource = result.source;
      await this.restoreFavorite();
      await this.restorePlanState();
    } catch (error) {
      this.loadError = `课程加载失败：${error}`;
    } finally {
      this.isLoading = false;
    }
  }

  private async restoreFavorite(): Promise<void> {
    try {
      const item: FavoriteItem | null = await FavoriteService.getCourseFavorite(this.context(), this.courseId);
      this.isFavorite = item !== null;
      this.favoriteId = item === null ? 0 : item.id;
    } catch (error) {
      console.warn(`恢复收藏状态失败: ${JSON.stringify(error)}`);
    }
  }

  private async restorePlanState(): Promise<void> {
    if (this.studentProfileId <= 0) {
      this.isAdded = false;
      return;
    }
    try {
      const result: DataLoadResult<StudyTask[]> = await StudyPlanService.getTasks(this.studentProfileId);
      this.isAdded = result.data.some((task: StudyTask) => task.taskType === '课程' && task.targetId === this.courseId);
    } catch (error) {
      console.warn(`检查学习计划状态失败: ${JSON.stringify(error)}`);
    }
  }

  private async toggleFavorite(): Promise<void> {
    if (this.favoriteBusy || this.loadError) return;
    this.favoriteBusy = true;
    try {
      if (this.isFavorite) {
        await FavoriteService.removeFavorite(this.context(), this.favoriteId);
        this.isFavorite = false;
        this.favoriteId = 0;
        promptAction.showToast({ message: '已取消收藏' });
      } else {
        const item: FavoriteItem = await FavoriteService.addCourseFavorite(this.context(), this.detail.course);
        this.isFavorite = true;
        this.favoriteId = item.id;
        promptAction.showToast({ message: '已收藏课程' });
      }
    } catch (error) {
      promptAction.showToast({ message: '收藏操作失败，请稍后重试' });
    } finally {
      this.favoriteBusy = false;
    }
  }

  private async addTask(): Promise<void> {
    if (this.isAdding || this.isAdded || this.role !== 'parent') return;
    if (this.studentProfileId <= 0) {
      promptAction.showToast({ message: '请先创建或绑定学生档案' });
      return;
    }
    this.isAdding = true;
    try {
      await StudyPlanService.addTask(this.studentProfileId, '课程', this.detail.course.id);
      this.isAdded = true;
      promptAction.showToast({ message: '已加入本周学习计划' });
    } catch (error) {
      if (`${error}`.includes('409')) {
        this.isAdded = true;
        promptAction.showToast({ message: '该课程已在学习计划中' });
      } else {
        promptAction.showToast({ message: '添加失败，请稍后重试' });
      }
    } finally {
      this.isAdding = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        CourseDetailHeader({
          isFavorite: this.isFavorite,
          favoriteBusy: this.favoriteBusy,
          onToggleFavorite: () => void this.toggleFavorite()
        })
        if (this.loadError) {
          Column({ space: 14 }) {
            Text('课程暂时无法打开').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033')
            Text(this.loadError).fontSize(13).fontColor('#667085').textAlign(TextAlign.Center)
            Button('重新加载').backgroundColor('#2F6BFF').onClick(() => void this.initialize())
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).padding(24)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              CourseVideoSection({ course: this.detail.course })
              CourseBasicInfo({ detail: this.detail })
              CourseTeacherCard({ teacher: this.detail.teacher })
              CourseContentSections({ detail: this.detail })
              CourseOutline({
                items: this.detail.outline,
                expanded: this.outlineExpanded,
                onToggle: () => this.outlineExpanded = !this.outlineExpanded
              })
              CourseReviews({ rating: this.detail.rating, reviewCount: this.detail.reviewCount, reviews: this.detail.reviews })
              if (this.dataSource === DataSource.MOCK) {
                Text('价格与课程基础信息优先来自服务端，其余介绍内容为演示数据')
                  .fontSize(10).fontColor('#98A2B3').textAlign(TextAlign.Center).width('100%')
              }
            }.padding({ left: 16, right: 16, top: 12, bottom: 20 }).width('100%')
          }.layoutWeight(1).width('100%')
          CourseBottomBar({
            role: this.role,
            isFavorite: this.isFavorite,
            favoriteBusy: this.favoriteBusy,
            isAdding: this.isAdding,
            isAdded: this.isAdded,
            onToggleFavorite: () => void this.toggleFavorite(),
            onAddPlan: () => void this.addTask()
          })
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
