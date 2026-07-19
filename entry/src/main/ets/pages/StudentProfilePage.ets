import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { StudentProfile } from '../model/DomainModels';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';
import { StudentService } from '../service/StudentService';

@Component
export struct StudentProfilePage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State name: string = '';
  @State grade: string = '六年级';
  @State subject: string = '数学';
  @State scoreText: string = '75';
  @State weakPoints: string = '';
  @State learningGoal: string = '提高成绩';
  @State weeklyMinutes: string = '180';
  @State bindCode: string = '';
  @State isLoading: boolean = false;
  @State isSaving: boolean = false;

  aboutToAppear(): void {
    if (this.studentProfileId > 0) void this.loadProfile();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private applyProfile(profile: StudentProfile): void {
    this.studentProfileId = profile.id;
    this.name = profile.name;
    this.grade = profile.grade;
    this.subject = profile.subject;
    this.scoreText = `${profile.recentScore}`;
    this.weakPoints = profile.weakPoints.join('、');
    this.learningGoal = profile.learningGoal;
    this.weeklyMinutes = `${profile.weeklyStudyMinutes}`;
    this.bindCode = profile.bindCode;
  }

  private async loadProfile(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      this.applyProfile(await StudentService.getProfile(this.studentProfileId));
    } catch (error) {
      console.error(`学生档案加载失败: ${JSON.stringify(error)}`);
      this.studentProfileId = 0;
      promptAction.showToast({ message: '原学生档案已失效，请重新创建' });
    } finally {
      this.isLoading = false;
    }
  }

  private async save(): Promise<void> {
    const score: number = Number(this.scoreText);
    const minutes: number = Number(this.weeklyMinutes);
    if (!this.name.trim() || score < 0 || score > 100 || minutes < 30) {
      promptAction.showToast({ message: '请检查姓名、成绩和学习时间' });
      return;
    }
    if (this.isSaving) return;
    this.isSaving = true;
    const profile: StudentProfile = {
      id: this.studentProfileId,
      name: this.name.trim(),
      grade: this.grade,
      subject: this.subject,
      recentScore: score,
      weakPoints: this.weakPoints.split('、').filter((item: string) => item.trim().length > 0),
      learningGoal: this.learningGoal.trim(),
      weeklyStudyMinutes: minutes,
      bindCode: this.bindCode
    };
    try {
      const saved: StudentProfile = await StudentService.saveProfile(profile);
      this.applyProfile(saved);
      const snapshot: SessionSnapshot = await SessionStorageService.load(this.context());
      snapshot.studentProfileId = saved.id;
      await SessionStorageService.save(this.context(), snapshot);
      promptAction.showToast({ message: '学生档案已保存' });
    } catch (error) {
      console.error(`学生档案保存失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '保存失败，请检查后端连接' });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.studentProfileId > 0 ? '学生档案' : '创建学生档案' })
        Scroll() {
          Column({ space: 14 }) {
            if (this.studentProfileId <= 0) {
              Text('完善学情后，AI 才能进行个性化课程与试卷推荐。')
                .fontSize(13).fontColor('#2F6BFF').padding(12).backgroundColor('#EEF4FF').borderRadius(12).width('100%')
            }
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
            if (this.bindCode) {
              Text(`学生绑定码：${this.bindCode}`).width('100%').fontColor('#2F6BFF')
              Text('绑定码供学生账号加入当前家庭使用，成功绑定后会失效。').fontSize(12).fontColor('#98A2B3').width('100%')
            }
            Button(this.isSaving ? '保存中...' : '保存档案').width('100%').enabled(!this.isSaving)
              .backgroundColor('#2F6BFF').onClick(() => void this.save())
          }.padding(20).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
