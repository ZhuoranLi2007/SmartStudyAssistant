import { CourseOutlineItem } from '../../model/CourseDetailModels';

@Component
export struct CourseOutline {
  @Prop items: CourseOutlineItem[];
  @Prop expanded: boolean = false;
  onToggle: () => void = (): void => {};

  private visibleItems(): CourseOutlineItem[] {
    return this.expanded ? this.items : this.items.slice(0, 5);
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('课程大纲').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').layoutWeight(1)
        Text(`共${this.items.length}个单元`).fontSize(12).fontColor('#667085')
      }.width('100%')
      ForEach(this.visibleItems(), (item: CourseOutlineItem) => {
        Row({ space: 10 }) {
          Text(`${item.sequence}`).width(24).height(24).textAlign(TextAlign.Center).fontSize(11).fontColor(Color.White)
            .backgroundColor(item.playable ? '#2F6BFF' : '#84ADFF').borderRadius(12)
          Column({ space: 3 }) {
            Text(item.title).fontSize(14).fontColor('#344054').width('100%')
            Text(item.duration).fontSize(11).fontColor('#98A2B3').width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(item.playable ? '▶' : '锁').fontSize(item.playable ? 17 : 11)
            .fontColor(item.playable ? '#2F6BFF' : '#98A2B3')
        }.width('100%').alignItems(VerticalAlign.Center)
      }, (item: CourseOutlineItem) => `${item.sequence}`)
      Text(this.expanded ? '收起课程 ︿' : '查看全部课程 ﹀').fontSize(13).fontColor('#2F6BFF')
        .width('100%').textAlign(TextAlign.Center).padding({ top: 5, bottom: 5 }).onClick(() => this.onToggle())
    }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
  }
}
