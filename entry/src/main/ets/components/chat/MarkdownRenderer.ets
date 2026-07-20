import { MarkdownBlock, MarkdownBlockType, MarkdownInlineSegment } from '../../model/AiModels';
import { MarkdownParser } from './MarkdownParser';

@Component
export struct MarkdownRenderer {
  @Prop content: string = '';

  @Builder
  private richLine(content: string, size: number, weight: FontWeight) {
    Text() {
      ForEach(MarkdownParser.inlineSegments(content), (segment: MarkdownInlineSegment) => {
        Span(segment.text).fontWeight(segment.bold ? FontWeight.Bold : weight)
      })
    }.fontSize(size).fontColor('#172033').lineHeight(size + 8).width('100%')
  }

  build() {
    Column({ space: 5 }) {
      ForEach(MarkdownParser.parse(this.content), (block: MarkdownBlock, blockIndex: number) => {
        if (block.type === MarkdownBlockType.HEADING) {
          this.richLine(block.content, 16, FontWeight.Bold)
        } else if (block.type === MarkdownBlockType.PARAGRAPH) {
          this.richLine(block.content, 15, FontWeight.Normal)
        } else if (block.type === MarkdownBlockType.BULLET_LIST || block.type === MarkdownBlockType.NUMBERED_LIST) {
          Column({ space: 5 }) {
            ForEach(block.items, (item: string, itemIndex: number) => {
              Row({ space: 7 }) {
                Text(block.type === MarkdownBlockType.NUMBERED_LIST ? `${itemIndex + 1}.` : '•')
                  .fontSize(14).fontColor('#4777F5').alignSelf(ItemAlign.Start)
                Column() { this.richLine(item, 14, FontWeight.Normal) }.layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
            }, (item: string, itemIndex: number) => `${itemIndex}_${item}`)
          }.width('100%')
        } else if (block.type === MarkdownBlockType.DIVIDER) {
          Divider().color('#E8ECF4').strokeWidth(1).margin({ top: 3, bottom: 3 })
        } else {
          Blank().height(4)
        }
      }, (block: MarkdownBlock, index: number) => `${index}_${block.type}_${block.content}`)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
