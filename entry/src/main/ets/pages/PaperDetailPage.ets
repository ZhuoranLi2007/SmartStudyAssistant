import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { Paper } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';

@Component
export struct PaperDetailPage {
  @Prop paperId: number = 1;
  private paper: Paper = MockDataService.getPaper(this.paperId);

  private addTask(): void {
    MockDataService.addTask(this.paper.name, '试卷', this.paper.subject, this.paper.difficulty);
    promptAction.showToast({ message: '已加入训练计划' });
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '试卷详情' })
        Scroll() {
          Column({ space: 16 }) {
            Image($r('app.media.realImageGen_education_9')).width('100%').height(190).borderRadius(18).objectFit(ImageFit.Cover)
            Text(this.paper.name).fontSize(24).fontWeight(FontWeight.Bold).width('100%')
            Text(`${this.paper.grade} · ${this.paper.subject} · ${this.paper.difficulty}`).fontColor('#2F6BFF').width('100%')
            Text(`题目数量：${this.paper.questionCount}`).width('100%')
            Text(`知识点：${this.paper.knowledgePoints.join('、')}`).width('100%')
            Text(`适用课程：${this.paper.suitableCourseLevel}`).width('100%')
            Text('OCR 内容将在上传图片并确认后显示。').fontSize(13).fontColor('#667085').width('100%')
            Button('加入训练计划').width('100%').backgroundColor('#2F6BFF').onClick(() => this.addTask())
          }.padding(20).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
