import { AppRoutes } from '../../common/AppRoutes';
import { AppStorageKeys } from '../../common/AppStorageKeys';

@Component
export struct HomeHeader {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USERNAME) username: string = '';

  build() {
    Column({ space: 11 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(`你好，${this.username || '同学'}`)
            .fontSize(23).fontWeight(FontWeight.Bold).fontColor('#101828')
          Text('加入课程、练习试卷，把任务放进学习计划')
            .fontSize(13).fontColor('#667085')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.avatar')).width(46).height(46).borderRadius(23)
          .onClick(() => this.appPathStack.pushPathByName(AppRoutes.PROFILE, null))
      }.width('100%')
    }.width('100%')
  }
}
