import { AppRoutes } from '../common/AppRoutes';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { AIRecommendCard } from '../components/home/AIRecommendCard';
import { CourseHorizontalList } from '../components/home/CourseHorizontalList';
import { EducationEntranceGrid } from '../components/home/EducationEntranceGrid';
import { HomeBannerSwiper } from '../components/home/HomeBannerSwiper';
import { HomeHeader } from '../components/home/HomeHeader';
import { HomeLearningOverviewCard } from '../components/home/HomeLearningOverviewCard';
import { LatestCourseSection } from '../components/home/LatestCourseSection';
import { PaperTrainingSection } from '../components/home/PaperTrainingSection';
import { TodayTaskCard } from '../components/home/TodayTaskCard';
import { MainTabBar } from '../components/MainTabBar';
import { MockHomeData } from '../data/MockHomeData';
import { HomeData, HomeDataSource, HomeLoadResult } from '../model/HomeModels';
import { HomeService } from '../service/HomeService';

@Component
export struct HomePage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State homeData: HomeData = MockHomeData.getHomeData();
  @State dataSource: HomeDataSource = HomeDataSource.MOCK;
  @State sourceMessage: string = '当前部分首页内容为演示数据';
  @State isLoading: boolean = false;

  aboutToAppear(): void { void this.loadHomeData(); }

  private async loadHomeData(): Promise<void> {
    if (this.isLoading) return;
    this.isLoading = true;
    try {
      const result: HomeLoadResult = await HomeService.getHomeData(this.studentProfileId);
      this.homeData = result.data;
      this.studentProfileId = result.data.studentProfileId;
      this.dataSource = result.source;
      this.sourceMessage = result.message;
    } catch (error) {
      console.error(`首页数据加载失败: ${JSON.stringify(error)}`);
      this.homeData = MockHomeData.getHomeData();
      this.dataSource = HomeDataSource.MOCK;
      this.sourceMessage = '网络服务暂不可用，已展示本地演示内容';
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 15 }) {
            HomeHeader()
            HomeBannerSwiper({ banners: this.homeData.banners })
            EducationEntranceGrid()
            HomeLearningOverviewCard({ overview: this.homeData.overview })
            AIRecommendCard({ course: this.homeData.recommendedCourse })
            CourseHorizontalList({ courses: this.homeData.popularCourses })
            LatestCourseSection({ courses: this.homeData.latestCourses })
            PaperTrainingSection({ papers: this.homeData.recommendedPapers })
            TodayTaskCard({ task: this.homeData.todayTask })
            if (this.dataSource === HomeDataSource.MOCK) {
              Text(this.sourceMessage || '当前部分首页内容为演示数据')
                .fontSize(11).fontColor('#98A2B3').lineHeight(18).width('100%')
            }
          }.padding({ left: 16, right: 16, top: 12, bottom: 24 }).width('100%')
        }.layoutWeight(1).width('100%')
        MainTabBar({ activeRoute: AppRoutes.HOME })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
