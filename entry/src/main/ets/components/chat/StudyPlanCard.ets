import { promptAction } from '@kit.ArkUI';
import { AiCard, AiPlanTask } from '../../model/AiModels';
import { StudyPlanService } from '../../service/StudyPlanService';

@Component
export struct StudyPlanCard {
  @Prop card: AiCard;
  @Prop studentProfileId: number = 0;
  @State isAdded: boolean = false;
  @State adding: boolean = false;

  private targetIdForTask(task: AiPlanTask): number {
    if (task.taskType === '课程') {
      return task.courseId || 0;
    }
    if (task.taskType === '试卷') {
      return task.paperId || 0;
    }
    if (task.taskType === '错题') {
      return task.wrongQuestionId || 0;
    }
    return 0;
  }

  private async addToPlan(): Promise<void> {
    if (this.adding || this.isAdded || this.studentProfileId <= 0) {
      if (this.studentProfileId <= 0) {
        promptAction.showToast({ message: '请先绑定学生档案' });
      }
      return;
    }
    if (!this.card.tasks || this.card.tasks.length === 0) {
      promptAction.showToast({ message: '没有可添加的学习任务' });
      return;
    }
    this.adding = true;
    let addedCount: number = 0;
    let skippedCount: number = 0;
    try {
      for (const task of this.card.tasks) {
        const targetId: number = this.targetIdForTask(task);
        if (targetId <= 0 && task.taskType !== '错题') {
          continue;
        }
        try {
          await StudyPlanService.addTask(this.studentProfileId, task.taskType, targetId, task.date);
          addedCount++;
        } catch (error) {
          const message: string = `${error}`;
          if (message.includes('HTTP 409')) {
            skippedCount++;
          } else {
            throw new Error(message);
          }
        }
      }
      if (addedCount > 0) {
        this.isAdded = true;
        promptAction.showToast({ message: `已添加 ${addedCount} 项到学习计划` });
      } else if (skippedCount > 0) {
        this.isAdded = true;
        promptAction.showToast({ message: '这些学习任务已在学习计划中' });
      } else {
        promptAction.showToast({ message: '没有可添加的学习任务' });
      }
    } catch (error) {
      promptAction.showToast({ message: `添加失败：${error}` });
    } finally {
      this.adding = false;
    }
  }

  private dayText(date: string): string {
    if (!date) return '任务';
    const parts: string[] = date.split('-');
    if (parts.length < 3) return date;
    return `${parts[1]}/${parts[2]}`;
  }

  build() {
    Column({ space: 9 }) {
      Row() {
        Text('▣ 学习计划（本周）').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
        Blank()
        Text(`${this.card.tasks ? this.card.tasks.length : 0}项`).fontSize(10).fontColor('#667085')
      }.width('100%')
      if (this.card.tasks && this.card.tasks.length > 0) {
        ForEach(this.card.tasks.slice(0, 4), (task: AiPlanTask) => {
          Row({ space: 9 }) {
            Text(this.dayText(task.date)).fontSize(10).fontColor('#2F6BFF').width(42).textAlign(TextAlign.Center)
              .padding({ top: 4, bottom: 4 }).backgroundColor('#EEF4FF').borderRadius(8)
            Column({ space: 2 }) {
              Text(task.title).fontSize(12).fontWeight(FontWeight.Medium).maxLines(1).width('100%')
              Text(`${task.taskType} · ${task.durationMinutes}分钟`).fontSize(10).fontColor('#667085').width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%')
        }, (task: AiPlanTask) => `${task.id}_${task.date}`)
      } else {
        Text(this.card.subtitle || '学习计划已生成，可进入学习计划查看').fontSize(12).fontColor('#667085').width('100%')
      }
      Button(this.isAdded ? '已添加到我的学习计划' : (this.adding ? '添加中...' : '添加到我的学习计划'))
        .fontSize(12)
        .height(34)
        .width('100%')
        .backgroundColor(this.isAdded ? '#98A2B3' : '#356DF3')
        .enabled(!this.adding && !this.isAdded)
        .accessibilityText('添加到我的学习计划')
        .onClick(() => void this.addToPlan())
    }.padding(13).width('100%').backgroundColor('#F9FBFF').borderRadius(14).border({ width: 1, color: '#DCE6FB' })
  }
}
