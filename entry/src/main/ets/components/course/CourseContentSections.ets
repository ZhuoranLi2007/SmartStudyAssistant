import { CourseDetailData, CourseHighlight, CourseServiceItem } from '../../model/CourseDetailModels';

@Component
export struct CourseContentSections {
  @Prop detail: CourseDetailData;

  @Builder
  private highlightItem(item: CourseHighlight) {
    Row({ space: 9 }) {
      Text(item.iconText).width(34).height(34).textAlign(TextAlign.Center).fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor('#2F6BFF').backgroundColor('#EEF4FF').borderRadius(17)
      Column({ space: 3 }) {
        Text(item.title).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#344054').width('100%')
        Text(item.description).fontSize(10).fontColor('#98A2B3').maxLines(2).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.layoutWeight(1).padding(8).alignItems(VerticalAlign.Center)
  }

  @Builder
  private serviceItem(item: CourseServiceItem) {
    Row({ space: 11 }) {
      Text(item.iconText).width(36).height(36).textAlign(TextAlign.Center).fontSize(11).fontWeight(FontWeight.Bold)
        .fontColor('#2F6BFF').backgroundColor('#EEF4FF').borderRadius(11)
      Column({ space: 3 }) {
        Text(item.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#344054').width('100%')
        Text(item.description).fontSize(11).fontColor('#667085').width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%')
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 11 }) {
        Text('课程介绍').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
        Text(this.detail.course.description).fontSize(14).fontColor('#475467').lineHeight(22).width('100%')
        Text('教学目标').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#344054').width('100%')
        Text(this.detail.teachingGoal).fontSize(13).fontColor('#667085').lineHeight(20).width('100%')
        Text('学习方式').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#344054').width('100%')
        Text(this.detail.learningMethod).fontSize(13).fontColor('#667085').lineHeight(20).width('100%')
        Text('学习收获').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#344054').width('100%')
        Text(this.detail.learningOutcome).fontSize(13).fontColor('#667085').lineHeight(20).width('100%')
      }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)

      Column({ space: 8 }) {
        Text('课程亮点').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
        Row() {
          this.highlightItem(this.detail.highlights[0])
          this.highlightItem(this.detail.highlights[1])
        }.width('100%')
        Row() {
          this.highlightItem(this.detail.highlights[2])
          this.highlightItem(this.detail.highlights[3])
        }.width('100%')
      }.padding(12).width('100%').backgroundColor(Color.White).borderRadius(18)

      Column({ space: 9 }) {
        Text('适合人群').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
        ForEach(this.detail.suitableUsers, (item: string) => {
          Text(`• ${item}`).fontSize(13).fontColor('#475467').lineHeight(20).width('100%')
        }, (item: string) => item)
      }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)

      Column({ space: 11 }) {
        Text('核心知识点').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.detail.knowledgeTags, (tag: string) => {
            Text(tag).fontSize(12).fontColor('#2F6BFF').padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#EEF4FF').borderRadius(9).margin({ right: 8, bottom: 8 })
          }, (tag: string) => tag)
        }.width('100%')
      }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)

      Column({ space: 13 }) {
        Text('课程服务').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
        ForEach(this.detail.services, (item: CourseServiceItem) => {
          this.serviceItem(item)
        }, (item: CourseServiceItem) => item.title)
      }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
    }.width('100%')
  }
}
