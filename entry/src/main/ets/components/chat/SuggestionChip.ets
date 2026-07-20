import { QuickQuestion } from '../../model/AiModels';

@Component
export struct SuggestionChip {
  @Prop item: QuickQuestion;
  @Prop disabled: boolean = false;
  onSelect: (question: string) => void = (_question: string): void => {};

  build() {
    Row({ space: 7 }) {
      Text(this.item.icon).fontSize(15).fontColor('#4777F5')
      Text(this.item.label).fontSize(12).fontColor('#344054').fontWeight(FontWeight.Medium)
    }
    .height(38)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Color.White)
    .borderRadius(18)
    .border({ width: 1, color: '#E3E9F6' })
    .opacity(this.disabled ? 0.55 : 1)
    .onClick(() => { if (!this.disabled) this.onSelect(this.item.question); })
  }
}
