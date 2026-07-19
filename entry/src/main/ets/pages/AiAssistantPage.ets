import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { speechAiService } from '../ai/SpeechAiService';
import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { AiResponseCard } from '../components/ai/AiResponseCard';
import { MainTabBar } from '../components/MainTabBar';
import { AiCard, AiChatHistory, AiChatResult, AiHistoryMessage, AiSource, AiStreamCallbacks } from '../model/AiModels';
import { ChatMessage } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';
import { ChatViewModel } from '../viewModel/ChatViewModel';

@Component
export struct AiAssistantPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State inputText: string = '';
  @State messages: ChatMessage[] = MockDataService.welcomeMessages();
  @State cards: AiCard[] = [];
  @State sources: AiSource[] = [];
  @State isLoading: boolean = false;
  @State isRecording: boolean = false;
  @State isRestoring: boolean = true;
  @State sessionId: string = '';
  @State streamingText: string = '';
  @State currentIntent: string = '';
  @State fallbackUsed: boolean = false;
  @State lastQuestion: string = '';
  @State errorMessage: string = '';

  aboutToAppear(): void {
    void this.restoreHistory();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private addMessage(role: string, content: string): void {
    const message: ChatMessage = { id: `${role}_${Date.now()}_${this.messages.length}`, role: role, content: content, createTime: '现在' };
    this.messages = this.messages.concat([message]);
  }

  private async restoreHistory(): Promise<void> {
    this.isRestoring = true;
    try {
      const history: AiChatHistory | null = await ChatViewModel.restore(this.context());
      if (history && history.messages.length > 0) {
        const restored: ChatMessage[] = [];
        for (let index: number = 0; index < history.messages.length; index++) {
          const item: AiHistoryMessage = history.messages[index];
          restored.push({ id: `${item.id}`, role: item.role, content: item.content, createTime: item.createTime });
        }
        this.messages = restored;
        this.sessionId = history.sessionId;
      }
    } finally {
      this.isRestoring = false;
    }
  }

  private async sendQuestion(questionText: string): Promise<void> {
    const question: string = questionText.trim();
    if (!question || this.isLoading) return;
    if (this.studentProfileId <= 0) {
      promptAction.showToast({ message: '请先创建或绑定学生档案，再使用个性化 AI 顾问' });
      this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null);
      return;
    }
    this.lastQuestion = question;
    this.errorMessage = '';
    this.cards = [];
    this.sources = [];
    this.streamingText = '';
    this.addMessage('user', question);
    this.inputText = '';
    this.isLoading = true;
    const callbacks: AiStreamCallbacks = {
      onDelta: (content: string): void => { this.streamingText += content; },
      onIntent: (intent: string): void => { this.currentIntent = intent; }
    };
    try {
      const result: AiChatResult = await ChatViewModel.send(
        this.context(), this.studentProfileId,
        question, this.sessionId, callbacks
      );
      this.sessionId = result.sessionId;
      this.currentIntent = result.intent;
      this.fallbackUsed = result.fallbackUsed;
      this.cards = result.cards || [];
      this.sources = result.sources || [];
      this.addMessage('assistant', result.answer || result.assistantMessage);
      this.streamingText = '';
    } catch (error) {
      this.streamingText = '';
      this.errorMessage = '连接智能服务失败，已保留当前对话，可点击重试。';
      promptAction.showToast({ message: '智能服务暂时不可用，请检查后端网络' });
      console.error(`AI 对话失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
    }
  }

  private async clearConversation(): Promise<void> {
    if (this.isLoading) return;
    try {
      await ChatViewModel.clear(this.context(), this.sessionId);
      this.sessionId = '';
      this.cards = [];
      this.sources = [];
      this.messages = MockDataService.welcomeMessages();
      this.errorMessage = '';
    } catch (error) {
      promptAction.showToast({ message: '清空会话失败，请稍后重试' });
    }
  }

  private async newConversation(): Promise<void> {
    this.sessionId = '';
    this.cards = [];
    this.sources = [];
    this.messages = MockDataService.welcomeMessages();
    this.errorMessage = '';
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
    try {
      const granted: boolean = await speechAiService.requestMicrophonePermission(this.context());
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
    try {
      for (let index: number = this.messages.length - 1; index >= 0; index--) {
        if (this.messages[index].role === 'assistant') {
          const success: boolean = await speechAiService.speak(this.messages[index].content);
          if (!success) promptAction.showToast({ message: '当前设备不支持语音播报' });
          return;
        }
      }
    } catch (error) {
      promptAction.showToast({ message: '语音播报失败' });
    }
  }

  aboutToDisappear(): void {
    speechAiService.cancelListening();
    speechAiService.stopSpeak();
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 12 }) {
          Column({ space: 3 }) {
            Text('AI 学习顾问').fontSize(23).fontWeight(FontWeight.Bold).width('100%')
            Text(this.currentIntent ? `当前意图：${this.currentIntent}` : '课程、试卷、计划和学情一站式咨询').fontSize(11).fontColor('#667085').width('100%')
          }.layoutWeight(1)
          Text('新会话').fontSize(12).fontColor('#2F6BFF').onClick(() => void this.newConversation())
          Text('清空').fontSize(12).fontColor('#F04438').onClick(() => void this.clearConversation())
        }.padding({ left: 18, right: 18, top: 14, bottom: 10 }).width('100%')

        if (this.messages.length <= 1) {
          List({ space: 8 }) {
            ForEach(ChatViewModel.QUICK_QUESTIONS, (question: string) => {
              ListItem() {
                Text(question).fontSize(12).fontColor('#344054').padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor('#EEF4FF').borderRadius(16).onClick(() => void this.sendQuestion(question))
              }
            }, (question: string) => question)
          }.listDirection(Axis.Horizontal).height(42).padding({ left: 14, right: 14 }).width('100%')
        }

        List({ space: 10 }) {
          ForEach(this.messages, (message: ChatMessage) => {
            ListItem() {
              Row() {
                if (message.role === 'assistant') Blank().layoutWeight(1)
                Column({ space: 5 }) {
                  Text(message.role === 'assistant' ? '智学助手' : '我').fontSize(11).fontColor('#667085').width('100%')
                  Text(message.content).fontSize(15).fontColor(message.role === 'assistant' ? '#101828' : Color.White).lineHeight(22)
                }.padding(12).constraintSize({ maxWidth: '84%' })
                  .backgroundColor(message.role === 'assistant' ? Color.White : '#2F6BFF').borderRadius(15)
                if (message.role === 'user') Blank().layoutWeight(1)
              }.width('100%')
            }
          }, (message: ChatMessage) => message.id)
          if (this.isLoading) {
            ListItem() {
              Text(this.streamingText || '智学助手正在调用学习工具...').fontColor('#667085').padding(12)
                .backgroundColor(Color.White).borderRadius(14)
            }
          }
          if (this.errorMessage) {
            ListItem() {
              Row() {
                Text(this.errorMessage).fontSize(12).fontColor('#B42318').layoutWeight(1)
                Text('重试').fontSize(13).fontColor('#2F6BFF').onClick(() => void this.sendQuestion(this.lastQuestion))
              }.padding(12).backgroundColor('#FEF3F2').borderRadius(12)
            }
          }
        }.layoutWeight(1).padding({ left: 14, right: 14 }).width('100%')

        if (this.cards.length > 0) {
          List({ space: 10 }) {
            ForEach(this.cards, (card: AiCard) => {
              ListItem() { AiResponseCard({ card: card }) }
            }, (card: AiCard) => `${card.type}_${card.id}`)
          }.listDirection(Axis.Horizontal).height(138).padding({ left: 14, right: 14 }).width('100%')
        }
        if (this.sources.length > 0 || this.fallbackUsed) {
          Row({ space: 8 }) {
            if (this.fallbackUsed) Text('Mock兜底').fontSize(10).fontColor('#B54708')
            if (this.sources.length > 0) Text(`参考来源 ${this.sources.length} 条`).fontSize(10).fontColor('#667085')
          }.padding({ left: 16, right: 16, bottom: 4 }).width('100%')
        }
        Row({ space: 7 }) {
          Button(this.isRecording ? '停止' : '语音').fontSize(12).height(42).backgroundColor(this.isRecording ? '#F04438' : '#7A5AF8').onClick(() => void this.toggleVoice())
          TextInput({ placeholder: '描述学生学情或提出学习问题...', text: this.inputText }).layoutWeight(1).height(42).onChange((value: string) => this.inputText = value)
          Button('发送').fontSize(12).height(42).enabled(!this.isLoading && !this.isRestoring).backgroundColor('#2F6BFF').onClick(() => void this.sendQuestion(this.inputText))
          Button('朗读').fontSize(12).height(42).backgroundColor('#12B76A').onClick(() => void this.readLastAnswer())
        }.padding(9).width('100%').backgroundColor(Color.White)
        MainTabBar({ activeRoute: AppRoutes.AI_ASSISTANT })
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
