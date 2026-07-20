import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';

@Component
export struct FeedbackPage {
  @State feedbackType: string = '功能建议';
  @State content: string = '';
  @State contact: string = '';
  @State isSubmitting: boolean = false;

  private async submit(): Promise<void> {
    if (this.content.trim().length < 5) { promptAction.showToast({ message: '请至少输入5个字的反馈内容' }); return; }
    if (this.isSubmitting) return; this.isSubmitting = true;
    try {
      await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500));
      this.content = ''; this.contact = '';
      promptAction.showToast({ message: '反馈已提交，感谢您的建议' });
    } finally { this.isSubmitting = false; }
  }

  @Builder
  private typeButton(label: string) {
    Button(label).fontSize(12).backgroundColor(this.feedbackType === label ? '#2F6BFF' : '#D0D5DD').onClick(() => this.feedbackType = label)
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '意见反馈' })
        Scroll() {
          Column({ space: 14 }) {
            Text('反馈类型').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
            Row({ space: 8 }) { this.typeButton('功能建议'); this.typeButton('使用问题'); this.typeButton('其他') }.width('100%')
            Text('反馈内容').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
            TextArea({ placeholder: '请描述您遇到的问题或建议（至少5个字）', text: this.content })
              .height(180).onChange((value: string) => this.content = value)
            TextInput({ placeholder: '联系方式（选填）', text: this.contact }).onChange((value: string) => this.contact = value)
            Text('反馈页面当前为本地演示，不会上传真实个人信息。').fontSize(11).fontColor('#98A2B3').width('100%')
            Button(this.isSubmitting ? '提交中...' : '提交反馈').width('100%').height(48).enabled(!this.isSubmitting).backgroundColor('#2F6BFF').onClick(() => void this.submit())
          }.padding(18).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
