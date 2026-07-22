import { StudyTask, TaskStatus } from '../../model/DomainModels';

@Component
export struct StudyTaskCard {
  @Prop task: StudyTask;
  @Prop operating: boolean = false;
  onOpen: (task: StudyTask) => void = (_task: StudyTask): void => {};
  onStart: (task: StudyTask) => void = (_task: StudyTask): void => {};
  onComplete: (task: StudyTask) => void = (_task: StudyTask): void => {};
  onDelete: (task: StudyTask) => void = (_task: StudyTask): void => {};

  private statusColor(): string {
    if (this.task.status === TaskStatus.COMPLETED) return '#12B76A';
    if (this.task.status === TaskStatus.IN_PROGRESS) return '#F79009';
    return '#2F6BFF';
  }

  private dateLabel(): string {
    if (!this.task.scheduledDate) return '待安排';
    return `${this.task.scheduledDate.substring(5).split('-').join('月')}日`;
  }

  private taskIcon(): string {
    if (this.task.taskType === '试卷') return '卷';
    if (this.task.taskType === '错题') return '错';
    return '课';
  }

  private taskColor(): string {
    if (this.task.taskType === '试卷') return '#7A5AF8';
    if (this.task.taskType === '错题') return '#D92D20';
    return '#2F6BFF';
  }

  private taskBackground(): string {
    if (this.task.taskType === '试卷') return '#F4F0FF';
    if (this.task.taskType === '错题') return '#FEF3F2';
    return '#EEF4FF';
  }

  build() {
    Column({ space: 11 }) {
      Row({ space: 10 }) {
        Text(this.taskIcon())
          .width(38).height(38).textAlign(TextAlign.Center).fontWeight(FontWeight.Bold)
          .fontColor(this.taskColor()).backgroundColor(this.taskBackground()).borderRadius(11)
        Column({ space: 4 }) {
          Text(this.task.name).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#172033').maxLines(2).width('100%')
          Text(`${this.task.subject} · ${this.task.difficulty} · ${this.dateLabel()} · ${this.task.durationMinutes}分钟`)
            .fontSize(11).fontColor('#667085').width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.task.status).fontSize(10).fontColor(this.statusColor())
          .padding({ left: 7, right: 7, top: 4, bottom: 4 })
          .backgroundColor(this.task.status === TaskStatus.COMPLETED ? '#ECFDF3' : '#F4F7FF').borderRadius(9)
      }.width('100%').alignItems(VerticalAlign.Top)
      Row({ space: 6 }) {
        Text('知识点').fontSize(10).fontColor('#2F6BFF').padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor('#EEF4FF').borderRadius(8)
        Text(this.task.knowledgePoint || '综合训练').fontSize(12).fontColor('#475467').layoutWeight(1)
      }.width('100%')
      Row({ space: 8 }) {
        Button('查看详情').fontSize(12).height(34).backgroundColor('#E9EEF8').fontColor('#344054')
          .onClick(() => this.onOpen(this.task))
        if (this.task.status !== TaskStatus.COMPLETED) {
          Button(this.task.taskType === '课程' ? '继续学习' : this.task.taskType === '错题' ? '开始复测' : '开始练习')
            .fontSize(12).height(34).backgroundColor('#2F6BFF').enabled(!this.operating)
            .onClick(() => this.onStart(this.task))
          if (this.task.taskType === '课程' && this.task.status === TaskStatus.IN_PROGRESS) {
            Button('标记完成').fontSize(12).height(34).backgroundColor('#12B76A').enabled(!this.operating)
              .onClick(() => this.onComplete(this.task))
          }
        }
        Blank().layoutWeight(1)
        Text('删除').fontSize(12).fontColor('#D92D20').onClick(() => this.onDelete(this.task))
      }.width('100%')
    }
    .padding(14).width('100%').backgroundColor(Color.White).borderRadius(16)
    .shadow({ radius: 8, color: '#14000000', offsetX: 0, offsetY: 2 })
  }
}
