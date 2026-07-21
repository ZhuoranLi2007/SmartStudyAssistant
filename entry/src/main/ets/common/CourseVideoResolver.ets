import { Course, CourseLevel } from '../model/DomainModels';

export class CourseVideoResolver {
  static resolve(course: Course): Resource {
    if (course.subject === '语文') {
      return course.level === CourseLevel.FOUNDATION
        ? $r('app.media.Chinese1')
        : $r('app.media.Chinese2');
    }

    if (course.subject === '英语') {
      return course.level === CourseLevel.FOUNDATION
        ? $r('app.media.English1')
        : $r('app.media.English2');
    }

    if (course.level === CourseLevel.IMPROVEMENT) {
      return $r('app.media.Maths2');
    }
    if (course.level === CourseLevel.EXTENSION) {
      return $r('app.media.Math3');
    }
    return $r('app.media.Math1');
  }

  static resolvePreview(course: Course): Resource {
    if (course.subject === '语文') {
      return course.level === CourseLevel.FOUNDATION
        ? $r('app.media.Chinese1_cover')
        : $r('app.media.Chinese2_cover');
    }

    if (course.subject === '英语') {
      return course.level === CourseLevel.FOUNDATION
        ? $r('app.media.English1_cover')
        : $r('app.media.English2_cover');
    }

    if (course.level === CourseLevel.IMPROVEMENT) {
      return $r('app.media.Maths2_cover');
    }
    if (course.level === CourseLevel.EXTENSION) {
      return $r('app.media.Math3_cover');
    }
    return $r('app.media.Math1_cover');
  }
}
