import { promptAction } from '@kit.ArkUI';
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
  @State source: DataSource = DataSource.LIVE;
  @State isLoading: boolean = false;
  @State busyId: number = 0;

  aboutToAppear(): void {
    void this.load(true);
  }

  private copyItem(item: WrongQuestion, mastered: boolean): WrongQuestion {
    return {
      id: item.id,
      questionNo: item.questionNo,
      subject: item.subject,
      knowledgePoint: item.knowledgePoint,
      question: item.question,
      userAnswer: item.userAnswer,
      correctAnswer: item.correctAnswer,
      explanation: item.explanation,
      mastered: mastered,
      wrongCount: item.wrongCount
    };
  }

  private async load(showLoading: boolean): Promise<void> {
    if (this.isLoading) return;
    if (showLoading) {
      this.isLoading = true;
    }
    try {
      const result: DataLoadResult<WrongQuestion[]> =
        await WrongQuestionService.getQuestions(this.studentProfileId, this.subject);
      // 仅在拿到有效列表时替换，避免闪成空页
      if (result.data) {
        this.questions = result.data;
        this.source = result.source;
      }
    } catch (error) {
      console.error(`错题本加载失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  private async master(id: number): Promise<void> {
    if (this.busyId > 0) return;
    const studentId: number = this.studentProfileId;
    if (studentId <= 0) {
      promptAction.showToast({ message: '请先完善学生档案' });
      return;
    }
    this.busyId = id;
    try {
      await WrongQuestionService.masterQuestion(studentId, id, true);
      const next: WrongQuestion[] = [];
      for (let index: number = 0; index < this.questions.length; index++) {
        const item: WrongQuestion = this.questions[index];
        if (item.id === id) {
          next.push(this.copyItem(item, true));
        } else {
          next.push(item);
        }
      }
      this.questions = next;
      promptAction.showToast({ message: '已标记为掌握' });
    } catch (error) {
      promptAction.showToast({ message: '标记失败，请稍后重试' });
      console.error(`标记掌握失败: ${error}`);
    } finally {
      this.busyId = 0;
    }
  }

  private async deleteItem(id: number): Promise<void> {
    if (this.busyId > 0) return;
    const studentId: number = this.studentProfileId;
    const questionId: number = id;
    if (studentId <= 0 || questionId <= 0) {
      promptAction.showToast({ message: '删除失败：题目无效' });
      return;
    }
    this.busyId = questionId;
    try {
      await WrongQuestionService.deleteQuestion(studentId, questionId);
      const next: WrongQuestion[] = [];
      for (let index: number = 0; index < this.questions.length; index++) {
        if (this.questions[index].id !== questionId) {
          next.push(this.questions[index]);
        }
      }
      this.questions = next;
      if (this.expandedId === questionId) {
        this.expandedId = 0;
      }
      promptAction.showToast({ message: '已从错题本删除' });
    } catch (error) {
      const message: string = `${error}`;
      console.error(`删除错题失败: ${message}`);
      promptAction.showToast({
        message: message.includes('HTTP') ? `删除失败：${message}` : '删除失败，请稍后重试'
      });
    } finally {
      this.busyId = 0;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '错题本' })
        if (this.studentProfileId <= 0) {
          EmptyStateView({ title: '尚未绑定学生档案', description: '绑定后可同步练习产生的错题' })
            .margin({ left: 16, right: 16 })
        } else if (this.isLoading && this.questions.length === 0) {
          Text('正在加载错题...').fontColor('#667085').margin({ top: 40 })
        } else if (this.questions.length === 0) {
          EmptyStateView({ title: '暂无错题', description: '在试卷训练中答错后，会自动加入错题本' })
            .margin({ left: 16, right: 16 })
        } else {
          List({ space: 12 }) {
            ForEach(this.questions, (item: WrongQuestion) => {
              ListItem() {
                Column({ space: 12 }) {
                  Row() {
                    Row({ space: 8 }) {
                      Text(item.subject).fontSize(12).fontColor('#2F6BFF').backgroundColor('#EEF4FF')
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8)
                      Text(item.knowledgePoint).fontSize(12).fontColor('#667085').maxLines(1)
                    }.layoutWeight(1)
                    if (item.mastered) {
                      Text('已掌握').fontSize(12).fontColor('#12B76A').fontWeight(FontWeight.Medium)
                        .backgroundColor('#ECFDF3').padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
                    } else {
                      Text(`累计答错 ${item.wrongCount} 次`).fontSize(12).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                        .backgroundColor('#F04438').padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(10)
                    }
                  }.width('100%')
                  Text(item.question).fontSize(16).fontWeight(FontWeight.Medium).lineHeight(25).fontColor('#172033').width('100%')
                  Row({ space: 16 }) {
                    Column({ space: 3 }) {
                      Text('我的答案').fontSize(11).fontColor('#D92D20')
                      Text(item.userAnswer).fontSize(14).fontColor('#D92D20').fontWeight(FontWeight.Medium)
                    }.layoutWeight(1)
                    Column({ space: 3 }) {
                      Text('正确答案').fontSize(11).fontColor('#12B76A')
                      Text(item.correctAnswer).fontSize(14).fontColor('#12B76A').fontWeight(FontWeight.Medium)
                    }.layoutWeight(1)
                  }.width('100%')
                  Row({ space: 8 }) {
                    Text(this.expandedId === item.id ? '收起解析' : '查看解析')
                      .fontSize(13).fontColor('#2F6BFF').layoutWeight(1)
                      .onClick(() => this.expandedId = this.expandedId === item.id ? 0 : item.id)
                    if (!item.mastered) {
                      Button(this.busyId === item.id ? '处理中...' : '标记已掌握')
                        .height(34).fontSize(12).backgroundColor('#12B76A')
                        .enabled(this.busyId === 0)
                        .onClick(() => void this.master(item.id))
                    } else {
                      Button(this.busyId === item.id ? '删除中...' : '删除')
                        .height(34).fontSize(12).backgroundColor('#F04438')
                        .enabled(this.busyId === 0)
                        .onClick(() => void this.deleteItem(item.id))
                    }
                  }.width('100%')
                  if (this.expandedId === item.id) {
                    Text(item.explanation).fontSize(13).fontColor('#475467').lineHeight(21)
                      .padding(10).backgroundColor('#F9FAFB').borderRadius(10).width('100%')
                  }
                }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
              }
            }, (item: WrongQuestion) => `${item.id}-${item.mastered ? 1 : 0}-${item.wrongCount}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 18 }).width('100%')
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
