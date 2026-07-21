import { promptAction } from '@kit.ArkUI';
import { CourseVideoResolver } from '../../common/CourseVideoResolver';
import { Course } from '../../model/DomainModels';

@Component
export struct CourseVideoSection {
  @Prop course: Course;
  @State videoLoadFailed: boolean = false;
  private controller: VideoController = new VideoController();

  aboutToDisappear(): void {
    try {
      this.controller.stop();
    } catch (error) {
      console.warn(`停止课程视频失败: ${JSON.stringify(error)}`);
    }
  }

  build() {
    if (this.videoLoadFailed) {
      Image(CourseVideoResolver.resolvePreview(this.course))
        .width('100%').aspectRatio(16 / 9).borderRadius(18).objectFit(ImageFit.Cover)
    } else {
      Video({
        src: CourseVideoResolver.resolve(this.course),
        previewUri: CourseVideoResolver.resolvePreview(this.course),
        controller: this.controller
      })
        .width('100%').aspectRatio(16 / 9).borderRadius(18).backgroundColor('#000000')
        .objectFit(ImageFit.Contain).autoPlay(false).controls(true).loop(false)
        .onError(() => {
          this.videoLoadFailed = true;
          promptAction.showToast({ message: '课程视频加载失败，已显示课程封面' });
        })
    }
  }
}
