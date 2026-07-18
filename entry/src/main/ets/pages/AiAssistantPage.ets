import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { speechAiService } from '../ai/SpeechAiService';
import { AppRoutes } from '../common/AppRoutes';
import { AppConfig } from '../common/AppConfig';
import { MainTabBar } from '../components/MainTabBar';
import { ChatMessage } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';
import { AiChatResult, AiService } from '../service/AiService';

@Component
export struct AiAssistantPage {
  @State inputText: string = '';
  @State messages: ChatMessage[] = MockDataService.welcomeMessages();
  @State isLoading: boolean = false;
  @State isRecording: boolean = false;
  @State sessionId: string = '';

  private addMessage(role: string, content: string): void {
    const message: ChatMessage = { id: `${role}_${Date.now()}`, role: role, content: content, createTime: '现在' };
    this.messages = this.messages.concat([message]);
  }

  private buildMockAnswer(question: string): string {
    const hasGrade: boolean = question.includes('五年级') || question.includes('六年级');
    const hasSubject: boolean = question.includes('数学') || question.includes('英语');
    const hasScore: boolean = /\d{2,3}分?/.test(question);
    if (!hasGrade) return '为了给出准确建议，请先告诉我孩子当前是五年级还是六年级。';
    if (!hasSubject) return '请问需要咨询数学课程还是英语课程？';
    if (!hasScore) return '请补充最近一次考试成绩，以及主要薄弱知识点。';
    const scoreMatch: RegExpMatchArray | null = question.match(/\d{2,3}/);
    const score: number = scoreMatch ? Number(scoreMatch[0]) : 75;
    let level: string = score < 60 ? '基础巩固型' : score < 85 ? '中等提升型' : '拔高拓展型';
    if (question.includes('巩固基础')) level = '基础巩固型';
    return `推荐等级：${level}\n\n推荐理由：根据您提供的年级、科目和最近成绩，孩子当前更适合${level}课程。建议先针对薄弱知识点完成专项训练，再根据阶段测评调整难度。\n\n配套建议：每周学习3次，每次40-60分钟，并完成一份对应难度试卷。`;
  }

  private async sendMessage(): Promise<void> {
    const question: string = this.inputText.trim();
    if (!question || this.isLoading) return;
    this.addMessage('user', question);
    this.inputText = '';
    this.isLoading = true;
    try {
      if (AppConfig.USE_MOCK_DATA) {
        await new Promise<void>((resolve: () => void) => setTimeout(resolve, 500));
        this.addMessage('assistant', this.buildMockAnswer(question));
      } else {
        const result: AiChatResult = await AiService.sendMessage(1, question, this.sessionId);
        this.sessionId = result.sessionId;
        this.addMessage('assistant', result.assistantMessage);
      }
    } catch (error) {
      promptAction.showToast({ message: '当前智能推荐服务暂时不可用，请稍后重试' });
      console.error(`AI 对话失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
    }
  }

  private async toggleVoice(): Promise<void> {
    if (this.isRecording) {
      speechAiService.stopListening();
      this.isRecording = false;
      return;
    }
    if (!speechAiService.isAsrSupported()) {
      promptAction.showToast({ message: '当前设备不支持语音识别，可继续使用文字输入' });
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const granted: boolean = await speechAiService.requestMicrophonePermission(context);
      if (!granted) {
        promptAction.showToast({ message: '请允许使用麦克风' });
        return;
      }
      this.isRecording = await speechAiService.startListening((text: string, isFinal: boolean, isLast: boolean) => {
        this.inputText = text;
        if (isFinal || isLast) this.isRecording = false;
      }, (_code: number, message: string) => {
        this.isRecording = false;
        promptAction.showToast({ message: `语音识别失败：${message}` });
      });
    } catch (error) {
      this.isRecording = false;
      promptAction.showToast({ message: '语音能力启动失败' });
    }
  }

  private async readLastAnswer(): Promise<void> {
    for (let index: number = this.messages.length - 1; index >= 0; index--) {
      if (this.messages[index].role === 'assistant') {
        const success: boolean = await speechAiService.speak(this.messages[index].content);
        if (!success) promptAction.showToast({ message: '当前设备不支持语音播报' });
        return;
      }
    }
  }

  aboutToDisappear(): void {
    speechAiService.cancelListening();
    speechAiService.stopSpeak();
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('AI 学习顾问').fontSize(24).fontWeight(FontWeight.Bold).layoutWeight(1)
          Text('清空').fontColor('#F04438').onClick(() => this.messages = MockDataService.welcomeMessages())
        }.padding(20).width('100%')
        List({ space: 10 }) {
          ForEach(this.messages, (message: ChatMessage) => {
            ListItem() {
              Row() {
                if (message.role === 'assistant') Blank().layoutWeight(1)
                Column({ space: 5 }) {
                  Text(message.role === 'assistant' ? '智学助手' : '我').fontSize(11).fontColor('#667085').width('100%')
                  Text(message.content).fontSize(15).fontColor(message.role === 'assistant' ? '#101828' : Color.White).lineHeight(22)
                }
                .padding(12)
                .constraintSize({ maxWidth: '82%' })
                .backgroundColor(message.role === 'assistant' ? Color.White : '#2F6BFF')
                .borderRadius(15)
                if (message.role === 'user') Blank().layoutWeight(1)
              }.width('100%')
            }
          }, (message: ChatMessage) => message.id)
          if (this.isLoading) {
            ListItem() { Text('智学助手正在分析...').fontColor('#667085').padding(12) }
          }
        }.layoutWeight(1).padding({ left: 14, right: 14 }).width('100%')
        Row({ space: 8 }) {
          Button(this.isRecording ? '停止' : '语音').fontSize(13).height(44).backgroundColor(this.isRecording ? '#F04438' : '#7A5AF8').onClick(() => void this.toggleVoice())
          TextInput({ placeholder: '描述孩子的学情...', text: this.inputText }).layoutWeight(1).height(44).onChange((value: string) => this.inputText = value)
          Button('发送').fontSize(13).height(44).enabled(!this.isLoading).backgroundColor('#2F6BFF').onClick(() => void this.sendMessage())
          Button('朗读').fontSize(13).height(44).backgroundColor('#12B76A').onClick(() => void this.readLastAnswer())
        }.padding(10).width('100%').backgroundColor(Color.White)
        MainTabBar({ activeRoute: AppRoutes.AI_ASSISTANT })
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
