import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
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
  AiSessionSummary,
  AiSource,
  AiStreamCallbacks,
  ChatMessage,
  ChatRole,
  QuickQuestion
} from '../model/AiModels';
import {
  ContinuationSnapshot,
  DistributedEntityType,
  DistributedEventType
} from '../model/DistributedStudyModels';
import { AiService } from '../service/AiService';
import { DistributedPageService } from '../service/DistributedPageService';
import { PageRefreshResult } from '../service/PageRefreshCoordinator';
import { ChatViewModel } from '../viewModel/ChatViewModel';
import { StudentProfile } from '../model/DomainModels';
import { StudentService } from '../service/StudentService';

@Component
export struct AiAssistantPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop initialSessionId: string = '';
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
  @State sessions: AiSessionSummary[] = [];
  @State showSessionList: boolean = false;
  private messageScroller: Scroller = new Scroller();
  private asrTimeoutId: number = -1;
  private asrHasResult: boolean = false;

  aboutToAppear(): void {
    const continuation = new ContinuationSnapshot();
    continuation.routeName = AppRoutes.AI_ASSISTANT;
    continuation.entityKey = this.initialSessionId;
    DistributedPageService.activate('AiAssistantPage', [
      DistributedEventType.AI_CONVERSATION_CREATED,
      DistributedEventType.AI_CONVERSATION_UPDATED,
      DistributedEventType.AI_CONVERSATION_DELETED,
      DistributedEventType.AI_CONVERSATION_CLEARED,
      DistributedEventType.AI_CONVERSATION_LIST_UPDATED
    ], async (): Promise<PageRefreshResult> => {
      if (this.isLoading) return PageRefreshResult.BUSY;
      await this.loadSessions();
      if (this.sessionId) await this.mergeCurrentHistory();
      return PageRefreshResult.SUCCESS;
    }, continuation);
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
      const history: AiChatHistory | null = await ChatViewModel.restore(this.context(), this.initialSessionId);
      if (history) {
        this.sessionId = history.sessionId;
        if (history.messages.length > 0) this.mergeHistory(history, true);
        this.updateContinuation();
      }
      await this.loadSessions();
    } finally {
      this.isRestoring = false;
    }
  }

  private async loadSessions(): Promise<void> {
    if (this.studentProfileId <= 0) return;
    try {
      this.sessions = await AiService.getSessions(this.studentProfileId);
    } catch (error) {
      console.warn(`AI会话列表加载失败: ${JSON.stringify(error)}`);
    }
  }

  private mergeHistory(history: AiChatHistory, replaceWelcome: boolean = false): void {
    const next: ChatMessage[] = replaceWelcome ? [] : this.messages.slice();
    for (let historyIndex: number = 0; historyIndex < history.messages.length; historyIndex++) {
      const item: AiHistoryMessage = history.messages[historyIndex];
      const historyId: string = `history_${item.id}`;
      let foundIndex: number = -1;
      for (let messageIndex: number = 0; messageIndex < next.length; messageIndex++) {
        const current: ChatMessage = next[messageIndex];
        if (current.id === historyId || (item.clientMessageId &&
          current.clientMessageId === item.clientMessageId && current.role === this.roleFromText(item.role))) {
          foundIndex = messageIndex;
          break;
        }
      }
      if (foundIndex >= 0 && next[foundIndex].isStreaming) continue;
      const message: ChatMessage = ChatViewModel.createMessage(
        this.roleFromText(item.role), item.content, item.clientMessageId || ''
      );
      message.id = historyId;
      message.createTime = item.createTime;
      message.intent = item.intent;
      message.cards = item.cards || [];
      message.sources = item.sources || [];
      message.fallbackUsed = item.fallbackUsed || false;
      if (foundIndex >= 0) next[foundIndex] = message; else next.push(message);
    }
    this.messages = next.length > 0 ? next : ChatViewModel.welcomeMessages();
    this.scrollToBottom();
  }

  private async mergeCurrentHistory(): Promise<void> {
    if (!this.sessionId) return;
    const history: AiChatHistory = await AiService.getHistory(this.sessionId);
    this.mergeHistory(history);
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
        if (newSessionId) {
          this.sessionId = newSessionId;
          this.updateContinuation();
        }
      },
      onSource: (source: AiSource): void => this.appendSource(assistantId, source),
      onMessageSaved: (newSessionId: string, _messageId: number, _clientId: string): void => {
        if (newSessionId) this.sessionId = newSessionId;
        DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_UPDATED,
          DistributedEntityType.AI_CONVERSATION, 0, newSessionId);
        DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_LIST_UPDATED,
          DistributedEntityType.AI_CONVERSATION);
        this.updateContinuation();
      }
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
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_UPDATED,
        DistributedEntityType.AI_CONVERSATION, 0, result.sessionId);
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_LIST_UPDATED,
        DistributedEntityType.AI_CONVERSATION);
      this.updateContinuation();
    } catch (error) {
      let failed: ChatMessage = assistantMessage;
      for (let index: number = 0; index < this.messages.length; index++) {
        if (this.messages[index].id === assistantId) failed = this.copyMessage(this.messages[index]);
      }
      failed.isStreaming = false;
      failed.errorMessage = this.aiFailureMessage(error, !!failed.content);
      failed.retryQuestion = question;
      this.replaceMessage(failed);
      this.showCurrentToast(failed.errorMessage);
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
      await this.loadSessions();
      if (this.sessionId) {
        try { await this.mergeCurrentHistory(); } catch (error) {
          console.warn(`AI请求结束后合并历史失败: ${JSON.stringify(error)}`);
        }
      }
    }
  }

  private aiFailureMessage(error: Object, hasPartialContent: boolean): string {
    if (hasPartialContent) return '回复中断，可点击重试。';
    const detail: string = error instanceof Error ? error.message : JSON.stringify(error);
    if (detail.indexOf('SERVICE:') >= 0 || detail.indexOf('HTTP 5') >= 0) {
      return '智能服务处理失败，可点击重试。';
    }
    if (detail.indexOf('2300028') >= 0 || detail.indexOf('Network') >= 0 || detail.indexOf('connect') >= 0) {
      return '网络连接失败，请检查网络后重试。';
    }
    return '智能服务暂时不可用，可点击重试。';
  }

  private async confirmClear(): Promise<void> {
    try {
      await ChatViewModel.clear(this.context(), this.sessionId);
      this.currentIntent = '';
      this.messages = ChatViewModel.welcomeMessages();
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_CLEARED,
        DistributedEntityType.AI_CONVERSATION, 0, this.sessionId);
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_LIST_UPDATED,
        DistributedEntityType.AI_CONVERSATION);
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
      const session: AiSessionSummary = await ChatViewModel.createConversation(this.context(), this.studentProfileId);
      this.sessionId = session.sessionId;
      this.currentIntent = '';
      this.messages = ChatViewModel.welcomeMessages();
      this.sessions = [session].concat(this.sessions);
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_CREATED,
        DistributedEntityType.AI_CONVERSATION, 0, session.sessionId);
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_LIST_UPDATED,
        DistributedEntityType.AI_CONVERSATION);
      this.updateContinuation();
      this.scrollToBottom();
    } catch (error) {
      promptAction.showToast({ message: '新会话创建失败，请稍后重试' });
    }
  }

  private updateContinuation(): void {
    const continuation = new ContinuationSnapshot();
    continuation.routeName = AppRoutes.AI_ASSISTANT;
    continuation.entityKey = this.sessionId;
    DistributedPageService.updateContinuation(continuation);
  }

  private async openSession(sessionId: string): Promise<void> {
    if (this.isLoading) return;
    this.isRestoring = true;
    try {
      const history: AiChatHistory = await ChatViewModel.selectConversation(this.context(), sessionId);
      this.sessionId = sessionId;
      this.mergeHistory(history, true);
      this.showSessionList = false;
      this.updateContinuation();
    } finally {
      this.isRestoring = false;
    }
  }

  private async deleteSession(sessionId: string): Promise<void> {
    if (this.isLoading) return;
    try {
      await AiService.deleteConversation(sessionId);
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_DELETED,
        DistributedEntityType.AI_CONVERSATION, 0, sessionId);
      DistributedPageService.publish(DistributedEventType.AI_CONVERSATION_LIST_UPDATED,
        DistributedEntityType.AI_CONVERSATION);
      if (this.sessionId === sessionId) {
        await ChatViewModel.startNewConversation(this.context());
        this.sessionId = '';
        this.messages = ChatViewModel.welcomeMessages();
      }
      await this.loadSessions();
    } catch (error) {
      this.showCurrentToast('删除会话失败，请稍后重试');
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
      speechAiService.stopBackendRecording();
      speechAiService.cancelBackendRecording();
      speechAiService.stopListening();
      this.isRecording = false;
      this.clearAsrTimeout();
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

      // 长语音优先交给后端识别；无法启动时再回退到设备原生 ASR。
      const backendStarted: boolean = await speechAiService.startBackendRecording(this.context(),
        (text: string): void => {
          this.isRecording = false;
          this.asrHasResult = true;
          this.inputText = text;
          if (text.trim()) {
            promptAction.showToast({ message: '语音识别完成，可检查后发送' });
          } else {
            promptAction.showToast({ message: '未识别到有效内容' });
          }
        },
        (message: string): void => {
          this.isRecording = false;
          this.clearAsrTimeout();
          promptAction.showToast({ message: message });
        }
      );

      if (backendStarted) {
        this.isRecording = true;
        promptAction.showToast({ message: '正在录音，请说话…' });
        this.asrTimeoutId = setTimeout(() => {
          if (this.isRecording) {
            speechAiService.stopBackendRecording();
            speechAiService.cancelBackendRecording();
            this.isRecording = false;
            if (!this.asrHasResult) {
              promptAction.showToast({ message: '未检测到语音，请检查麦克风或网络' });
            }
          }
        }, 60000);
        return;
      }

      console.info('后端录音不可用，尝试原生 ASR');
      const nativeStarted: boolean = await speechAiService.startListening(
        (text: string, isFinal: boolean, isLast: boolean) => {
          this.asrHasResult = true;
          this.inputText = text;
          if (isFinal || isLast) {
            this.isRecording = false;
            this.clearAsrTimeout();
            if (text.trim()) {
              promptAction.showToast({ message: '语音识别完成，可检查后发送' });
            } else {
              promptAction.showToast({ message: '未识别到有效内容' });
            }
          }
        },
        (_code: number, message: string) => {
          this.isRecording = false;
          this.clearAsrTimeout();
          promptAction.showToast({ message: `语音识别失败：${message}` });
        }
      );

      if (nativeStarted) {
        this.isRecording = true;
        promptAction.showToast({ message: '正在听，请说话…' });
        this.asrTimeoutId = setTimeout(() => {
          if (this.isRecording) {
            speechAiService.stopListening();
            this.isRecording = false;
            if (!this.asrHasResult) {
              promptAction.showToast({ message: '未检测到语音，请检查麦克风或网络' });
            }
          }
        }, 60000);
        return;
      }

      promptAction.showToast({ message: '当前设备不支持语音识别，可继续使用文字输入' });
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

  private async copyAssistantContent(content: string): Promise<void> {
    try {
      const data: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      await pasteboard.getSystemPasteboard().setData(data);
      this.showCurrentToast('已复制');
    } catch (error) {
      console.error(`复制 AI 回复失败: ${JSON.stringify(error)}`);
      this.showCurrentToast('复制失败，请重试');
    }
  }

  private showCurrentToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (error) {
      console.error(`显示页面提示失败: ${JSON.stringify(error)}`);
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
    DistributedPageService.deactivate('AiAssistantPage');
    this.clearAsrTimeout();
    speechAiService.cancelBackendRecording();
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
          Text('历史').fontSize(12).fontColor('#5B65E8').onClick(() => {
            this.showSessionList = !this.showSessionList;
            if (this.showSessionList) void this.loadSessions();
          })
          Text('＋ 新会话').fontSize(12).fontColor('#2F6BFF').onClick(() => void this.newConversation())
          Text('清空').fontSize(12).fontColor('#F04438').onClick(() => this.showClearDialog())
        }.padding({ left: 16, right: 16, top: 12, bottom: 10 }).width('100%')

        if (this.showSessionList) {
          Column({ space: 8 }) {
            Row() {
              Text('历史会话').fontSize(15).fontWeight(FontWeight.Bold).layoutWeight(1)
              Text(`${this.sessions.length} 个`).fontSize(11).fontColor('#98A2B3')
            }.width('100%')
            if (this.sessions.length === 0) {
              Text('暂无历史会话').fontSize(12).fontColor('#98A2B3').width('100%')
            } else {
              List({ space: 6 }) {
                ForEach(this.sessions, (session: AiSessionSummary) => {
                  ListItem() {
                    Row({ space: 8 }) {
                      Column({ space: 3 }) {
                        Text(session.title || '学习咨询').fontSize(13).fontWeight(FontWeight.Medium).maxLines(1)
                        Text(`${session.messageCount} 条消息`).fontSize(10).fontColor('#98A2B3')
                      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                        .onClick(() => void this.openSession(session.sessionId))
                      Text('删除').fontSize(11).fontColor('#F04438')
                        .onClick(() => void this.deleteSession(session.sessionId))
                    }.width('100%').padding(10).backgroundColor(
                      session.sessionId === this.sessionId ? '#EEF4FF' : '#F8FAFC'
                    ).borderRadius(10)
                  }
                }, (session: AiSessionSummary) => session.sessionId)
              }.height(Math.min(180, this.sessions.length * 56)).width('100%')
            }
          }.margin({ left: 16, right: 16, bottom: 8 }).padding(12)
            .backgroundColor(Color.White).borderRadius(14)
        }

        List({ space: 14, scroller: this.messageScroller }) {
          ForEach(this.messages, (message: ChatMessage, index: number) => {
            ListItem() {
              Column() {
                ChatMessageBubble({
                  message: message,
                  speakingMessageId: this.speakingMessageId,
                  onRead: (content: string, messageId: string): void => { void this.readMessage(content, messageId); },
                  onCopy: (content: string): void => { void this.copyAssistantContent(content); },
                  onRetry: (failed: ChatMessage): void => { void this.sendQuestion(failed.retryQuestion, failed); }
                })

                if (index === 0) {
                  Column({ space: 8 }) {
                    ForEach(ChatViewModel.QUICK_QUESTIONS, (item: QuickQuestion) => {
                      Row() {
                        SuggestionChip({
                          item: item,
                          disabled: this.isLoading || this.isRestoring,
                          onSelect: (question: string): void => {
                            void this.sendQuestion(question);
                          }
                        })
                      }
                      .width('100%')
                    }, (item: QuickQuestion) => item.label)

                    Row() {
                      Row({ space: 7 }) {
                        Text('✎')
                          .fontSize(15)
                          .fontColor('#4777F5')

                        Text('AI 组卷')
                          .fontSize(13)
                          .fontColor('#344054')
                          .fontWeight(FontWeight.Medium)
                      }
                      .height(38)
                      .padding({ left: 12, right: 12 })
                      .alignItems(VerticalAlign.Center)
                      .backgroundColor(Color.White)
                      .borderRadius(18)
                      .border({ width: 1, color: '#E3E9F6' })
                      .opacity(this.isLoading || this.isRestoring ? 0.55 : 1)
                      .onClick(() => {
                        if (!this.isLoading && !this.isRestoring) {
                          this.appPathStack.pushPathByName(
                            AppRoutes.GENERATE_PAPER,
                            null
                          );
                        }
                      })
                    }
                    .width('100%')
                    .justifyContent(FlexAlign.Start)
                  }
                  .width('100%')
                  .margin({ top: 10 })
                }
              }
              .width('100%')
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
