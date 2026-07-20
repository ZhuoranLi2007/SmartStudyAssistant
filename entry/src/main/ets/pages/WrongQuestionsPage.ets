import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { DataLoadResult, DataSource, WrongQuestion } from '../model/ProfileModels';
import { WrongQuestionService } from '../service/WrongQuestionService';

@Component
export struct WrongQuestionsPage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State subject: string = '全部';
  @State questions: WrongQuestion[] = [];
  @State expandedId: number = 0;
  @State source: DataSource = DataSource.MOCK;
  @State isLoading: boolean = false;

  aboutToAppear(): void { void this.load(); }

  private async load(): Promise<void> {
    if (this.isLoading) return; this.isLoading = true;
    try {
      const result: DataLoadResult<WrongQuestion[]> = await WrongQuestionService.getQuestions(this.studentProfileId, this.subject);
      this.questions = result.data; this.source = result.source;
    } finally { this.isLoading = false; }
  }

  private select(subject: string): void { this.subject = subject; void this.load(); }
  private master(id: number): void { WrongQuestionService.masterQuestion(id); void this.load(); }

  @Builder
  private subjectButton(label: string) {
    Button(label).layoutWeight(1).backgroundColor(this.subject === label ? '#2F6BFF' : '#D0D5DD').onClick(() => this.select(label))
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '错题本' })
        Row({ space: 8 }) { this.subjectButton('全部'); this.subjectButton('数学'); this.subjectButton('英语') }
          .padding({ left: 16, right: 16, bottom: 12 }).width('100%')
        if (!this.isLoading && this.questions.length === 0) {
          EmptyStateView({ title: '暂无错题', description: '继续保持，新的错题分析会显示在这里' }).margin({ left: 16, right: 16 })
        } else {
          List({ space: 12 }) {
            ForEach(this.questions, (item: WrongQuestion) => {
              ListItem() {
                Column({ space: 9 }) {
                  Row() {
                    Text(item.subject).fontSize(12).fontColor('#2F6BFF').backgroundColor('#EEF4FF').padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8)
                    Text(item.knowledgePoint).fontSize(12).fontColor('#667085').margin({ left: 8 }).layoutWeight(1)
                    if (item.mastered) Text('已掌握').fontSize(12).fontColor('#12B76A')
                  }.width('100%')
                  Text(item.question).fontSize(15).fontWeight(FontWeight.Medium).lineHeight(23).width('100%')
                  Text(`我的答案：${item.userAnswer}`).fontSize(13).fontColor('#D92D20').width('100%')
                  Text(`正确答案：${item.correctAnswer}`).fontSize(13).fontColor('#12B76A').width('100%')
                  Row() {
                    Text(this.expandedId === item.id ? '收起解析' : '查看解析').fontSize(13).fontColor('#2F6BFF').layoutWeight(1)
                    if (!item.mastered) Button('标记已掌握').height(34).fontSize(12).backgroundColor('#12B76A').onClick(() => this.master(item.id))
                  }.width('100%').onClick(() => this.expandedId = this.expandedId === item.id ? 0 : item.id)
                  if (this.expandedId === item.id) {
                    Text(item.explanation).fontSize(13).fontColor('#475467').lineHeight(21).padding(10).backgroundColor('#F9FAFB').borderRadius(10).width('100%')
                  }
                }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
              }
            }, (item: WrongQuestion) => `${item.id}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 18 }).width('100%')
        }
        if (this.source === DataSource.MOCK) Text('错题及掌握状态为演示数据').fontSize(11).fontColor('#98A2B3').margin({ bottom: 10 })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
