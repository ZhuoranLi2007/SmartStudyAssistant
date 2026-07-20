import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { StudentProfile } from '../model/DomainModels';
import { SessionSnapshot, SessionStorageService } from '../service/SessionStorageService';
import { StudentService } from '../service/StudentService';

@Component
export struct StudentProfilePage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @State name: string = '';
  @State grade: string = '六年级';
  @State subject: string = '数学';
  @State scoreText: string = '75';
  @State weakPoints: string[] = [];
  @State customWeakPoint: string = '';
  @State learningGoal: string = '提高成绩';
  @State weeklyMinutes: string = '180';
  @State bindCode: string = '';
  @State isLoading: boolean = false;
  @State isSaving: boolean = false;
  @State loadError: string = '';
  @State formError: string = '';
  @State usingMockData: boolean = false;

  private readonly grades: string[] = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];
  private readonly subjects: string[] = ['语文', '数学', '英语'];
  private readonly goals: string[] = ['巩固基础', '提高成绩', '查漏补缺', '培养习惯', '冲刺优秀', '拓展思维'];

  aboutToAppear(): void {
    if (this.studentProfileId > 0) void this.loadProfile();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private canEdit(): boolean {
    return this.role === 'parent';
  }

  private applyProfile(profile: StudentProfile): void {
    this.studentProfileId = profile.id;
    this.name = profile.name;
    this.grade = profile.grade;
    this.subject = profile.subject;
    this.scoreText = `${profile.recentScore}`;
    this.weakPoints = profile.weakPoints.slice();
    this.learningGoal = profile.learningGoal;
    this.weeklyMinutes = `${profile.weeklyStudyMinutes}`;
    this.bindCode = profile.bindCode;
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
      this.loadError = '学生档案暂时无法加载，请检查登录状态或网络后重试。';
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
    if (this.learningGoal.trim()) completed++;
    if (this.weeklyMinutes.trim()) completed++;
    return Math.round(completed * 100 / 7);
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
    if (!this.canEdit()) return;
    if (this.weakPoints.indexOf(item) >= 0) {
      this.weakPoints = this.weakPoints.filter((value: string) => value !== item);
      return;
    }
    if (this.weakPoints.length >= 10) {
      promptAction.showToast({ message: '最多选择10个薄弱知识点' });
      return;
    }
    this.weakPoints = this.weakPoints.concat([item]);
  }

  private addCustomWeakPoint(): void {
    const item: string = this.customWeakPoint.trim();
    if (!item) {
      promptAction.showToast({ message: '请输入一个知识点' });
      return;
    }
    if (this.weakPoints.indexOf(item) >= 0) {
      promptAction.showToast({ message: '该知识点已经添加' });
      return;
    }
    if (this.weakPoints.length >= 10) {
      promptAction.showToast({ message: '最多添加10个薄弱知识点' });
      return;
    }
    this.weakPoints = this.weakPoints.concat([item]);
    this.customWeakPoint = '';
  }

  private validate(): string {
    const score: number = Number(this.scoreText);
    const minutes: number = Number(this.weeklyMinutes);
    if (!this.name.trim()) return '请填写学生姓名';
    if (!this.scoreText.trim() || Number.isNaN(score) || score < 0 || score > 100) return '最近成绩应为0到100之间的数字';
    if (this.weakPoints.length === 0) return '请至少选择一个薄弱知识点';
    if (!this.learningGoal.trim()) return '请选择学习目标';
    if (!this.weeklyMinutes.trim() || Number.isNaN(minutes) || minutes < 30 || minutes > 2000) {
      return '每周学习时间应为30到2000分钟';
    }
    return '';
  }

  private async save(): Promise<void> {
    if (!this.canEdit()) return;
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
      learningGoal: this.learningGoal.trim(),
      weeklyStudyMinutes: Number(this.weeklyMinutes),
      bindCode: this.bindCode
    };
    try {
      const saved: StudentProfile = await StudentService.saveProfile(profile);
      this.applyProfile(saved);
      this.usingMockData = StudentService.isUsingMockFallback();
      const snapshot: SessionSnapshot = await SessionStorageService.load(this.context());
      snapshot.studentProfileId = saved.id;
      await SessionStorageService.save(this.context(), snapshot);
      promptAction.showToast({ message: this.usingMockData ? '已保存为本地演示档案' : '学生档案已保存' });
    } catch (error) {
      console.error(`学生档案保存失败: ${JSON.stringify(error)}`);
      this.formError = '保存失败，请检查账号权限或后端连接。';
      promptAction.showToast({ message: '保存失败，请稍后重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private async copyBindCode(): Promise<void> {
    if (!this.bindCode) return;
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.bindCode);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '学生绑定码已复制' });
    } catch (error) {
      console.error(`复制绑定码失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '复制失败，请稍后重试' });
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

  @Builder
  private optionButton(label: string, selected: boolean, optionType: string) {
    Button(label)
      .width(optionType === 'grade' ? '31%' : optionType === 'subject' ? '31%' : '47%')
      .height(40)
      .fontSize(13)
      .fontColor(selected ? Color.White : '#475467')
      .backgroundColor(selected ? '#2F6BFF' : '#F2F4F7')
      .border({ width: 1, color: selected ? '#2F6BFF' : '#EAECF0' })
      .borderRadius(12)
      .margin({ right: 6, bottom: 8 })
      .enabled(this.canEdit())
      .onClick(() => {
        if (optionType === 'grade') this.grade = label;
        if (optionType === 'subject') this.subject = label;
        if (optionType === 'goal') this.learningGoal = label;
      })
  }

  @Builder
  private timeOption(minutes: string, title: string) {
    Column({ space: 3 }) {
      Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.weeklyMinutes === minutes ? Color.White : '#344054')
      Text(`${minutes}分钟`).fontSize(11).fontColor(this.weeklyMinutes === minutes ? '#EAF0FF' : '#98A2B3')
    }
    .width('47%')
    .height(58)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.weeklyMinutes === minutes ? '#2F6BFF' : '#F2F4F7')
    .borderRadius(12)
    .margin({ right: 6, bottom: 8 })
    .enabled(this.canEdit())
    .onClick(() => this.weeklyMinutes = minutes)
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.studentProfileId > 0 ? '学生档案' : '创建学生档案' })
        if (this.isLoading && !this.name) {
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
                    Text(this.studentProfileId > 0 ? '完善学生学情' : '创建专属学习档案')
                      .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#173B7A')
                    Text('用于AI课程推荐、专项试卷和学习计划生成')
                      .fontSize(12).fontColor('#526581').lineHeight(18)
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(`${this.completion()}%`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
                }.width('100%')
                Progress({ value: this.completion(), total: 100, type: ProgressType.Linear })
                  .color('#2F6BFF').backgroundColor('#DDE7FF').width('100%')
                Text(this.canEdit() ? '请根据孩子最近的实际学习情况填写，之后可以随时修改。' : '学生账号仅可查看档案，如需修改请联系家长账号。')
                  .fontSize(12).fontColor('#667085').width('100%')
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
                  .height(48).enabled(this.canEdit()).backgroundColor('#F7F9FC').borderRadius(12)
                  .onChange((value: string) => this.name = value)
                this.fieldTitle('当前年级', '小学一至六年级')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.grades, (item: string) => {
                    this.optionButton(item, this.grade === item, 'grade')
                  }, (item: string) => item)
                }.width('100%')
              }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)

              Column({ space: 13 }) {
                this.sectionHeader('当前学情', '成绩和薄弱点将直接影响课程等级与试卷推荐。')
                this.fieldTitle('主要科目', '当前重点提升科目')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.subjects, (item: string) => {
                    this.optionButton(item, this.subject === item, 'subject')
                  }, (item: string) => item)
                }.width('100%')
                this.fieldTitle('最近成绩', '0–100分')
                TextInput({ placeholder: '请输入最近一次考试或测评成绩', text: this.scoreText })
                  .type(InputType.Number).height(48).enabled(this.canEdit()).backgroundColor('#F7F9FC').borderRadius(12)
                  .onChange((value: string) => this.scoreText = value)
                Text('建议填写最近一次正式考试或阶段测评成绩。').fontSize(11).fontColor('#98A2B3').width('100%')
                this.fieldTitle('薄弱知识点', `已选${this.weakPoints.length}/10`)
                Text('点击下方标签可多选，再次点击即可取消。').fontSize(11).fontColor('#98A2B3').width('100%')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.weakPointSuggestions(), (item: string) => {
                    Button(item)
                      .height(36).fontSize(12)
                      .fontColor(this.weakPoints.indexOf(item) >= 0 ? Color.White : '#475467')
                      .backgroundColor(this.weakPoints.indexOf(item) >= 0 ? '#7A5AF8' : '#F2F4F7')
                      .borderRadius(18).margin({ right: 8, bottom: 8 }).enabled(this.canEdit())
                      .onClick(() => this.toggleWeakPoint(item))
                  }, (item: string) => item)
                }.width('100%')
                if (this.weakPoints.length > 0) {
                  Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                    ForEach(this.weakPoints, (item: string) => {
                      Button(this.canEdit() ? `${item} ×` : item)
                        .height(34).fontSize(12).fontColor('#2F6BFF').backgroundColor('#EEF4FF')
                        .borderRadius(17).margin({ right: 8, bottom: 8 })
                        .onClick(() => this.toggleWeakPoint(item))
                    }, (item: string) => item)
                  }.width('100%')
                }
                if (this.canEdit()) {
                  Row({ space: 8 }) {
                    TextInput({ placeholder: '没有合适选项？输入一个知识点', text: this.customWeakPoint })
                      .height(44).layoutWeight(1).backgroundColor('#F7F9FC').borderRadius(12)
                      .onChange((value: string) => this.customWeakPoint = value)
                    Button('添加').height(42).fontSize(13).backgroundColor('#EEF4FF').fontColor('#2F6BFF')
                      .onClick(() => this.addCustomWeakPoint())
                  }.width('100%')
                }
              }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)

              Column({ space: 13 }) {
                this.sectionHeader('学习目标', '明确本阶段最希望获得的学习效果。')
                this.fieldTitle('主要目标', '单选')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  ForEach(this.goals, (item: string) => {
                    this.optionButton(item, this.learningGoal === item, 'goal')
                  }, (item: string) => item)
                }.width('100%')
              }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)

              Column({ space: 13 }) {
                this.sectionHeader('学习安排', '设置每周可用于课程、试卷和错题复习的总时间。')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
                  this.timeOption('90', '轻量安排')
                  this.timeOption('180', '标准安排')
                  this.timeOption('300', '加强训练')
                  this.timeOption('420', '冲刺计划')
                }.width('100%')
                this.fieldTitle('自定义每周时间', '30–2000分钟')
                TextInput({ placeholder: '输入每周学习分钟数', text: this.weeklyMinutes })
                  .type(InputType.Number).height(48).enabled(this.canEdit()).backgroundColor('#F7F9FC').borderRadius(12)
                  .onChange((value: string) => this.weeklyMinutes = value)
              }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)

              if (this.bindCode && this.role === 'parent') {
                Column({ space: 10 }) {
                  this.sectionHeader('家庭与学生绑定', '学生账号使用一次性绑定码加入当前家庭。')
                  Row() {
                    Column({ space: 3 }) {
                      Text('学生档案绑定码').fontSize(12).fontColor('#667085')
                      Text(this.bindCode).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Button('复制').height(36).fontSize(12).backgroundColor('#EEF4FF').fontColor('#2F6BFF')
                      .onClick(() => void this.copyBindCode())
                  }.width('100%')
                  Text('绑定成功后该绑定码会失效，请勿公开分享。').fontSize(11).fontColor('#98A2B3').width('100%')
                }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
              }

              if (this.usingMockData) {
                Text('当前后端暂不可用，本页正在使用运行期演示数据；应用重启后演示修改会重置。')
                  .fontSize(11).fontColor('#B54708').lineHeight(18).width('100%')
                  .padding(12).backgroundColor('#FFFAEB').borderRadius(12)
              }
              if (this.formError) {
                Text(this.formError).fontSize(12).fontColor('#B42318').width('100%')
                  .padding(12).backgroundColor('#FEF3F2').borderRadius(12)
              }
              if (this.canEdit()) {
                Button(this.isSaving ? '保存中…' : '保存学生档案')
                  .width('100%').height(50).enabled(!this.isSaving)
                  .backgroundColor('#2F6BFF').fontSize(16).fontWeight(FontWeight.Medium)
                  .onClick(() => void this.save())
              }
            }.padding({ left: 16, right: 16, top: 12, bottom: 30 }).width('100%')
          }.layoutWeight(1).width('100%')
        }
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
