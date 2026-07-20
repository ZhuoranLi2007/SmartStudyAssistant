import { AiSource } from '../../model/AiModels';

@Component
export struct ChatSourceList {
  @Prop sources: AiSource[] = [];
  @State expanded: boolean = false;

  private scoreText(score: number): string {
    if (score <= 0) return '';
    return ` · 匹配度 ${Math.round(score * 100)}%`;
  }

  build() {
    if (this.sources.length > 0) {
      Column({ space: 7 }) {
        Row() {
          Text(`参考依据（${this.sources.length}）`).fontSize(11).fontColor('#667085').layoutWeight(1)
          Text(this.expanded ? '收起⌃' : '展开⌄').fontSize(11).fontColor('#2F6BFF')
        }.width('100%').onClick(() => this.expanded = !this.expanded)
        if (this.expanded) {
          ForEach(this.sources, (source: AiSource) => {
            Column({ space: 3 }) {
              Text(source.title || '参考资料').fontSize(11).fontWeight(FontWeight.Medium).width('100%')
              Text(`${source.sourceType || '知识库'}${this.scoreText(source.score)}`).fontSize(9).fontColor('#98A2B3').width('100%')
              if (source.excerpt) Text(source.excerpt).fontSize(10).fontColor('#667085').lineHeight(16).maxLines(3).width('100%')
            }.padding(8).width('100%').backgroundColor('#F8FAFC').borderRadius(9)
          }, (source: AiSource, index: number) => `${source.sourceType}_${source.sourceId}_${index}`)
        }
      }.width('100%')
    }
  }
}
