import { MarkdownBlock, MarkdownBlockType, MarkdownInlineSegment } from '../../model/AiModels';
import { MarkdownParser } from './MarkdownParser';

@Component
export struct MarkdownRenderer {
  @Prop content: string = '';

  private headingSize(level: number): number {
    if (level === 1) return 19;
    if (level === 2) return 17;
    return 15;
  }

  private headingLineHeight(level: number): number {
    if (level === 1) return 28;
    if (level === 2) return 25;
    return 23;
  }

  @Builder
  private richLine(content: string, size: number, lineHeight: number, weight: FontWeight, color: string) {
    Text() {
      ForEach(MarkdownParser.inlineSegments(content), (segment: MarkdownInlineSegment) => {
        Span(segment.text)
          .fontWeight(segment.bold ? FontWeight.Bold : weight)
          .fontColor(color)
      })
    }
    .fontSize(size)
    .fontColor(color)
    .fontWeight(weight)
    .lineHeight(lineHeight)
    .width('100%')
  }

  build() {
    Column({ space: 7 }) {
      ForEach(MarkdownParser.parse(this.content), (block: MarkdownBlock, blockIndex: number) => {
        if (block.type === MarkdownBlockType.HEADING) {
          this.richLine(
            block.content,
            this.headingSize(block.headingLevel),
            this.headingLineHeight(block.headingLevel),
            FontWeight.Bold,
            '#172033'
          )
          if (block.headingLevel === 1) {
            Divider().color('#EEF1F6').strokeWidth(1)
          }
        } else if (block.type === MarkdownBlockType.PARAGRAPH) {
          this.richLine(block.content, 15, 23, FontWeight.Normal, '#243047')
        } else if (block.type === MarkdownBlockType.BULLET_LIST || block.type === MarkdownBlockType.NUMBERED_LIST) {
          Column({ space: 7 }) {
            ForEach(block.items, (item: string, itemIndex: number) => {
              Row({ space: 7 }) {
                Text(block.type === MarkdownBlockType.NUMBERED_LIST ? `${itemIndex + 1}.` : '•')
                  .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#4777F5')
                  .width(20).textAlign(TextAlign.Center).alignSelf(ItemAlign.Start)
                Column() {
                  this.richLine(item, 14, 21, FontWeight.Normal, '#243047')
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
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
