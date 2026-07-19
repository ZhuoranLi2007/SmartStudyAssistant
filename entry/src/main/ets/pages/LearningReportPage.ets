import { AppStorageKeys } from '../common/AppStorageKeys';
import { PageHeader } from '../components/PageHeader';
import { ProfileMockData } from '../data/ProfileMockData';
import { DataLoadResult, DataSource, LearningReport } from '../model/ProfileModels';
import { LearningReportService } from '../service/LearningReportService';

@Component
export struct LearningReportPage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @State report: LearningReport = ProfileMockData.getReport();
  @State source: DataSource = DataSource.MOCK;

  aboutToAppear(): void { void this.load(); }
  private async load(): Promise<void> {
    const result: DataLoadResult<LearningReport> = await LearningReportService.getReport(this.studentProfileId);
    this.report = result.data; this.source = result.source;
  }

  @Builder
  private metric(value: string, label: string) {
    Column({ space: 6 }) {
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#2F6BFF')
      Text(label).fontSize(12).fontColor('#667085')
    }.layoutWeight(1).padding({ top: 13, bottom: 13 })
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '学习报告' })
        Scroll() {
          Column({ space: 14 }) {
            Text('本周学习概览').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
            Row() {
              this.metric(`${this.report.completedCourseCount}`, '完成课程')
              this.metric(`${this.report.completedPaperCount}`, '完成试卷')
              this.metric(`${this.report.averageAccuracy}%`, '平均正确率')
            }.width('100%').backgroundColor(Color.White).borderRadius(18)
            Column({ space: 10 }) {
              Row() { Text('学习任务完成率').fontSize(16).fontWeight(FontWeight.Bold).layoutWeight(1); Text(`${this.report.taskCompletionRate}%`).fontColor('#2F6BFF') }.width('100%')
              Progress({ value: this.report.taskCompletionRate, total: 100, type: ProgressType.Linear }).color('#2F6BFF').width('100%')
            }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
            Column({ space: 10 }) {
              Text('进步知识点').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
              ForEach(this.report.improvedPoints, (point: string) => { Text(`✓ ${point}`).fontSize(14).fontColor('#12B76A').width('100%') })
            }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
            Column({ space: 10 }) {
              Text('薄弱知识点').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
              ForEach(this.report.weakPoints, (point: string) => { Text(`• ${point}`).fontSize(14).fontColor('#F79009').width('100%') })
            }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(18)
            Column({ space: 9 }) {
              Text('AI 学习建议').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
              Text(this.report.aiSuggestion).fontSize(14).fontColor('#475467').lineHeight(23).width('100%')
            }.padding(16).width('100%').backgroundColor('#EEF4FF').borderRadius(18)
            if (this.source === DataSource.MOCK) Text('本报告为演示数据').fontSize(11).fontColor('#98A2B3').width('100%')
          }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
