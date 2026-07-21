import { CourseReview } from '../../model/CourseDetailModels';

@Component
export struct CourseReviews {
  @Prop rating: number = 0;
  @Prop reviewCount: number = 0;
  @Prop reviews: CourseReview[];

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('学员评价').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#172033')
        Text(`（${this.reviewCount}）`).fontSize(13).fontColor('#667085').layoutWeight(1)
        Text('真实体验反馈').fontSize(11).fontColor('#98A2B3')
      }.width('100%')
      Row({ space: 12 }) {
        Text(`${this.rating}`).fontSize(30).fontWeight(FontWeight.Bold).fontColor('#172033')
        Text('★★★★★').fontSize(19).fontColor('#FDB022')
      }.width('100%')
      ForEach(this.reviews, (review: CourseReview) => {
        Column({ space: 8 }) {
          Row({ space: 9 }) {
            Image($r('app.media.avatar')).width(38).height(38).borderRadius(19).objectFit(ImageFit.Cover)
            Column({ space: 3 }) {
              Text(review.nickname).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#344054')
              Text(`${review.score}  ★★★★★`).fontSize(11).fontColor('#FDB022')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text(review.date).fontSize(10).fontColor('#98A2B3')
          }.width('100%')
          Text(review.content).fontSize(13).fontColor('#475467').lineHeight(20).width('100%')
        }.padding({ top: 4, bottom: 10 }).width('100%').border({ width: { bottom: 1 }, color: '#EAECF0' })
      }, (review: CourseReview) => `${review.id}`)
    }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
  }
}
