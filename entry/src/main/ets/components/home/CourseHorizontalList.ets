import { AppRoutes, IdRouteParam } from '../../common/AppRoutes';
import { HomeCourseItem } from '../../model/HomeModels';
import { CourseSectionHeader } from './CourseSectionHeader';

@Component
export struct CourseHorizontalList {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @Prop courses: HomeCourseItem[] = [];

  private courseImage(key: string): Resource {
    if (key === 'COURSE_9') return $r('app.media.realImageGen_education_9');
    if (key === 'COURSE_3') return $r('app.media.realImageGen_education_3');
    if (key === 'COURSE_10') return $r('app.media.realImageGen_education_10');
    return $r('app.media.realImageGen_education_1');
  }

  private open(id: number): void {
    const param: IdRouteParam = new IdRouteParam(); param.id = id;
    this.appPathStack.pushPathByName(AppRoutes.COURSE_DETAIL, param);
  }

  build() {
    Column({ space: 11 }) {
      CourseSectionHeader({ title: '热门课程', routeName: AppRoutes.COURSES })
      List({ space: 11 }) {
        ForEach(this.courses, (course: HomeCourseItem) => {
          ListItem() {
            Column({ space: 6 }) {
              Image(this.courseImage(course.imageKey)).width(156).height(88).borderRadius(12).objectFit(ImageFit.Cover)
              Text(course.name).fontSize(14).fontWeight(FontWeight.Bold).maxLines(2).width('100%')
              Text(`${course.grade} · ${course.subject} · ${course.difficulty}`).fontSize(10).fontColor('#667085').width('100%')
              Row() {
                Text(course.courseType).fontSize(10).fontColor('#2F6BFF').layoutWeight(1)
                Text(course.priceText).fontSize(13).fontWeight(FontWeight.Bold).fontColor(course.priceText === '免费' ? '#12B76A' : '#F04438')
              }.width('100%')
            }.width(156).onClick(() => this.open(course.id))
          }
        }, (course: HomeCourseItem) => `${course.id}`)
      }.listDirection(Axis.Horizontal).height(190).width('100%')
    }.width('100%')
  }
}
