import { promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { TaskStatus } from '../model/DomainModels';
import { WrongQuestionTraining, WrongQuestionTrainingResult } from '../model/StudyPlanModels';
import { StudyPlanService } from '../service/StudyPlanService';
import { WrongQuestionService } from '../service/WrongQuestionService';

@Component
export struct WrongQuestionTrainingPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @Prop wrongQuestionId: number = 0;
  @Prop taskId: number = 0;
  @State training: WrongQuestionTraining | null = null;
  @State selectedIndex: number = -1;
  @State result: WrongQuestionTrainingResult | null = null;
  @State loading: boolean = true;
  @State submitting: boolean = false;

  aboutToAppear(): void {
    void this.loadTraining();
  }

  private async loadTraining(): Promise<void> {
    this.loading = true;
    try {
      this.training = await WrongQuestionService.getTraining(this.studentProfileId, this.wrongQuestionId);
    } catch (error) {
      this.training = null;
      console.error(`错题复测加载失败: ${JSON.stringify(error)}`);
    } finally {
      this.loading = false;
    }
  }

  private async submit(): Promise<void> {
    if (!this.training || this.submitting) return;
    if (this.selectedIndex < 0) {
      promptAction.showToast({ message: '请先选择一个答案' });
      return;
    }
    this.submitting = true;
    try {
      const value: WrongQuestionTrainingResult = await WrongQuestionService.submitTraining(
        this.studentProfileId, this.training.id, this.selectedIndex, this.training.live
      );
      this.result = value;
      if (value.correct && this.taskId > 0 && !this.training.live) {
        await StudyPlanService.updateStatus(this.taskId, TaskStatus.COMPLETED);
      }
      promptAction.showToast({ message: value.correct ? '回答正确，已标记为掌握' : '回答错误，请结合解析重新练习' });
    } catch (error) {
      promptAction.showToast({ message: '提交失败，请检查网络后重试' });
    } finally {
      this.submitting = false;
    }
  }

  private reset(): void {
    this.selectedIndex = -1;
    this.result = null;
  }

  @Builder
  private optionItem(option: string, index: number) {
    Row({ space: 10 }) {
      Text(String.fromCharCode(65 + index)).width(34).height(34).textAlign(TextAlign.Center)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedIndex === index ? Color.White : '#2F6BFF')
        .backgroundColor(this.selectedIndex === index ? '#2F6BFF' : '#EEF4FF').borderRadius(17)
      Text(option).fontSize(15).fontColor('#344054').layoutWeight(1)
    }.padding(12).width('100%').backgroundColor(this.selectedIndex === index ? '#F4F7FF' : Color.White)
      .border({ width: 1, color: this.selectedIndex === index ? '#2F6BFF' : '#EAECF0' }).borderRadius(14)
      .onClick(() => { if (!this.result) this.selectedIndex = index; })
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '错题复测' })
        if (this.loading) {
          Text('正在加载原题...').margin({ top: 40 }).fontColor('#667085')
        } else if (!this.training) {
          EmptyStateView({ title: '暂时无法加载错题', description: '错题参数无效或原题数据不存在，请返回后重试' })
            .margin({ left: 16, right: 16, top: 24 })
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Column({ space: 8 }) {
                Row() {
                  Text(`${this.training.subject} · ${this.training.knowledgePoint}`).fontSize(13).fontWeight(FontWeight.Bold)
                    .fontColor('#2F6BFF').layoutWeight(1)
                  Text(`历史答错 ${this.result ? this.result.wrongCount : this.training.wrongCount} 次`)
                    .fontSize(11).fontColor('#D92D20')
                }.width('100%')
                Text('原题复测').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
                Text(this.training.question).fontSize(17).lineHeight(27).fontColor('#172033').width('100%')
                Text(`上次错误答案：${this.training.previousAnswer}`).fontSize(12).fontColor('#667085').width('100%')
              }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(17)
              ForEach(this.training.options, (option: string, index: number) => {
                this.optionItem(option, index)
              }, (option: string, index: number) => `${index}-${option}`)
              if (this.result) {
                Column({ space: 9 }) {
                  Text(this.result.correct ? '复测通过，已掌握' : '本次仍未掌握')
                    .fontSize(17).fontWeight(FontWeight.Bold)
                    .fontColor(this.result.correct ? '#12B76A' : '#D92D20').width('100%')
                  Text(`正确答案：${String.fromCharCode(65 + this.result.correctIndex)}. ${this.training.options[this.result.correctIndex]}`)
                    .fontSize(13).fontColor('#344054').width('100%')
                  Text(`解析：${this.result.explanation}`).fontSize(13).lineHeight(21).fontColor('#475467').width('100%')
                }.padding(15).width('100%').backgroundColor(this.result.correct ? '#ECFDF3' : '#FFF4ED').borderRadius(15)
                Row({ space: 10 }) {
                  Button('返回学习计划').layoutWeight(1).height(44).backgroundColor('#98A2B3')
                    .onClick(() => this.appPathStack.pop())
                  if (!this.result.correct) {
                    Button('重新练习').layoutWeight(1).height(44).backgroundColor('#2F6BFF').onClick(() => this.reset())
                  }
                }.width('100%')
              } else {
                Button(this.submitting ? '正在提交...' : '提交答案').width('100%').height(46)
                  .enabled(!this.submitting).backgroundColor('#2F6BFF').onClick(() => { void this.submit(); })
              }
              if (!this.training.live) {
                Text('当前为演示错题，作答状态仅在本次运行中保存').fontSize(11).fontColor('#B54708')
                  .padding(10).width('100%').backgroundColor('#FFF8EB').borderRadius(10)
              }
            }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
          }.layoutWeight(1).width('100%')
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
