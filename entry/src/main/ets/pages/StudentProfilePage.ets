import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { StudentProfile } from '../model/DomainModels';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';
import { StudentService } from '../service/StudentService';

@Component
export struct StudentProfilePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @Prop requireSetup: boolean = false;
  @State name: string = '';
  @State grade: string = '六年级';
  @State subject: string = '数学';
  @State scoreText: string = '';
  @State weakPoints: string[] = [];
  @State isLoading: boolean = false;
  @State isSaving: boolean = false;
  @State loadError: string = '';
  @State formError: string = '';
  @State usingMockData: boolean = false;

  private readonly grades: string[] = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];
  private readonly subjects: string[] = ['语文', '数学', '英语'];

  aboutToAppear(): void {
    if (this.studentProfileId > 0) void this.loadProfile();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private applyProfile(profile: StudentProfile): void {
    this.studentProfileId = profile.id;
    this.name = this.requireSetup && !profile.profileCompleted ? '' : profile.name;
    this.grade = profile.grade || '六年级';
    this.subject = profile.subject || '数学';
    this.scoreText = profile.profileCompleted ? `${profile.recentScore}` : '';
    this.weakPoints = profile.weakPoints.slice();
    this.formError = '';
  }

  private async loadProfile(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    this.loadError = '';
    try {
      this.applyProfile(await StudentService.getProfile(this.studentProfileId));
      this.usingMockData = StudentService.isUsingMockFallback();
    } catch (error) {
      console.error(`学生档案加载失败: ${JSON.stringify(error)}`);
      this.loadError = '学生档案暂时无法加载，请检查网络后重试。';
      promptAction.showToast({ message: '学生档案加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private completion(): number {
    let completed: number = 0;
    if (this.name.trim()) completed++;
    if (this.grade) completed++;
    if (this.subject) completed++;
    if (this.scoreText.trim()) completed++;
    if (this.weakPoints.length > 0) completed++;
    return Math.round(completed * 100 / 5);
  }

  private weakPointSuggestions(): string[] {
    const lowerGrade: boolean = this.grade === '一年级' || this.grade === '二年级';
    const middleGrade: boolean = this.grade === '三年级' || this.grade === '四年级';
    if (this.subject === '语文') {
      if (lowerGrade) return ['拼音', '识字写字', '词语积累', '朗读', '看图写话'];
      if (middleGrade) return ['字词基础', '阅读理解', '句子表达', '习作', '古诗词'];
      return ['基础知识', '阅读理解', '古诗文', '作文', '综合运用'];
    }
    if (this.subject === '数学') {
      if (lowerGrade) return ['口算', '加减法', '应用题', '认识图形', '单位认识'];
      if (middleGrade) return ['乘除法', '计算', '应用题', '小数', '图形面积'];
      return ['分数', '小数', '百分数', '应用题', '几何'];
    }
    if (lowerGrade) return ['字母', '自然拼读', '基础词汇', '听力', '口语'];
    if (middleGrade) return ['词汇', '句型', '语法', '听力', '阅读'];
    return ['词汇', '语法', '阅读理解', '写作', '听力'];
  }

  private toggleWeakPoint(item: string): void {
    if (this.weakPoints.indexOf(item) >= 0) {
      this.weakPoints = this.weakPoints.filter((value: string) => value !== item);
      return;
    }
    if (this.weakPoints.length >= 5) {
      promptAction.showToast({ message: '最多选择5个薄弱知识点' });
      return;
    }
    this.weakPoints = this.weakPoints.concat([item]);
  }

  private validate(): string {
    const score: number = Number(this.scoreText);
    if (!this.name.trim()) return '请填写学生姓名';
    if (!this.scoreText.trim() || Number.isNaN(score) || score < 0 || score > 100) {
      return '最近成绩应为0到100之间的数字';
    }
    if (this.weakPoints.length === 0) return '请至少选择一个薄弱知识点';
    return '';
  }

  private async save(): Promise<void> {
    const validation: string = this.validate();
    this.formError = validation;
    if (validation) {
      promptAction.showToast({ message: validation });
      return;
    }
    if (this.isSaving) return;
    this.isSaving = true;
    const profile: StudentProfile = {
      id: this.studentProfileId,
      name: this.name.trim(),
      grade: this.grade,
      subject: this.subject,
      recentScore: Number(this.scoreText),
      weakPoints: this.weakPoints.slice(),
      learningGoal: '自主提升',
      weeklyStudyMinutes: 180,
      bindCode: '',
      profileCompleted: true
    };
    try {
      const saved: StudentProfile = await StudentService.saveProfile(profile);
      this.applyProfile(saved);
      this.usingMockData = StudentService.isUsingMockFallback();
      AppStorage.setOrCreate<boolean>(AppStorageKeys.PROFILE_COMPLETED, true);
      const snapshot: SessionSnapshot = await SessionStorageService.load(this.context());
      snapshot.studentProfileId = saved.id;
      snapshot.profileCompleted = true;
      await SessionStorageService.save(this.context(), snapshot);
      promptAction.showToast({ message: '学生档案已保存' });
      if (this.requireSetup) {
        this.appPathStack.clear();
        this.appPathStack.pushPathByName(AppRoutes.HOME, null);
      } else {
        this.appPathStack.pop();
      }
    } catch (error) {
      console.error(`学生档案保存失败: ${JSON.stringify(error)}`);
      this.formError = '保存失败，请检查网络后重试。';
      promptAction.showToast({ message: '保存失败，请稍后重试' });
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  private sectionHeader(title: string, description: string) {
    Column({ space: 4 }) {
      Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#101828').width('100%')
      Text(description).fontSize(12).fontColor('#667085').lineHeight(18).width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private fieldTitle(title: string, hint: string) {
    Row() {
      Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#344054')
      Text(' *').fontSize(14).fontColor('#F04438')
      Blank()
      if (hint) Text(hint).fontSize(11).fontColor('#98A2B3')
    }.width('100%')
  }

  private isGradeSelected(item: string): boolean {
    return this.grade === item;
  }

  private isSubjectSelected(item: string): boolean {
    return this.subject === item;
  }

  build() {
    NavDestination() {
      Column() {
        if (this.requireSetup) {
          Row() {
            Text('完善学生档案').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#101828')
          }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 8 })
          Text('首次使用需填写档案后才能进入应用')
            .fontSize(13).fontColor('#667085').width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })
        } else {
          PageHeader({ title: '修改学生档案' })
        }
        if (this.isLoading && !this.name && !this.requireSetup) {
          Column({ space: 12 }) {
            LoadingProgress().width(36).height(36).color('#2F6BFF')
            Text('正在加载学生档案…').fontSize(14).fontColor('#667085')
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 14 }) {
              Column({ space: 12 }) {
                Row() {
                  Column({ space: 5 }) {
                    Text(this.requireSetup ? '创建专属学习档案' : '修改学情信息')
                      .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#173B7A')
                    Text('用于课程推荐、试卷训练与学习计划')
                      .fontSize(12).fontColor('#526581').lineHeight(18)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(`${this.completion()}%`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
                }.width('100%')
                Progress({ value: this.completion(), total: 100, type: ProgressType.Linear })
                  .color('#2F6BFF').backgroundColor('#DDE7FF').width('100%')
              }.width('100%').padding(16).backgroundColor('#EEF4FF').borderRadius(18)

              if (this.loadError) {
                Row({ space: 10 }) {
                  Text(this.loadError).fontSize(12).fontColor('#B42318').lineHeight(18).layoutWeight(1)
                  Button('重试').fontSize(12).height(34).backgroundColor('#FEF3F2').fontColor('#B42318')
                    .onClick(() => void this.loadProfile())
                }.width('100%').padding(14).backgroundColor('#FFF7F6').borderRadius(14)
              }

              Column({ space: 13 }) {
                this.sectionHeader('基本信息', '填写学生姓名并选择当前就读年级。')
                this.fieldTitle('学生姓名', '例如：小明')
                TextInput({ placeholder: '请输入学生姓名', text: this.name })
                  .height(48).backgroundColor('#F7F9FC').borderRadius(12)
                  .onChange((value: string) => this.name = value)
                this.fieldTitle('当前年级', '小学一至六年级')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.grades, (item: string) => {
                    Button(item)
                      .width('31%')
                      .height(40)
                      .fontSize(13)
                      .fontColor(this.isGradeSelected(item) ? Color.White : '#475467')
                      .backgroundColor(this.isGradeSelected(item) ? '#2F6BFF' : '#F2F4F7')
                      .border({ width: 1, color: this.isGradeSelected(item) ? '#2F6BFF' : '#EAECF0' })
                      .borderRadius(12)
                      .margin({ right: 6, bottom: 8 })
                      .onClick(() => {
                        this.grade = item;
                        this.weakPoints = [];
                      })
                  }, (item: string) => `grade-${item}-${this.grade}`)
                }.width('100%')
              }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)

              Column({ space: 13 }) {
                this.sectionHeader('当前学情', '成绩和薄弱点将影响课程与试卷推荐。')
                this.fieldTitle('主要科目', '当前重点提升科目')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.subjects, (item: string) => {
                    Button(item)
                      .width('31%')
                      .height(40)
                      .fontSize(13)
                      .fontColor(this.isSubjectSelected(item) ? Color.White : '#475467')
                      .backgroundColor(this.isSubjectSelected(item) ? '#2F6BFF' : '#F2F4F7')
                      .border({ width: 1, color: this.isSubjectSelected(item) ? '#2F6BFF' : '#EAECF0' })
                      .borderRadius(12)
                      .margin({ right: 6, bottom: 8 })
                      .onClick(() => {
                        this.subject = item;
                        this.weakPoints = [];
                      })
                  }, (item: string) => `subject-${item}-${this.subject}`)
                }.width('100%')
                this.fieldTitle('最近成绩', '0–100分')
                TextInput({ placeholder: '请输入最近一次考试或测评成绩', text: this.scoreText })
                  .type(InputType.Number).height(48).backgroundColor('#F7F9FC').borderRadius(12)
                  .onChange((value: string) => this.scoreText = value)
                this.fieldTitle('薄弱知识点', `已选${this.weakPoints.length}/5`)
                Text('点击下方标签可多选，再次点击即可取消。').fontSize(11).fontColor('#98A2B3').width('100%')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.weakPointSuggestions(), (item: string) => {
                    Button(item)
                      .height(36).fontSize(12)
                      .fontColor(this.weakPoints.indexOf(item) >= 0 ? Color.White : '#475467')
                      .backgroundColor(this.weakPoints.indexOf(item) >= 0 ? '#7A5AF8' : '#F2F4F7')
                      .borderRadius(18).margin({ right: 8, bottom: 8 })
                      .onClick(() => this.toggleWeakPoint(item))
                  }, (item: string) => `weak-${this.grade}-${this.subject}-${item}`)
                }.width('100%')
                if (this.weakPoints.length > 0) {
                  Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                    ForEach(this.weakPoints, (item: string) => {
                      Button(`${item} ×`)
                        .height(34).fontSize(12).fontColor('#2F6BFF').backgroundColor('#EEF4FF')
                        .borderRadius(17).margin({ right: 8, bottom: 8 })
                        .onClick(() => this.toggleWeakPoint(item))
                    }, (item: string) => `selected-weak-${item}`)
                  }.width('100%')
                }
              }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)

              if (this.formError) {
                Text(this.formError).fontSize(12).fontColor('#B42318').width('100%')
                  .padding(12).backgroundColor('#FEF3F2').borderRadius(12)
              }
              Button(this.isSaving ? '保存中…' : (this.requireSetup ? '保存并进入应用' : '保存修改'))
                .width('100%').height(50).enabled(!this.isSaving)
                .backgroundColor('#2F6BFF').fontSize(16).fontWeight(FontWeight.Medium)
                .onClick(() => void this.save())
            }.padding({ left: 16, right: 16, top: 12, bottom: 30 }).width('100%')
          }.layoutWeight(1).width('100%')
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (this.requireSetup) {
        promptAction.showToast({ message: '请先完善学生档案' });
        return true;
      }
      return false;
    })
  }
}
