import { AppRoutes } from '../../common/AppRoutes';
import { AppStorageKeys } from '../../common/AppStorageKeys';

@Component
export struct HomeHeader {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USERNAME) username: string = '';
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';

  build() {
    Column({ space: 11 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(`你好，${this.username || (this.role === 'student' ? '同学' : '家长')}`).fontSize(23).fontWeight(FontWeight.Bold).fontColor('#101828')
          Text(this.role === 'student' ? '完成今天的学习任务，一点点进步' : '为孩子规划更合适的学习路径').fontSize(13).fontColor('#667085')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Image($r('app.media.avatar')).width(46).height(46).borderRadius(23)
          .onClick(() => this.appPathStack.pushPathByName(AppRoutes.PROFILE, null))
      }.width('100%')
      Row({ space: 9 }) {
        Text('⌕').fontSize(22).fontColor('#667085')
        Text('搜索课程、试卷或知识点').fontSize(13).fontColor('#98A2B3').layoutWeight(1)
        Text('搜索').fontSize(12).fontColor('#2F6BFF')
      }.height(40).padding({ left: 13, right: 13 }).backgroundColor(Color.White).borderRadius(12).width('100%')
        .onClick(() => this.appPathStack.pushPathByName(AppRoutes.COURSES, null))
    }.width('100%')
  }
}
