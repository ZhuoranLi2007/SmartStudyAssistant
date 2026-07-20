import { promptAction } from '@kit.ArkUI';
import { AppRoutes, IdRouteParam } from '../../common/AppRoutes';
import { AiCard } from '../../model/AiModels';

@Component
export struct CourseRecommendationCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop card: AiCard;

  private openCourse(): void {
    if (this.card.id <= 0) {
      promptAction.showToast({ message: '课程信息暂不完整' });
      return;
    }
    const param: IdRouteParam = new IdRouteParam();
    param.id = this.card.id;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  private labelText(): string {
    return this.card.level || this.card.difficulty || '个性化推荐';
  }

  build() {
    Column({ space: 9 }) {
      Row() {
        Text('▣ 推荐课程').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
        Blank()
        Text(this.labelText()).fontSize(10).fontColor('#2F6BFF').padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor('#EEF4FF').borderRadius(8)
      }.width('100%')
      Row({ space: 10 }) {
        Image($r('app.media.realImageGen_education_10')).width(72).height(72).objectFit(ImageFit.Cover).borderRadius(12)
        Column({ space: 5 }) {
          Text(this.card.title).fontSize(15).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
          Text(`${this.card.grade || ''} ${this.card.subject || ''}`.trim()).fontSize(11).fontColor('#667085').width('100%')
          if (this.card.lessonCount !== undefined) {
            Text(`共 ${this.card.lessonCount} 课时`).fontSize(11).fontColor('#667085').width('100%')
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      if (this.card.recommendationReason) {
        Text(this.card.recommendationReason).fontSize(12).fontColor('#475467').lineHeight(18).maxLines(3).width('100%')
      }
      Row() {
        if (this.card.price !== undefined) {
          Text(`¥${this.card.price}`).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#F04438')
        }
        Blank()
        Button('查看课程').fontSize(12).height(34).backgroundColor('#356DF3').enabled(this.card.id > 0)
          .onClick(() => this.openCourse())
      }.width('100%')
    }
    .padding(13).width('100%').backgroundColor('#F9FBFF').borderRadius(14)
    .border({ width: 1, color: '#DCE6FB' })
  }
}
