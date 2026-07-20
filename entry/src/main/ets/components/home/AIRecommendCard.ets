import { AppRoutes, IdRouteParam } from '../../common/AppRoutes';
import { HomeCourseItem } from '../../model/HomeModels';

@Component
export struct AIRecommendCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop course: HomeCourseItem = { id: 0, name: '', grade: '', subject: '', difficulty: '', courseType: '', priceText: '', imageKey: '', recommendReason: '' };

  private open(): void {
    const param: IdRouteParam = new IdRouteParam(); param.id = this.course.id;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('为你推荐').fontSize(18).fontWeight(FontWeight.Bold)
          Text('根据学生档案和学习情况智能匹配').fontSize(11).fontColor('#667085')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('AI推荐').fontSize(11).fontColor('#7A5AF8').backgroundColor('#F4F3FF').padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(8)
      }.width('100%')
      Row({ space: 12 }) {
        Image($r('app.media.realImageGen_education_4')).width(106).height(88).borderRadius(13).objectFit(ImageFit.Cover)
        Column({ space: 5 }) {
          Text(this.course.name).fontSize(15).fontWeight(FontWeight.Bold).maxLines(2)
          Text(`${this.course.grade} · ${this.course.subject} · ${this.course.courseType}`).fontSize(11).fontColor('#667085')
          Text(this.course.recommendReason).fontSize(11).fontColor('#475467').maxLines(2)
          Row() {
            Text(this.course.priceText).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#F04438').layoutWeight(1)
            Text('查看详情').fontSize(12).fontColor('#2F6BFF')
          }.width('100%')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
    }.padding(15).width('100%').backgroundColor(Color.White).borderRadius(18).onClick(() => this.open())
  }
}
