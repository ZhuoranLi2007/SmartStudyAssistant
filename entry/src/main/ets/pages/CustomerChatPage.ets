import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { ProfileMockData } from '../data/ProfileMockData';
import { CustomerMessage } from '../model/ProfileModels';

@Component
export struct CustomerChatPage {
  @State messages: CustomerMessage[] = ProfileMockData.getCustomerMessages();
  @State inputText: string = '';
  @State isReplying: boolean = false;

  private send(): void {
    const text: string = this.inputText.trim();
    if (!text || this.isReplying) return;
    this.messages.push({ id: `user_${Date.now()}`, fromUser: true, content: text, createTime: '刚刚' });
    this.inputText = '';
    this.isReplying = true;
    setTimeout(() => {
      this.messages.push({ id: `service_${Date.now()}`, fromUser: false, content: '已收到您的问题。当前为本地演示客服，您也可以在常见问题中查找答案。', createTime: '刚刚' });
      this.messages = this.messages.slice();
      this.isReplying = false;
    }, 600);
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '在线客服' })
        List({ space: 10 }) {
          ForEach(this.messages, (message: CustomerMessage) => {
            ListItem() {
              Row() {
                if (message.fromUser) Blank()
                Column({ space: 4 }) {
                  Text(message.content).fontSize(14).fontColor(message.fromUser ? Color.White : '#344054').lineHeight(21)
                  Text(message.createTime).fontSize(10).fontColor(message.fromUser ? '#DDE7FF' : '#98A2B3')
                }.alignItems(message.fromUser ? HorizontalAlign.End : HorizontalAlign.Start)
                  .padding(12).constraintSize({ maxWidth: '78%' })
                  .backgroundColor(message.fromUser ? '#2F6BFF' : Color.White).borderRadius(14)
                if (!message.fromUser) Blank()
              }.width('100%')
            }
          }, (message: CustomerMessage) => message.id)
        }.layoutWeight(1).padding({ left: 14, right: 14, top: 12, bottom: 8 }).width('100%')
        if (this.isReplying) Text('客服正在回复...').fontSize(11).fontColor('#98A2B3').margin({ bottom: 5 })
        Row({ space: 8 }) {
          TextInput({ placeholder: '请输入您的问题', text: this.inputText }).layoutWeight(1).onChange((value: string) => this.inputText = value)
          Button('发送').enabled(!this.isReplying).backgroundColor('#2F6BFF').onClick(() => {
            if (!this.inputText.trim()) promptAction.showToast({ message: '请输入问题' }); else this.send();
          })
        }.padding({ left: 12, right: 12, top: 8, bottom: 14 }).backgroundColor(Color.White).width('100%')
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
