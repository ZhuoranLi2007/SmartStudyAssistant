import { AppRoutes, StudentRouteParam } from '../../common/AppRoutes';
import { AppStorageKeys } from '../../common/AppStorageKeys';
import { HomeBanner } from '../../model/HomeModels';

@Component
export struct HomeBannerSwiper {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @Prop banners: HomeBanner[] = [];
  private controller: SwiperController = new SwiperController();

  private bannerImage(key: string): Resource {
    if (key === 'PAPER') return $r('app.media.realImageGen_education_9');
    if (key === 'PLAN') return $r('app.media.realImageGen_education_4');
    return $r('app.media.realImageGen_education_10');
  }

  private open(banner: HomeBanner): void {
    if (banner.routeName === AppRoutes.AI_ASSISTANT) {
      const param: StudentRouteParam = new StudentRouteParam();
      param.studentProfileId = this.studentProfileId;
      this.appPathStack.pushPathByName(banner.routeName, param);
    } else {
      this.appPathStack.pushPathByName(banner.routeName, null);
    }
  }

  build() {
    Swiper(this.controller) {
      ForEach(this.banners, (banner: HomeBanner) => {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image(this.bannerImage(banner.imageKey)).width('100%').height('100%').objectFit(ImageFit.Cover)
          Column({ space: 5 }) {
            Text(banner.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White).width('100%')
            Text(banner.subtitle).fontSize(12).fontColor('#F2F4F7').maxLines(2).width('78%')
            Text(banner.actionText).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#2F6BFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 }).backgroundColor(Color.White).borderRadius(12)
          }.width('100%').padding(16).linearGradient({ angle: 0, colors: [['#B3000000', 0], ['#12000000', 1]] })
        }.width('100%').height(164).borderRadius(18).clip(true).onClick(() => this.open(banner))
      }, (banner: HomeBanner) => `${banner.id}`)
    }
    .width('100%').height(164).autoPlay(true).interval(4000).loop(true).indicator(true)
  }
}
