import { Course, CourseLevel } from '../model/DomainModels';

export class CourseVideoResolver {
  static previewKey(course: Course): string {
    if (course.subject === '语文') {
      return course.level === CourseLevel.FOUNDATION ? 'Chinese1_cover' : 'Chinese2_cover';
    }
    if (course.subject === '英语') {
      return course.level === CourseLevel.FOUNDATION ? 'English1_cover' : 'English2_cover';
    }
    if (course.level === CourseLevel.IMPROVEMENT) return 'Maths2_cover';
    if (course.level === CourseLevel.EXTENSION) return 'Math3_cover';
    return 'Math1_cover';
  }

  static resolvePreviewByKey(key: string): Resource {
    if (key === 'Chinese1_cover') return $r('app.media.Chinese1_cover');
    if (key === 'Chinese2_cover') return $r('app.media.Chinese2_cover');
    if (key === 'English1_cover') return $r('app.media.English1_cover');
    if (key === 'English2_cover') return $r('app.media.English2_cover');
    if (key === 'Maths2_cover') return $r('app.media.Maths2_cover');
    if (key === 'Math3_cover') return $r('app.media.Math3_cover');
    return $r('app.media.Math1_cover');
  }

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
    return CourseVideoResolver.resolvePreviewByKey(CourseVideoResolver.previewKey(course));
  }
}
