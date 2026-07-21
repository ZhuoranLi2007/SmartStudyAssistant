import { promptAction } from '@kit.ArkUI';
import { AppConfig } from '../common/AppConfig';
import { AppRoutes, IdRouteParam, OnlinePracticeRouteParam, WrongQuestionTrainingRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { MainTabBar } from '../components/MainTabBar';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { StudyPlanSummaryCard } from '../components/studyplan/StudyPlanSummaryCard';
import { StudyTaskCard } from '../components/studyplan/StudyTaskCard';
import { WeekDateStrip } from '../components/studyplan/WeekDateStrip';
import { StudentProfile, StudyTask, TaskStatus } from '../model/DomainModels';
import { DataLoadResult, DataSource } from '../model/ProfileModels';
import { StudyPlanFilter, WeekDayItem } from '../model/StudyPlanModels';
import { MockDataService } from '../service/MockDataService';
import { StudentService } from '../service/StudentService';
import { StudyPlanService } from '../service/StudyPlanService';

@Component
export struct StudyPlanPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @State tasks: StudyTask[] = [];
  @State weekDays: WeekDayItem[] = [];
  @State studentName: string = '';
  @State selectedDate: string = '';
  @State filter: StudyPlanFilter = StudyPlanFilter.WEEK;
  @State source: DataSource = DataSource.LIVE;
  @State sourceMessage: string = '';
  @State isLoading: boolean = false;
  @State operatingTaskId: number = 0;
  @State summaryTotal: number = 0;
  @State summaryCompleted: number = 0;
  @State summaryCourse: number = 0;
  @State summaryPaper: number = 0;
  @State summaryProgress: number = 0;
  @State summaryWeekLabel: string = '';

  aboutToAppear(): void {
    this.weekDays = this.createWeekDays();
    this.selectedDate = this.todayIso();
    void this.loadData();
  }

  private isoDate(value: Date): string {
    const month: string = `${value.getMonth() + 1}`.padStart(2, '0');
    const day: string = `${value.getDate()}`.padStart(2, '0');
    return `${value.getFullYear()}-${month}-${day}`;
  }

  private todayIso(): string {
    return this.isoDate(new Date());
  }

  private createWeekDays(): WeekDayItem[] {
    const today = new Date();
    const mondayOffset: number = today.getDay() === 0 ? -6 : 1 - today.getDay();
    const labels: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const result: WeekDayItem[] = [];
    for (let index: number = 0; index < 7; index++) {
      const value = new Date(today.getFullYear(), today.getMonth(), today.getDate() + mondayOffset + index);
      const date: string = this.isoDate(value);
      result.push({ date: date, dayLabel: labels[index], dateLabel: `${value.getDate()}`, isToday: date === this.todayIso() });
    }
    return result;
  }

  private async loadData(): Promise<void> {
    if (this.isLoading) return;
    if (this.studentProfileId <= 0 && !AppConfig.USE_MOCK_DATA) {
      this.tasks = [];
      this.studentName = '';
      this.refreshSummary();
      return;
    }
    this.isLoading = true;
    try {
      try {
        const profile: StudentProfile = await StudentService.getProfile(this.studentProfileId);
        this.studentName = profile.name;
      } catch (error) {
        this.studentName = MockDataService.getStudentProfile().name;
        this.source = DataSource.MOCK;
      }
      const taskResult: DataLoadResult<StudyTask[]> = await StudyPlanService.getTasks(this.studentProfileId);
      this.tasks = taskResult.data;
      if (taskResult.source === DataSource.MOCK) {
        this.source = DataSource.MOCK;
        this.sourceMessage = taskResult.message;
      } else {
        this.source = DataSource.LIVE;
        this.sourceMessage = '';
      }
    } catch (error) {
      console.error(`学习计划加载失败: ${JSON.stringify(error)}`);
      this.tasks = MockDataService.getTasks();
      this.studentName = MockDataService.getStudentProfile().name;
      this.source = DataSource.MOCK;
      this.sourceMessage = '加载失败，当前展示演示学习计划';
    } finally {
      this.isLoading = false;
      this.refreshSummary();
    }
  }

  private taskDateKey(value: string): string {
    if (!value) return '';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  private weekLabel(): string {
    if (this.weekDays.length < 7) return '';
    return `${this.weekDays[0].date.substring(5).split('-').join('.')} - ${this.weekDays[6].date.substring(5).split('-').join('.')}`;
  }

  private weekTasks(): StudyTask[] {
    if (this.weekDays.length < 7) return this.tasks.slice();
    const start: string = this.weekDays[0].date;
    const end: string = this.weekDays[6].date;
    return this.tasks.filter((task: StudyTask) => {
      const dateKey: string = this.taskDateKey(task.scheduledDate);
      if (!dateKey) return true;
      return dateKey >= start && dateKey <= end;
    });
  }

  private visibleTasks(): StudyTask[] {
    const weekly: StudyTask[] = this.weekTasks();
    if (this.filter === StudyPlanFilter.TODAY) {
      return weekly.filter((task: StudyTask) => this.taskDateKey(task.scheduledDate) === this.selectedDate);
    }
    if (this.filter === StudyPlanFilter.COMPLETED) {
      return weekly.filter((task: StudyTask) => task.status === TaskStatus.COMPLETED);
    }
    return weekly;
  }

  private refreshSummary(): void {
    const weekly: StudyTask[] = this.weekTasks();
    let completed: number = 0;
    let courseCount: number = 0;
    let paperCount: number = 0;
    for (let index: number = 0; index < weekly.length; index++) {
      const task: StudyTask = weekly[index];
      if (task.status === TaskStatus.COMPLETED) completed++;
      if (task.taskType === '试卷') paperCount++;
      else if (task.taskType !== '错题') courseCount++;
    }
    this.summaryTotal = weekly.length;
    this.summaryCompleted = completed;
    this.summaryCourse = courseCount;
    this.summaryPaper = paperCount;
    this.summaryProgress = weekly.length > 0 ? Math.round(completed * 100 / weekly.length) : 0;
    this.summaryWeekLabel = this.weekLabel();
  }

  private openTask(task: StudyTask): void {
    if (task.targetId <= 0) {
      promptAction.showToast({ message: '任务关联内容暂不可用' });
      return;
    }
    if (task.taskType === '错题') {
      const wrongParam: WrongQuestionTrainingRouteParam = new WrongQuestionTrainingRouteParam();
      wrongParam.wrongQuestionId = task.targetId;
      wrongParam.taskId = task.id;
      this.appPathStack.pushPathByName(AppRoutes.WRONG_QUESTION_TRAINING, wrongParam);
      return;
    }
    const param: IdRouteParam = new IdRouteParam();
    param.id = task.targetId;
    this.appPathStack.pushPathByName(task.taskType === '试卷' ? AppRoutes.PAPER_DETAIL : AppRoutes.COURSE_DETAIL, param);
  }

  private async startTask(task: StudyTask): Promise<void> {
    if (this.operatingTaskId > 0) return;
    this.operatingTaskId = task.id;
    try {
      if (task.status === TaskStatus.NOT_STARTED) {
        await StudyPlanService.updateStatus(task.id, TaskStatus.IN_PROGRESS);
      }
      if (task.taskType === '试卷') {
        const param: OnlinePracticeRouteParam = new OnlinePracticeRouteParam();
        param.paperId = task.targetId;
        param.taskId = task.id;
        this.appPathStack.pushPathByName(AppRoutes.ONLINE_PRACTICE, param);
      } else if (task.taskType === '错题') {
        const param: WrongQuestionTrainingRouteParam = new WrongQuestionTrainingRouteParam();
        param.wrongQuestionId = task.targetId;
        param.taskId = task.id;
        this.appPathStack.pushPathByName(AppRoutes.WRONG_QUESTION_TRAINING, param);
      } else {
        this.openTask(task);
      }
      await this.loadData();
    } catch (error) {
      promptAction.showToast({ message: '任务启动失败，请检查网络后重试' });
    } finally {
      this.operatingTaskId = 0;
    }
  }

  private async completeTask(task: StudyTask): Promise<void> {
    if (this.operatingTaskId > 0) return;
    this.operatingTaskId = task.id;
    try {
      await StudyPlanService.updateStatus(task.id, TaskStatus.COMPLETED);
      promptAction.showToast({ message: '学习任务已完成' });
      await this.loadData();
    } catch (error) {
      promptAction.showToast({ message: '状态更新失败，请稍后重试' });
    } finally {
      this.operatingTaskId = 0;
    }
  }

  private confirmDelete(task: StudyTask): void {
    AlertDialog.show({
      title: '删除学习任务', message: `确定删除“${task.name}”吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '确定删除', fontColor: '#D92D20', action: () => void this.deleteTask(task) }
    });
  }

  private async deleteTask(task: StudyTask): Promise<void> {
    if (this.operatingTaskId > 0) return;
    this.operatingTaskId = task.id;
    try {
      await StudyPlanService.deleteTask(task.id);
      promptAction.showToast({ message: '任务已删除' });
      await this.loadData();
    } catch (error) {
      promptAction.showToast({ message: '删除失败，请稍后重试' });
    } finally {
      this.operatingTaskId = 0;
    }
  }

  @Builder
  private filterButton(label: string, value: StudyPlanFilter) {
    Button(label).layoutWeight(1).height(36).fontSize(12)
      .backgroundColor(this.filter === value ? '#2F6BFF' : Color.White)
      .fontColor(this.filter === value ? Color.White : '#475467')
      .onClick(() => this.filter = value)
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 14 }) {
            Row() {
              Column({ space: 3 }) {
                Text('学习计划').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#172033')
                Text('按计划完成每天的学习任务').fontSize(12).fontColor('#667085')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Text(this.isLoading ? '加载中' : '刷新').fontSize(13).fontColor('#2F6BFF')
                .onClick(() => { if (!this.isLoading) void this.loadData(); })
            }.width('100%')

            if (this.studentProfileId <= 0 && !AppConfig.USE_MOCK_DATA) {
              EmptyStateView({ title: '尚未绑定学生档案', description: '创建或绑定学生档案后，才能安排正式学习计划' })
              Button('创建或查看学生档案').width('100%').height(44).backgroundColor('#2F6BFF')
                .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
            } else {
              StudyPlanSummaryCard({
                studentName: this.studentName,
                weekLabel: this.summaryWeekLabel,
                totalCount: this.summaryTotal,
                completedCount: this.summaryCompleted,
                courseCount: this.summaryCourse,
                paperCount: this.summaryPaper,
                progress: this.summaryProgress
              })
              Row({ space: 8 }) {
                this.filterButton('今日', StudyPlanFilter.TODAY)
                this.filterButton('本周', StudyPlanFilter.WEEK)
                this.filterButton('已完成', StudyPlanFilter.COMPLETED)
              }.padding(4).width('100%').backgroundColor('#E9EEF8').borderRadius(12)
              WeekDateStrip({
                days: this.weekDays,
                selectedDate: this.selectedDate,
                onSelect: (date: string): void => { this.selectedDate = date; this.filter = StudyPlanFilter.TODAY; }
              })
              Row() {
                Text(this.filter === StudyPlanFilter.WEEK ? '本周任务' : this.filter === StudyPlanFilter.COMPLETED ? '已完成任务' : '当日任务')
                  .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').layoutWeight(1)
                Text(`${this.visibleTasks().length} 项`).fontSize(12).fontColor('#667085')
              }.width('100%')
              if (this.isLoading && this.tasks.length === 0) {
                Text('正在加载学习计划...').fontSize(13).fontColor('#667085').padding(30).width('100%').textAlign(TextAlign.Center)
              } else if (this.visibleTasks().length === 0) {
                EmptyStateView({ title: '暂无学习任务', description: '可从首页「查看课程」「试卷训练」加入计划' })
              } else {
                ForEach(this.visibleTasks(), (task: StudyTask) => {
                  StudyTaskCard({
                    task: task,
                    operating: this.operatingTaskId === task.id,
                    onOpen: (value: StudyTask): void => this.openTask(value),
                    onStart: (value: StudyTask): void => { void this.startTask(value); },
                    onComplete: (value: StudyTask): void => { void this.completeTask(value); },
                    onDelete: (value: StudyTask): void => this.confirmDelete(value)
                  })
                }, (task: StudyTask) => `${task.id}-${task.status}`)
              }
              Column({ space: 8 }) {
                Text('快捷添加').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
                Row({ space: 10 }) {
                  Button('去选课程').layoutWeight(1).height(40).backgroundColor('#12B76A')
                    .onClick(() => this.appPathStack.pushPathByName(AppRoutes.COURSES, null))
                  Button('去练试卷').layoutWeight(1).height(40).backgroundColor('#2F6BFF')
                    .onClick(() => this.appPathStack.pushPathByName(AppRoutes.PAPERS, null))
                }.width('100%')
              }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(16)
              if (this.source === DataSource.MOCK) {
                Text(this.sourceMessage || '当前部分学习计划为演示数据')
                  .fontSize(11).fontColor('#B54708').padding(10).width('100%')
                  .backgroundColor('#FFF8EB').borderRadius(10)
              }
            }
          }.padding({ left: 16, right: 16, top: 12, bottom: 24 }).width('100%')
        }.layoutWeight(1).width('100%').edgeEffect(EdgeEffect.Spring)
        MainTabBar({ activeRoute: AppRoutes.STUDY_PLAN })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
    .onShown(() => this.loadData())
  }
}
