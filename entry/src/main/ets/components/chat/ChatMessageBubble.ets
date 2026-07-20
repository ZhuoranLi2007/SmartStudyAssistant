import { AiCard, AiCardType, ChatMessage, ChatRole } from '../../model/AiModels';
import { ChatAvatar } from './ChatAvatar';
import { ChatSourceList } from './ChatSourceList';
import { CourseRecommendationCard } from './CourseRecommendationCard';
import { MarkdownRenderer } from './MarkdownRenderer';
import { OrderCard } from './OrderCard';
import { PaperRecommendationCard } from './PaperRecommendationCard';
import { StudyPlanCard } from './StudyPlanCard';
import { TypingIndicator } from './TypingIndicator';

@Component
export struct ChatMessageBubble {
  @Prop message: ChatMessage;
  onRead: (content: string) => void = (_content: string): void => {};
  onRetry: (message: ChatMessage) => void = (_message: ChatMessage): void => {};

  @Builder
  private structuredCards() {
    if (this.message.cards.length > 0) {
      Column({ space: 9 }) {
        ForEach(this.message.cards, (card: AiCard) => {
          if (card.type === AiCardType.COURSE) {
            CourseRecommendationCard({ card: card })
          } else if (card.type === AiCardType.PAPER) {
            PaperRecommendationCard({ card: card })
          } else if (card.type === AiCardType.STUDY_PLAN) {
            StudyPlanCard({ card: card })
          } else if (card.type === AiCardType.ORDER) {
            OrderCard({ card: card })
          }
        }, (card: AiCard, index: number) => `${card.type}_${card.id}_${index}`)
      }.width('100%')
    }
  }

  @Builder
  private assistantMessage() {
    Row({ space: 9 }) {
      ChatAvatar({ role: ChatRole.ASSISTANT, avatarSize: 40 })
      Column({ space: 6 }) {
        Text('智学助手').fontSize(11).fontColor('#667085').width('100%')
        Column({ space: 10 }) {
          if (this.message.isStreaming && !this.message.content) {
            TypingIndicator()
          } else if (this.message.content) {
            MarkdownRenderer({ content: this.message.content })
          }
          this.structuredCards()
          ChatSourceList({ sources: this.message.sources })
          if (this.message.fallbackUsed) {
            Text('本地演示回答').fontSize(9).fontColor('#B54708').padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor('#FFF4E5').borderRadius(7).alignSelf(ItemAlign.Start)
          }
          if (this.message.errorMessage) {
            Row() {
              Text(this.message.errorMessage).fontSize(11).fontColor('#B42318').layoutWeight(1)
              Text('重试').fontSize(12).fontColor('#2F6BFF').fontWeight(FontWeight.Medium)
                .onClick(() => this.onRetry(this.message))
            }.padding(8).width('100%').backgroundColor('#FEF3F2').borderRadius(8)
          }
          if (!this.message.isStreaming && this.message.content) {
            Row() {
              Text('朗读').fontSize(10).fontColor('#667085').onClick(() => this.onRead(this.message.content))
            }.width('100%')
          }
        }
        .padding(12).width('100%').backgroundColor(Color.White).borderRadius(16)
        .border({ width: 1, color: '#EDF0F6' })
      }.constraintSize({ maxWidth: '82%' }).alignItems(HorizontalAlign.Start)
      Blank().layoutWeight(1)
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  @Builder
  private userMessage() {
    Row({ space: 9 }) {
      Blank().layoutWeight(1)
      Column({ space: 5 }) {
        Text('我').fontSize(11).fontColor('#667085').width('100%').textAlign(TextAlign.End)
        Text(this.message.content).fontSize(15).fontColor(Color.White).lineHeight(22)
          .padding(12).backgroundColor('#356DF3').borderRadius(16).constraintSize({ maxWidth: '78%' })
      }.alignItems(HorizontalAlign.End)
      ChatAvatar({ role: ChatRole.USER, avatarSize: 38 })
    }.width('100%').alignItems(VerticalAlign.Top)
  }

  build() {
    if (this.message.role === ChatRole.USER) {
      this.userMessage()
    } else {
      this.assistantMessage()
    }
  }
}
