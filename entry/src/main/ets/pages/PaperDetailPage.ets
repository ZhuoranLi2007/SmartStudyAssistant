import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes, OnlinePracticeRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { Paper, StudyTask } from '../model/DomainModels';
import { DataLoadResult, FavoriteItem } from '../model/ProfileModels';
import { FavoriteService } from '../service/FavoriteService';
import { MockDataService } from '../service/MockDataService';
import { PaperService } from '../service/PaperService';
import { StudyPlanService } from '../service/StudyPlanService';

@Component
export struct PaperDetailPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @Prop paperId: number = 1;
  @State paper: Paper = MockDataService.getPaper(1);
  @State loading: boolean = true;
  @State isAdding: boolean = false;
  @State isAdded: boolean = false;
  @State isFavorite: boolean = false;
  @State favoriteId: number = 0;
  @State favoriteBusy: boolean = false;

  aboutToAppear(): void {
    void this.load();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async load(): Promise<void> {
    this.loading = true;
    try {
      this.paper = await PaperService.getPaper(this.paperId);
    } catch (error) {
      try {
        this.paper = MockDataService.getPaper(this.paperId);
      } catch (_inner) {
        promptAction.showToast({ message: '试卷加载失败' });
      }
    }
    await this.restoreFavorite();
    await this.restorePlanState();
    this.loading = false;
  }

  private async restoreFavorite(): Promise<void> {
    try {
      const item: FavoriteItem | null = await FavoriteService.getPaperFavorite(this.context(), this.paperId);
      this.isFavorite = item !== null;
      this.favoriteId = item === null ? 0 : item.id;
    } catch (error) {
      console.warn(`恢复试卷收藏失败: ${JSON.stringify(error)}`);
    }
  }

  private async restorePlanState(): Promise<void> {
    if (this.studentProfileId <= 0) return;
    try {
      const result: DataLoadResult<StudyTask[]> = await StudyPlanService.getTasks(this.studentProfileId);
      this.isAdded = result.data.some((task: StudyTask) => task.taskType === '试卷' && task.targetId === this.paperId);
    } catch (error) {
      console.warn(`检查试卷计划状态失败: ${JSON.stringify(error)}`);
    }
  }

  private async toggleFavorite(): Promise<void> {
    if (this.favoriteBusy) return;
    if (this.studentProfileId <= 0) {
      promptAction.showToast({ message: '请先创建或绑定学生档案' });
      return;
    }
    this.favoriteBusy = true;
    try {
      if (this.isFavorite) {
        await FavoriteService.removeFavorite(this.context(), this.favoriteId);
        this.isFavorite = false;
        this.favoriteId = 0;
        promptAction.showToast({ message: '已取消收藏' });
      } else {
        const item: FavoriteItem = await FavoriteService.addPaperFavorite(this.context(), this.paper);
        this.isFavorite = true;
        this.favoriteId = item.id;
        promptAction.showToast({ message: '已收藏试卷' });
      }
    } catch (error) {
      const message: string = `${error}`;
      if (message.includes('档案')) {
        promptAction.showToast({ message: '请先完善学生档案后再收藏' });
      } else if (message.includes('HTTP 404')) {
        promptAction.showToast({ message: '收藏服务未就绪，请重启后端后再试' });
      } else {
        promptAction.showToast({ message: '收藏操作失败，请稍后重试' });
      }
      console.error(`试卷收藏失败: ${message}`);
    } finally {
      this.favoriteBusy = false;
    }
  }

  private async addTask(): Promise<void> {
    if (this.isAdding || this.isAdded) return;
    if (this.studentProfileId <= 0) {
      promptAction.showToast({ message: '请先创建或绑定学生档案' });
      return;
    }
    this.isAdding = true;
    try {
      await StudyPlanService.addTask(this.studentProfileId, '试卷', this.paper.id);
      this.isAdded = true;
      promptAction.showToast({ message: '已加入本周训练计划' });
    } catch (error) {
      const message: string = `${error}`.includes('409') ? '该试卷已经在学习计划中' : '添加失败，请稍后重试';
      if (`${error}`.includes('409')) this.isAdded = true;
      promptAction.showToast({ message: message });
    } finally {
      this.isAdding = false;
    }
  }

  private startPractice(): void {
    const param: OnlinePracticeRouteParam = new OnlinePracticeRouteParam();
    param.paperId = this.paper.id;
    this.appPathStack.pushPathByName(AppRoutes.ONLINE_PRACTICE, param);
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '试卷详情' })
        if (this.loading) {
          Text('正在加载试卷...').fontColor('#667085').margin({ top: 40 })
        } else {
          Scroll() {
            Column({ space: 16 }) {
              Image($r('app.media.realImageGen_education_9')).width('100%').height(190).borderRadius(18).objectFit(ImageFit.Cover)
              Text(this.paper.name).fontSize(24).fontWeight(FontWeight.Bold).width('100%')
              Text(`${this.paper.grade} · ${this.paper.subject} · ${this.paper.difficulty}`)
                .fontColor('#2F6BFF').width('100%')
              Text(`题目数量：${this.paper.questionCount}`).width('100%')
              Text(`知识点：${this.paper.knowledgePoints.join('、')}`).width('100%')
              Text(`适用课程：${this.paper.suitableCourseLevel}`).width('100%')
              Text('答错的题目会自动进入错题本，可在学习计划中安排复测。')
                .fontSize(13).fontColor('#667085').width('100%')
                .padding(12).backgroundColor('#EEF4FF').borderRadius(10)
              Button('开始答题').width('100%').height(48).backgroundColor('#2F6BFF')
                .onClick(() => this.startPractice())
              Row({ space: 10 }) {
                Button(this.isFavorite ? '已收藏' : '收藏试卷').layoutWeight(1).height(44)
                  .backgroundColor(this.isFavorite ? '#FEE4E2' : '#F2F4F7')
                  .fontColor(this.isFavorite ? '#D92D20' : '#344054')
                  .enabled(!this.favoriteBusy)
                  .onClick(() => void this.toggleFavorite())
                Button(this.isAdded ? '已在计划' : (this.isAdding ? '添加中...' : '加入训练计划'))
                  .layoutWeight(1).height(44).backgroundColor(this.isAdded ? '#D0D5DD' : '#12B76A')
                  .enabled(!this.isAdding && !this.isAdded)
                  .onClick(() => void this.addTask())
              }.width('100%')
            }.padding(20).width('100%')
          }.layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
