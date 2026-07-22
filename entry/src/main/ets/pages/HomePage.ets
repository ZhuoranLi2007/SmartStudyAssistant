import { AppRoutes, SearchRouteParam } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { EducationEntranceGrid } from '../components/home/EducationEntranceGrid';
import { HomeHeader } from '../components/home/HomeHeader';
import { MainTabBar } from '../components/MainTabBar';

@Component
export struct HomePage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State searchText: string = '';

  private doSearch(): void {
    const keyword: string = this.searchText.trim();
    if (!keyword) return;
    const param: SearchRouteParam = new SearchRouteParam();
    param.keyword = keyword;
    this.appPathStack.pushPathByName(AppRoutes.SEARCH_RESULT, param);
  }

  @Builder
  private searchBar() {
    Row({ space: 12 }) {
      Text('🔍')
        .fontSize(18)
        .fontColor('#98A2B3')
      TextInput({ placeholder: '搜索课程或试卷名称', text: this.searchText })
        .placeholderColor('#98A2B3')
        .fontSize(14)
        .height(48)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.searchText = value)
        .onSubmit(() => this.doSearch())
      Button('搜索')
        .height(36)
        .fontSize(13)
        .backgroundColor('#2F6BFF')
        .onClick(() => this.doSearch())
    }
    .width('100%')
    .padding({ left: 16, right: 8, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .borderRadius(24)
    .shadow({ radius: 6, color: 'rgba(0,0,0,0.06)', offsetY: 2 })
  }

  @Builder
  private startTodayCard() {
    Column({ space: 12 }) {
      Text('今日学习').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#172033').width('100%')
      Stack({ alignContent: Alignment.TopEnd }) {
        Row() {
          Column({ space: 8 }) {
            Text('开启今日学习').fontSize(21).fontWeight(FontWeight.Bold).fontColor(Color.White)
            Text('查看今日学习任务，保持专注').fontSize(13).fontColor('rgba(255,255,255,0.92)')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Stack() {
            Text('→').fontSize(20).fontColor('#2F6BFF').fontWeight(FontWeight.Bold)
          }
          .width(46)
          .height(46)
          .backgroundColor(Color.White)
          .borderRadius(23)
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.15)', offsetY: 3 })
        }
        .width('100%')
        .padding(20)
        .linearGradient({
          angle: 135,
          colors: [['#2563EB', 0.0], ['#3B82F6', 0.45], ['#60A5FA', 1.0]]
        })
        .borderRadius(20)

        Stack() {
          Text('✦').fontSize(40).fontColor('rgba(255,255,255,0.22)')
        }
        .width(70)
        .height(70)
        .margin({ top: 8, right: 8 })
      }
      .width('100%')
      .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDY_PLAN, null))
    }.width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 18 }) {
            HomeHeader()
            this.searchBar()
            EducationEntranceGrid()
            this.startTodayCard()
          }.padding({ left: 16, right: 16, top: 12, bottom: 24 }).width('100%')
        }.layoutWeight(1).width('100%')
        MainTabBar({ activeRoute: AppRoutes.HOME })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
