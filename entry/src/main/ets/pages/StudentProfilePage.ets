import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { MockDataService } from '../service/MockDataService';

@Component
export struct StudentProfilePage {
  private profile = MockDataService.getStudentProfile();
  @State name: string = this.profile.name;
  @State grade: string = this.profile.grade;
  @State subject: string = this.profile.subject;
  @State scoreText: string = `${this.profile.recentScore}`;
  @State weakPoints: string = this.profile.weakPoints.join('、');
  @State learningGoal: string = this.profile.learningGoal;
  @State weeklyMinutes: string = `${this.profile.weeklyStudyMinutes}`;

  private save(): void {
    const score: number = Number(this.scoreText);
    if (!this.name.trim() || score < 0 || score > 100) {
      promptAction.showToast({ message: '请检查姓名和0-100分成绩' });
      return;
    }
    promptAction.showToast({ message: '学生档案已保存（演示模式）' });
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '学生档案' })
        Scroll() {
          Column({ space: 14 }) {
            TextInput({ placeholder: '学生姓名', text: this.name }).onChange((value: string) => this.name = value)
            Text('年级').width('100%').fontWeight(FontWeight.Medium)
            Row({ space: 10 }) {
              Button('五年级').layoutWeight(1).backgroundColor(this.grade === '五年级' ? '#2F6BFF' : '#D0D5DD').onClick(() => this.grade = '五年级')
              Button('六年级').layoutWeight(1).backgroundColor(this.grade === '六年级' ? '#2F6BFF' : '#D0D5DD').onClick(() => this.grade = '六年级')
            }
            Text('主要科目').width('100%').fontWeight(FontWeight.Medium)
            Row({ space: 10 }) {
              Button('数学').layoutWeight(1).backgroundColor(this.subject === '数学' ? '#2F6BFF' : '#D0D5DD').onClick(() => this.subject = '数学')
              Button('英语').layoutWeight(1).backgroundColor(this.subject === '英语' ? '#2F6BFF' : '#D0D5DD').onClick(() => this.subject = '英语')
            }
            TextInput({ placeholder: '最近考试成绩', text: this.scoreText }).type(InputType.Number).onChange((value: string) => this.scoreText = value)
            TextInput({ placeholder: '薄弱知识点，用顿号分隔', text: this.weakPoints }).onChange((value: string) => this.weakPoints = value)
            TextInput({ placeholder: '学习目标', text: this.learningGoal }).onChange((value: string) => this.learningGoal = value)
            TextInput({ placeholder: '每周学习分钟数', text: this.weeklyMinutes }).type(InputType.Number).onChange((value: string) => this.weeklyMinutes = value)
            Text(`学生绑定码：${this.profile.bindCode}`).width('100%').fontColor('#2F6BFF')
            Text('该绑定码仅用于演示；真实后端会生成一次性绑定码。').fontSize(12).fontColor('#98A2B3').width('100%')
            Button('保存档案').width('100%').backgroundColor('#2F6BFF').onClick(() => this.save())
          }
          .padding(20)
          .width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
