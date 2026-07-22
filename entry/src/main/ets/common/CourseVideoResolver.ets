import { Course, CourseLevel } from '../model/DomainModels';

export class CourseVideoResolver {
  static previewKey(course: Course): string {
    if (course.level === CourseLevel.IMPROVEMENT) return 'Maths2_cover';
    if (course.level === CourseLevel.EXTENSION) return 'Math3_cover';
    return 'Math1_cover';
  }

  static resolvePreviewByKey(key: string): Resource {
    if (key === 'Maths2_cover') return $r('app.media.Maths2_cover');
    if (key === 'Math3_cover') return $r('app.media.Math3_cover');
    return $r('app.media.Math1_cover');
  }

  static resolve(course: Course): Resource {
    if (course.level === CourseLevel.IMPROVEMENT) {
      return $r('app.media.Maths2');
    }
    if (course.level === CourseLevel.EXTENSION) {
      return $r('app.media.Math3');
    }
    return $r('app.media.Math1');
  }

  static resolvePreview(course: Course): Resource {
    return CourseVideoResolver.resolvePreviewByKey(CourseVideoResolver.previewKey(course));
  }
}
