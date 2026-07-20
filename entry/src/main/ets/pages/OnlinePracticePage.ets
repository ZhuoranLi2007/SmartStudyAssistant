import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { MockHomeData } from '../data/MockHomeData';
import { PracticeOption, PracticeQuestion } from '../model/HomeModels';
import { MockDataService } from '../service/MockDataService';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PracticeAttemptResult, PracticeLoadResult, PracticeQuestionResult } from '../model/AiModels';
import { PracticeService } from '../service/PracticeService';
import { StudyPlanService } from '../service/StudyPlanService';
import { TaskStatus } from '../model/DomainModels';

@Component
export struct OnlinePracticePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @Prop paperId: number = 0;
  @Prop taskId: number = 0;
  @State paperName: string = '在线答题';
  @State questions: PracticeQuestion[] = [];
  @State currentIndex: number = 0;
  @State selectedAnswers: number[] = [];
  @State submitted: boolean = false;
  @State score: number = 0;
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State liveData: boolean = false;

  aboutToAppear(): void {
    void this.loadQuestions();
  }

  private async loadQuestions(): Promise<void> {
    this.loading = true;
    try {
      const result: PracticeLoadResult = await PracticeService.load(this.paperId);
      this.questions = result.questions;
      this.paperName = result.paperName;
      this.liveData = result.live;
    } catch (error) {
      this.questions = MockHomeData.getPracticeQuestions(this.paperId);
      if (this.questions.length > 0) this.paperName = MockDataService.getPaper(this.paperId).name;
      this.liveData = false;
    }
    const answers: number[] = [];
    for (let index: number = 0; index < this.questions.length; index++) answers.push(-1);
    this.selectedAnswers = answers;
    this.loading = false;
  }

  private select(index: number): void {
    if (this.submitted) return;
    const answers: number[] = this.selectedAnswers.slice();
    answers[this.currentIndex] = index;
    this.selectedAnswers = answers;
  }

  private selectedIndex(): number {
    if (this.currentIndex < 0 || this.currentIndex >= this.selectedAnswers.length) return -1;
    return this.selectedAnswers[this.currentIndex];
  }

  private next(): void {
    if (this.selectedIndex() < 0) { promptAction.showToast({ message: '请先选择一个答案' }); return; }
    if (this.currentIndex < this.questions.length - 1) this.currentIndex++;
    else void this.submit();
  }

  private async submit(): Promise<void> {
    if (this.submitting) return;
    for (let index: number = 0; index < this.selectedAnswers.length; index++) {
      if (this.selectedAnswers[index] < 0) {
        this.currentIndex = index;
        promptAction.showToast({ message: `第${index + 1}题尚未作答` });
        return;
      }
    }
    if (this.liveData) {
      if (this.studentProfileId <= 0) {
        this.liveData = false;
        promptAction.showToast({ message: '尚未创建学生档案，本次按演示模式评分' });
      }
    }
    if (this.liveData) {
      this.submitting = true;
      try {
        const result: PracticeAttemptResult = await PracticeService.submit(
          this.paperId, this.studentProfileId,
          this.questions, this.selectedAnswers
        );
        const updated: PracticeQuestion[] = this.questions.slice();
        for (let resultIndex: number = 0; resultIndex < result.results.length; resultIndex++) {
          const item: PracticeQuestionResult = result.results[resultIndex];
          for (let questionIndex: number = 0; questionIndex < updated.length; questionIndex++) {
            if (updated[questionIndex].id === item.questionId) {
              updated[questionIndex] = {
                id: updated[questionIndex].id,
                stem: updated[questionIndex].stem,
                options: updated[questionIndex].options,
                correctIndex: item.correctIndex,
                explanation: item.explanation
              };
            }
          }
        }
        this.questions = updated;
        this.score = Math.round(result.score);
        this.submitted = true;
        await this.completePlanTask();
        return;
      } catch (error) {
        this.liveData = false;
        promptAction.showToast({ message: '答题记录上传失败，本次按演示模式评分' });
        this.questions = MockHomeData.getPracticeQuestions(this.paperId);
      } finally {
        this.submitting = false;
      }
    }
    let correctCount: number = 0;
    for (let index: number = 0; index < this.questions.length; index++) {
      if (this.selectedAnswers[index] === this.questions[index].correctIndex) correctCount++;
    }
    this.score = this.questions.length > 0 ? Math.round(correctCount * 100 / this.questions.length) : 0;
    this.submitted = true;
    await this.completePlanTask();
  }

  private async completePlanTask(): Promise<void> {
    if (this.taskId <= 0) return;
    try {
      await StudyPlanService.updateStatus(this.taskId, TaskStatus.COMPLETED);
      promptAction.showToast({ message: '试卷任务已同步完成' });
    } catch (error) {
      console.warn(`试卷任务状态同步失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '答题已完成，计划状态稍后可重试同步' });
    }
  }

  private answerText(question: PracticeQuestion, index: number): string {
    if (index < 0 || index >= question.options.length) return '未作答';
    return `${question.options[index].label}. ${question.options[index].content}`;
  }

  @Builder
  private optionItem(option: PracticeOption, index: number) {
    Row({ space: 10 }) {
      Text(option.label).width(34).height(34).textAlign(TextAlign.Center).fontWeight(FontWeight.Bold)
        .fontColor(this.selectedIndex() === index ? Color.White : '#2F6BFF')
        .backgroundColor(this.selectedIndex() === index ? '#2F6BFF' : '#EEF4FF').borderRadius(17)
      Text(option.content).fontSize(15).fontColor('#344054').layoutWeight(1)
    }.padding(12).width('100%').backgroundColor(this.selectedIndex() === index ? '#F4F7FF' : Color.White)
      .border({ width: 1, color: this.selectedIndex() === index ? '#2F6BFF' : '#EAECF0' }).borderRadius(14)
      .onClick(() => this.select(index))
  }

  @Builder
  private resultCard(question: PracticeQuestion, index: number) {
    Column({ space: 7 }) {
      Row() {
        Text(`第${index + 1}题`).fontSize(13).fontWeight(FontWeight.Bold).layoutWeight(1)
        Text(this.selectedAnswers[index] === question.correctIndex ? '回答正确' : '回答错误')
          .fontSize(12).fontColor(this.selectedAnswers[index] === question.correctIndex ? '#12B76A' : '#D92D20')
      }.width('100%')
      Text(question.stem).fontSize(14).fontWeight(FontWeight.Medium).width('100%')
      Text(`你的答案：${this.answerText(question, this.selectedAnswers[index])}`).fontSize(12)
        .fontColor(this.selectedAnswers[index] === question.correctIndex ? '#12B76A' : '#D92D20').width('100%')
      Text(`正确答案：${this.answerText(question, question.correctIndex)}`).fontSize(12).fontColor('#12B76A').width('100%')
      Text(`解析：${question.explanation}`).fontSize(12).fontColor('#667085').lineHeight(20).width('100%')
    }.padding(14).width('100%').backgroundColor(Color.White).borderRadius(15)
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.paperName })
        if (this.loading) {
          Text('正在加载题目...').margin({ top: 40 }).fontColor('#667085')
        } else if (this.questions.length === 0) {
          EmptyStateView({ title: '暂无练习题', description: '试卷参数无效或当前试卷还没有配置题目' }).margin({ left: 16, right: 16, top: 24 })
        } else if (this.submitted) {
          Scroll() {
            Column({ space: 13 }) {
              Column({ space: 8 }) {
                Text('答题完成').fontSize(20).fontWeight(FontWeight.Bold)
                Text(`${this.score} 分`).fontSize(38).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
              Text(`共 ${this.questions.length} 题，以下是本次答题解析`).fontSize(12).fontColor('#667085')
              Text(this.liveData ? '本次结果已保存到学习报告' : '当前为本地演示结果').fontSize(11).fontColor(this.liveData ? '#12B76A' : '#B54708')
              }.padding(18).width('100%').backgroundColor('#EEF4FF').borderRadius(18)
              ForEach(this.questions, (question: PracticeQuestion, index: number) => {
                this.resultCard(question, index)
              }, (question: PracticeQuestion) => `${question.id}`)
              Button('返回上一页').width('100%').height(46).backgroundColor('#2F6BFF').onClick(() => this.appPathStack.pop())
            }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
          }.layoutWeight(1)
        } else {
          Column({ space: 13 }) {
            Row() {
              Text(`第 ${this.currentIndex + 1}/${this.questions.length} 题`).fontSize(13).fontColor('#2F6BFF').layoutWeight(1)
              Text(`已答 ${this.selectedAnswers.filter((answer: number) => answer >= 0).length} 题`).fontSize(12).fontColor('#667085')
            }.width('100%')
            Progress({ value: this.currentIndex + 1, total: this.questions.length, type: ProgressType.Linear }).color('#2F6BFF').width('100%')
            Scroll() {
              Column({ space: 12 }) {
                Text(this.questions[this.currentIndex].stem).fontSize(18).fontWeight(FontWeight.Bold).lineHeight(28).width('100%')
                ForEach(this.questions[this.currentIndex].options, (option: PracticeOption, index: number) => {
                  this.optionItem(option, index)
                }, (option: PracticeOption) => option.label)
              }.width('100%')
            }.layoutWeight(1).width('100%')
            Row({ space: 10 }) {
              Button('上一题').layoutWeight(1).height(44).enabled(this.currentIndex > 0).backgroundColor('#98A2B3')
                .onClick(() => { if (this.currentIndex > 0) this.currentIndex--; })
              Button(this.submitting ? '正在提交...' : this.currentIndex === this.questions.length - 1 ? '提交答卷' : '下一题')
                .layoutWeight(1).height(44).enabled(!this.submitting).backgroundColor('#2F6BFF')
                .onClick(() => this.next())
            }.width('100%')
          }.padding({ left: 16, right: 16, bottom: 20 }).width('100%').layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
