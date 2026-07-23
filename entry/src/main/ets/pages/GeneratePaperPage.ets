import { promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { AIPaperService, GeneratePaperBody } from '../service/AIPaperService';

@Component
export struct GeneratePaperPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State requirement: string = '';
  @State grade: string = '五年级';
  @State submitting: boolean = false;

  private async submit(): Promise<void> {
    const req = this.requirement.trim();
    if (!req) {
      promptAction.showToast({ message: '请描述你想要的试卷' });
      return;
    }
    const profileId = this.studentProfileId;
    this.submitting = true;
    try {
      const body: GeneratePaperBody = {
        studentProfileId: profileId,
        requirement: req,
        grade: this.grade,
        subject: '数学',
        basedOnWrongQuestions: false,
      };
      const result = await AIPaperService.generate(body);
      promptAction.showToast({ message: '组卷成功，已加入我的试卷' });
      const param: IdRouteParam = new IdRouteParam();
      param.id = result.id;
      this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
    } catch (error) {
      promptAction.showToast({ message: '组卷失败，请稍后重试' });
      console.error(`AI 组卷失败: ${JSON.stringify(error)}`);
    } finally {
      this.submitting = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: 'AI 组卷' })
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 8 }) {
              Text('想要什么样的试卷？').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
              Text('例如：一套百分数训练卷、一套综合复习卷、根据我的错题出类似题').fontSize(12).fontColor('#667085').width('100%')
            }.width('100%')

            Column({ space: 8 }) {
              Text('需求描述').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#344054').width('100%')
              TextArea({ placeholder: '请描述你想要的试卷内容、难度、知识点范围', text: this.requirement })
                .height(140)
                .backgroundColor('#F9FAFB')
                .borderRadius(12)
                .onChange((value: string) => this.requirement = value)
            }.width('100%')

            Button(this.submitting ? 'AI 正在组卷...' : '开始组卷')
              .width('100%')
              .height(48)
              .backgroundColor('#2F6BFF')
              .enabled(!this.submitting)
              .onClick(() => { void this.submit(); })

            Text('组卷需要联网调用 AI，耗时约 5~15 秒，请耐心等待')
              .fontSize(11)
              .fontColor('#667085')
              .width('100%')
          }.padding(16).width('100%')
        }.layoutWeight(1).width('100%')
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
