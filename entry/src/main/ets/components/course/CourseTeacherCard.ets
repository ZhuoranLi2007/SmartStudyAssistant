import { CourseTeacher } from '../../model/CourseDetailModels';

@Component
export struct CourseTeacherCard {
  @Prop teacher: CourseTeacher;

  build() {
    Column({ space: 13 }) {
      Text('主讲老师').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
      Row({ space: 14 }) {
        Image($r('app.media.teacher')).width(68).height(68).borderRadius(34).objectFit(ImageFit.Cover)
        Column({ space: 7 }) {
          Row({ space: 8 }) {
            Text(this.teacher.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
            Text(this.teacher.tag).fontSize(10).fontColor('#9A6700').padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor('#FFF4D6').borderRadius(7)
          }.width('100%')
          ForEach(this.teacher.descriptionLines, (line: string) => {
            Text(`• ${line}`).fontSize(12).fontColor('#475467').lineHeight(18).width('100%')
          }, (line: string) => line)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Top)
    }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
  }
}
