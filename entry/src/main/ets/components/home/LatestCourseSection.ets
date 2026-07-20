import { AppRoutes, IdRouteParam } from '../../common/AppRoutes';
import { HomeCourseItem } from '../../model/HomeModels';
import { CourseSectionHeader } from './CourseSectionHeader';

@Component
export struct LatestCourseSection {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop courses: HomeCourseItem[] = [];

  private image(key: string): Resource {
    if (key === 'COURSE_5') return $r('app.media.realImageGen_education_5');
    if (key === 'COURSE_10') return $r('app.media.realImageGen_education_10');
    if (key === 'COURSE_4') return $r('app.media.realImageGen_education_4');
    return $r('app.media.realImageGen_education_1');
  }

  private open(id: number): void {
    const param: IdRouteParam = new IdRouteParam(); param.id = id;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  @Builder
  private card(course: HomeCourseItem) {
    Column({ space: 6 }) {
      Image(this.image(course.imageKey)).width('100%').aspectRatio(1.65).borderRadius(12).objectFit(ImageFit.Cover)
      Text(course.name).fontSize(13).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
      Text(`${course.courseType} · ${course.difficulty}`).fontSize(10).fontColor('#667085').width('100%')
      Text(course.priceText).fontSize(13).fontWeight(FontWeight.Bold).fontColor(course.priceText === '免费' ? '#12B76A' : '#F04438').width('100%')
    }.layoutWeight(1).padding(10).backgroundColor(Color.White).borderRadius(15).onClick(() => this.open(course.id))
  }

  build() {
    Column({ space: 11 }) {
      CourseSectionHeader({ title: '最新上架', routeName: AppRoutes.COURSES })
      Row({ space: 10 }) {
        if (this.courses.length > 0) this.card(this.courses[0])
        if (this.courses.length > 1) this.card(this.courses[1])
      }.width('100%')
      Row({ space: 10 }) {
        if (this.courses.length > 2) this.card(this.courses[2])
        if (this.courses.length > 3) this.card(this.courses[3])
      }.width('100%')
    }.width('100%')
  }
}
