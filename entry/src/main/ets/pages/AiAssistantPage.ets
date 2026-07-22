import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { speechAiService } from '../ai/SpeechAiService';
import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { ChatInputBar } from '../components/chat/ChatInputBar';
import { ChatMessageBubble } from '../components/chat/ChatMessageBubble';
import { SuggestionChip } from '../components/chat/SuggestionChip';
import { MainTabBar } from '../components/MainTabBar';
import {
  AiChatHistory,
  AiChatResult,
  AiHistoryMessage,
  AiSource,
  AiStreamCallbacks,
  ChatMessage,
  ChatRole,
  QuickQuestion
} from '../model/AiModels';
import { AiService } from '../service/AiService';
import { ChatViewModel } from '../viewModel/ChatViewModel';
import { StudentProfile } from '../model/DomainModels';
import { StudentService } from '../service/StudentService';

@Component
export struct AiAssistantPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State inputText: string = '';
  @State messages: ChatMessage[] = ChatViewModel.welcomeMessages();
  @State isLoading: boolean = false;
  @State isRecording: boolean = false;
  @State isRestoring: boolean = true;
  @State sessionId: string = '';
  @State currentIntent: string = '';
  @State linkedStudentText: string = '';
  @State speakingMessageId: string = '';
  private messageScroller: Scroller = new Scroller();
  private asrTimeoutId: number = -1;
  private asrHasResult: boolean = false;

  aboutToAppear(): void {
    void this.restoreHistory();
    void this.loadLinkedStudent();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private roleFromText(role: string): ChatRole {
    if (role === ChatRole.USER) return ChatRole.USER;
    if (role === ChatRole.SYSTEM) return ChatRole.SYSTEM;
    return ChatRole.ASSISTANT;
  }

  private copyMessage(message: ChatMessage): ChatMessage {
    return {
      id: message.id,
      revision: message.revision,
      role: message.role,
      content: message.content,
      createdAt: message.createdAt,
      createTime: message.createTime,
      isStreaming: message.isStreaming,
      fallbackUsed: message.fallbackUsed,
      intent: message.intent,
      cards: message.cards.slice(),
      sources: message.sources.slice(),
      errorMessage: message.errorMessage,
      clientMessageId: message.clientMessageId,
      retryQuestion: message.retryQuestion
    };
  }

  private replaceMessage(updated: ChatMessage): void {
    updated.revision++;
    const next: ChatMessage[] = [];
    for (let index: number = 0; index < this.messages.length; index++) {
      next.push(this.messages[index].id === updated.id ? updated : this.messages[index]);
    }
    this.messages = next;
    this.scrollToBottom();
  }

  private currentMessage(messageId: string): ChatMessage | null {
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id === messageId) return this.messages[index];
    }
    return null;
  }

  private async loadLinkedStudent(): Promise<void> {
    if (this.studentProfileId <= 0) {
      this.linkedStudentText = '';
      return;
    }
    try {
      const profile: StudentProfile = await StudentService.getProfile(this.studentProfileId);
      this.linkedStudentText = `${profile.name} · ${profile.grade} · ${profile.subject}`;
    } catch (error) {
      this.linkedStudentText = '';
      console.warn(`AI关联学生档案加载失败: ${JSON.stringify(error)}`);
    }
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      try {
        if (this.messages.length > 0) this.messageScroller.scrollToIndex(this.messages.length - 1, true, ScrollAlign.END);
      } catch (error) {
        console.warn(`聊天列表滚动失败: ${JSON.stringify(error)}`);
      }
    }, 40);
  }

  private appendDelta(messageId: string, delta: string): void {
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id === messageId) {
        const updated: ChatMessage = this.copyMessage(this.messages[index]);
        updated.content += delta;
        updated.isStreaming = true;
        this.replaceMessage(updated);
        return;
      }
    }
  }

  private appendSource(messageId: string, source: AiSource): void {
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id === messageId) {
        const updated: ChatMessage = this.copyMessage(this.messages[index]);
        updated.sources = updated.sources.concat([source]);
        this.replaceMessage(updated);
        return;
      }
    }
  }

  private async restoreHistory(): Promise<void> {
    this.isRestoring = true;
    try {
      const history: AiChatHistory | null = await ChatViewModel.restore(this.context());
      if (history && history.messages.length > 0) {
        const restored: ChatMessage[] = [];
        for (let index: number = 0; index < history.messages.length; index++) {
          const item: AiHistoryMessage = history.messages[index];
          const message: ChatMessage = ChatViewModel.createMessage(this.roleFromText(item.role), item.content);
          message.id = `history_${item.id}`;
          message.createTime = item.createTime;
          message.intent = item.intent;
          restored.push(message);
        }
        this.messages = restored;
        this.sessionId = history.sessionId;
        this.scrollToBottom();
      }
    } finally {
      this.isRestoring = false;
    }
  }

  private async sendQuestion(questionText: string, retryMessage?: ChatMessage): Promise<void> {
    const question: string = questionText.trim();
    if (!question || this.isLoading) return;
    const clientMessageId: string = retryMessage ? retryMessage.clientMessageId : AiService.createClientMessageId();
    let assistantMessage: ChatMessage;
    if (retryMessage) {
      assistantMessage = this.copyMessage(retryMessage);
      assistantMessage.content = '';
      assistantMessage.cards = [];
      assistantMessage.sources = [];
      assistantMessage.errorMessage = '';
      assistantMessage.isStreaming = true;
      this.replaceMessage(assistantMessage);
    } else {
      const userMessage: ChatMessage = ChatViewModel.createMessage(ChatRole.USER, question, clientMessageId);
      assistantMessage = ChatViewModel.createMessage(ChatRole.ASSISTANT, '', clientMessageId);
      assistantMessage.isStreaming = true;
      assistantMessage.retryQuestion = question;
      this.messages = this.messages.concat([userMessage, assistantMessage]);
      this.inputText = '';
      this.scrollToBottom();
    }
    this.isLoading = true;
    const assistantId: string = assistantMessage.id;
    const callbacks: AiStreamCallbacks = {
      onDelta: (content: string): void => this.appendDelta(assistantId, content),
      onIntent: (intent: string): void => { this.currentIntent = intent; },
      onMeta: (newSessionId: string, _requestId: string): void => {
        if (newSessionId) this.sessionId = newSessionId;
      },
      onSource: (source: AiSource): void => this.appendSource(assistantId, source)
    };
    try {
      const result: AiChatResult = await ChatViewModel.send(
        this.context(), this.studentProfileId, question, this.sessionId, callbacks, clientMessageId
      );
      this.sessionId = result.sessionId;
      this.currentIntent = result.intent;
      const latest: ChatMessage | null = this.currentMessage(assistantId);
      const completed: ChatMessage = this.copyMessage(latest || assistantMessage);
      completed.content = (result.answer || result.assistantMessage || '').trim();
      completed.isStreaming = false;
      completed.fallbackUsed = result.fallbackUsed;
      completed.intent = result.intent;
      completed.cards = result.cards || [];
      completed.sources = result.sources || [];
      completed.errorMessage = completed.content ? '' : '智能服务未返回正文，可点击重试。';
      completed.retryQuestion = question;
      this.replaceMessage(completed);
    } catch (error) {
      let failed: ChatMessage = assistantMessage;
      for (let index: number = 0; index < this.messages.length; index++) {
        if (this.messages[index].id === assistantId) failed = this.copyMessage(this.messages[index]);
      }
      failed.isStreaming = false;
      failed.errorMessage = failed.content ? '回复中断，可点击重试。' : '连接智能服务失败，可点击重试。';
      failed.retryQuestion = question;
      this.replaceMessage(failed);
      promptAction.showToast({ message: '智能服务暂时不可用，请检查后端网络' });
      console.error(`AI 对话失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
      const latest: ChatMessage | null = this.currentMessage(assistantId);
      if (latest && latest.isStreaming) {
        const stopped: ChatMessage = this.copyMessage(latest);
        stopped.isStreaming = false;
        if (!stopped.content && !stopped.errorMessage) stopped.errorMessage = '回复已结束但没有收到内容，可点击重试。';
        this.replaceMessage(stopped);
      }
    }
  }

  private async confirmClear(): Promise<void> {
    try {
      await ChatViewModel.clear(this.context(), this.sessionId);
      this.sessionId = '';
      this.currentIntent = '';
      this.messages = ChatViewModel.welcomeMessages();
      this.scrollToBottom();
    } catch (error) {
      promptAction.showToast({ message: '清空会话失败，请稍后重试' });
    }
  }

  private showClearDialog(): void {
    if (this.isLoading) return;
    AlertDialog.show({
      title: '清空当前会话',
      message: '确定要清空当前会话记录吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '清空', fontColor: '#F04438', action: () => void this.confirmClear() }
    });
  }

  private async newConversation(): Promise<void> {
    if (this.isLoading) return;
    try {
      await ChatViewModel.startNewConversation(this.context());
      this.sessionId = '';
      this.currentIntent = '';
      this.messages = ChatViewModel.welcomeMessages();
      this.scrollToBottom();
    } catch (error) {
      promptAction.showToast({ message: '新会话创建失败，请稍后重试' });
    }
  }

  private clearAsrTimeout(): void {
    if (this.asrTimeoutId >= 0) {
      clearTimeout(this.asrTimeoutId);
      this.asrTimeoutId = -1;
    }
  }

  private async toggleVoice(): Promise<void> {
    if (this.isRecording) {
      speechAiService.stopListening();
      this.isRecording = false;
      this.clearAsrTimeout();
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
      this.inputText = '';
      this.asrHasResult = false;
      this.isRecording = await speechAiService.startListening((text: string, isFinal: boolean, isLast: boolean) => {
        this.asrHasResult = true;
        this.inputText = text;
        if (isFinal || isLast) {
          this.isRecording = false;
          this.clearAsrTimeout();
          const question: string = text.trim();
          if (question) {
            void this.sendQuestion(question);
          } else {
            promptAction.showToast({ message: '未识别到有效内容' });
          }
        }
      }, (_code: number, message: string) => {
        this.isRecording = false;
        this.clearAsrTimeout();
        promptAction.showToast({ message: `语音识别失败：${message}` });
      });
      if (this.isRecording) {
        promptAction.showToast({ message: '正在听，请说话…' });
        this.asrTimeoutId = setTimeout(() => {
          if (this.isRecording) {
            speechAiService.stopListening();
            this.isRecording = false;
            if (!this.asrHasResult) {
              promptAction.showToast({ message: '未检测到语音，请检查麦克风或网络' });
            }
          }
        }, 30000);
      }
    } catch (error) {
      this.isRecording = false;
      this.clearAsrTimeout();
      promptAction.showToast({ message: '语音能力启动失败' });
    }
  }

  private async readMessage(content: string, messageId: string): Promise<void> {
    if (this.speakingMessageId === messageId) {
      speechAiService.stopSpeak();
      this.speakingMessageId = '';
      return;
    }

    // 正在朗读其他消息时，先停止再切到新消息
    if (this.speakingMessageId !== '') {
      speechAiService.stopSpeak();
    }

    this.speakingMessageId = messageId;
    try {
      const success: boolean = await speechAiService.speak(content, () => {
        this.speakingMessageId = '';
      });
      if (!success) {
        this.speakingMessageId = '';
        promptAction.showToast({ message: '当前设备不支持语音播报' });
      }
    } catch (error) {
      this.speakingMessageId = '';
      promptAction.showToast({ message: '语音播报失败' });
    }
  }

  private intentText(): string {
    if (!this.currentIntent || this.currentIntent === 'GENERAL_CHAT') return '';
    const names: Map<string, string> = new Map<string, string>([
      ['COURSE_RECOMMENDATION', '课程推荐'], ['COURSE_SEARCH', '课程检索'], ['PAPER_SEARCH', '试卷推荐'],
      ['STUDY_PLAN_GENERATION', '学习计划'], ['LEARNING_ANALYSIS', '学情分析'], ['LEARNING_REPORT', '学习报告'],
      ['WRONG_QUESTION_ANALYSIS', '错题分析'], ['ORDER_CREATION', '课程订单']
    ]);
    return names.get(this.currentIntent) || this.currentIntent;
  }

  aboutToDisappear(): void {
    this.clearAsrTimeout();
    speechAiService.cancelListening();
    speechAiService.stopSpeak();
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Row({ space: 7 }) {
              Text('AI 学习顾问').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#172033')
              if (this.intentText()) {
                Text(this.intentText()).fontSize(9).fontColor('#5B65E8').padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor('#EEF1FF').borderRadius(8)
              }
            }.width('100%')
            Text('为孩子找到更合适的学习路径').fontSize(12).fontColor('#718096').width('100%')
            if (this.linkedStudentText) {
              Text(`已关联：${this.linkedStudentText}`).fontSize(10).fontColor('#2F6BFF').width('100%')
            } else {
              Text('尚未关联学生档案，点击前往创建').fontSize(10).fontColor('#B54708').width('100%')
                .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
            }
          }.layoutWeight(1)
          Text('＋ 新会话').fontSize(12).fontColor('#2F6BFF').onClick(() => void this.newConversation())
          Text('清空').fontSize(12).fontColor('#F04438').onClick(() => this.showClearDialog())
        }.padding({ left: 16, right: 16, top: 12, bottom: 10 }).width('100%')

        List({ space: 8 }) {
          ForEach(ChatViewModel.QUICK_QUESTIONS, (item: QuickQuestion) => {
            ListItem() {
              SuggestionChip({ item: item, disabled: this.isLoading || this.isRestoring,
                onSelect: (question: string): void => { void this.sendQuestion(question); } })
            }
          }, (item: QuickQuestion) => item.label)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .height(48)
        .padding({ left: 14, right: 14 })
        .width('100%')

        List({ space: 14, scroller: this.messageScroller }) {
          ForEach(this.messages, (message: ChatMessage) => {
            ListItem() {
              ChatMessageBubble({
                message: message,
                speakingMessageId: this.speakingMessageId,
                onRead: (content: string, messageId: string): void => { void this.readMessage(content, messageId); },
                onRetry: (failed: ChatMessage): void => { void this.sendQuestion(failed.retryQuestion, failed); }
              })
            }
          }, (message: ChatMessage) => `${message.id}-${message.revision}`)
        }
        .layoutWeight(1)
        .padding({ left: 13, right: 13, top: 10, bottom: 10 })
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)

        ChatInputBar({
          text: $inputText,
          isSending: this.isLoading || this.isRestoring,
          isRecording: this.isRecording,
          onSend: (): void => { void this.sendQuestion(this.inputText); },
          onVoice: (): void => { void this.toggleVoice(); }
        })
        MainTabBar({ activeRoute: AppRoutes.AI_ASSISTANT })
      }.width('100%').height('100%').backgroundColor('#F3F6FB')
    }.hideTitleBar(true)
  }
}
