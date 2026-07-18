import { AppRoutes } from '../common/AppRoutes';
import { MainTabBar } from '../components/MainTabBar';
import { StudyTask, TaskStatus } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';

@Component
export struct StudyPlanPage {
  @State tasks: StudyTask[] = MockDataService.getTasks();

  private refresh(): void {
    this.tasks = MockDataService.getTasks().slice();
  }

  private nextStatus(task: StudyTask): void {
    const status: string = task.status === TaskStatus.NOT_STARTED ? TaskStatus.IN_PROGRESS : TaskStatus.COMPLETED;
    MockDataService.updateTaskStatus(task.id, status);
    this.refresh();
  }

  private completedCount(): number {
    return this.tasks.filter((task: StudyTask) => task.status === TaskStatus.COMPLETED).length;
  }

  build() {
    NavDestination() {
      Column() {
        Column({ space: 10 }) {
          Text('学习计划').fontSize(26).fontWeight(FontWeight.Bold).width('100%')
          Text(`共 ${this.tasks.length} 项 · 已完成 ${this.completedCount()} 项`).fontColor('#667085').width('100%')
          Progress({ value: this.tasks.length ? this.completedCount() * 100 / this.tasks.length : 0, total: 100 }).color('#2F6BFF').width('100%')
        }.padding(20).width('100%')
        List({ space: 12 }) {
          ForEach(this.tasks, (task: StudyTask) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(task.name).fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
                  Text(task.status).fontSize(12).fontColor(task.status === TaskStatus.COMPLETED ? '#12B76A' : '#2F6BFF')
                }.width('100%')
                Text(`${task.taskType} · ${task.subject} · ${task.difficulty} · ${task.createDate}`).fontSize(12).fontColor('#667085').width('100%')
                Row({ space: 10 }) {
                  if (task.status !== TaskStatus.COMPLETED) {
                    Button(task.status === TaskStatus.NOT_STARTED ? '开始学习' : '标记完成').fontSize(13).height(36).backgroundColor('#2F6BFF').onClick(() => this.nextStatus(task))
                  }
                  Button('删除').fontSize(13).height(36).backgroundColor('#F04438').onClick(() => { MockDataService.removeTask(task.id); this.refresh(); })
                }.width('100%')
              }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
            }
          }, (task: StudyTask) => `${task.id}-${task.status}`)
        }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 16 }).width('100%')
        MainTabBar({ activeRoute: AppRoutes.STUDY_PLAN })
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
