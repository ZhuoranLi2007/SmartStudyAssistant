import { AppRoutes, StudentRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { MainTabBar } from '../components/MainTabBar';

@Component
export struct HomePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.USERNAME) username: string = '家长';
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';

  @Builder
  private featureCard(title: string, description: string, routeName: string, image: Resource) {
    Row({ space: 14 }) {
      Image(image).width(72).height(72).borderRadius(16).objectFit(ImageFit.Cover)
      Column({ space: 7 }) {
        Text(title).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#101828')
        Text(description).fontSize(13).fontColor('#667085').maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›').fontSize(28).fontColor('#98A2B3')
    }
    .width('100%')
    .padding(16)
    .borderRadius(18)
    .backgroundColor(Color.White)
    .shadow({ radius: 12, color: '#14000000', offsetY: 4 })
    .onClick(() => {
      if (routeName === AppRoutes.AI_ASSISTANT) {
        this.appPathStack.pushPathByName(routeName, new StudentRouteParam());
      } else {
        this.appPathStack.pushPathByName(routeName, null);
      }
    })
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            Row() {
              Column({ space: 5 }) {
                Text(`你好，${this.username || '家长'}`).fontSize(26).fontWeight(FontWeight.Bold)
                Text(this.role === 'student' ? '今天也要完成学习任务哦' : '为孩子找到更合适的学习路径').fontSize(14).fontColor('#667085')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Image($r('app.media.avatar')).width(52).height(52).borderRadius(26)
            }.width('100%')
            Row() {
              Column({ space: 7 }) {
                Text('小明 · 六年级').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
                Text('数学 75分 · 薄弱点：应用题、百分数').fontSize(13).fontColor('#E8EEFF')
                Text('本周计划 2 项，已完成 0 项').fontSize(13).fontColor('#E8EEFF')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Image($r('app.media.realImageGen_education_3')).width(92).height(92).borderRadius(18).objectFit(ImageFit.Cover)
            }
            .padding(18)
            .borderRadius(22)
            .linearGradient({ angle: 120, colors: [['#2F6BFF', 0], ['#7A5AF8', 1]] })
            this.featureCard('学生档案', '记录成绩、薄弱点和学习目标', AppRoutes.STUDENT_PROFILE, $r('app.media.realImageGen_education_1'))
            this.featureCard('AI 课程咨询', '通过文字或语音获得可解释推荐', AppRoutes.AI_ASSISTANT, $r('app.media.realImageGen_education_2'))
            this.featureCard('分层课程', '浏览基础、提升和拔高课程', AppRoutes.COURSES, $r('app.media.realImageGen_education_4'))
            this.featureCard('试卷资源', '按知识点训练，也可上传图片 OCR', AppRoutes.PAPERS, $r('app.media.realImageGen_education_5'))
          }
          .padding({ left: 20, right: 20, top: 24, bottom: 24 })
        }
        .layoutWeight(1)
        MainTabBar({ activeRoute: AppRoutes.HOME })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFC')
    }
    .hideTitleBar(true)
  }
}
