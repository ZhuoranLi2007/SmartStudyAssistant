import { CourseDetailData } from '../../model/CourseDetailModels';

@Component
export struct CourseBasicInfo {
  @Prop detail: CourseDetailData;

  build() {
    Column({ space: 11 }) {
      Text(this.detail.course.name).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        Text(this.detail.course.grade).fontSize(11).fontColor('#2F6BFF').padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor('#EEF4FF').borderRadius(8).margin({ right: 7, bottom: 6 })
        Text(this.detail.course.subject).fontSize(11).fontColor('#2F6BFF').padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor('#EEF4FF').borderRadius(8).margin({ right: 7, bottom: 6 })
        Text(this.detail.course.level).fontSize(11).fontColor('#7A5AF8').padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor('#F4F3FF').borderRadius(8).margin({ right: 7, bottom: 6 })
      }.width('100%')
      Text(this.detail.course.description).fontSize(14).fontColor('#475467').lineHeight(22).width('100%')
      Row({ space: 8 }) {
        Text(`¥${this.detail.course.price}`).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#F04438')
        Text(`¥${this.detail.originalPrice}`).fontSize(13).fontColor('#98A2B3')
          .decoration({ type: TextDecorationType.LineThrough, color: '#98A2B3' })
        Blank()
        Text(`${this.detail.enrollmentCount}人已报名`).fontSize(12).fontColor('#667085')
      }.width('100%')
      Row() {
        Text(`共${this.detail.course.totalLessons}课时`).fontSize(12).fontColor('#475467').layoutWeight(1)
        Text('支持回看').fontSize(12).fontColor('#2F6BFF')
      }.width('100%')
    }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
  }
}
