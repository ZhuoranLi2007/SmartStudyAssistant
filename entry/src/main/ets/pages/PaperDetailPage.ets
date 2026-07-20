import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../components/PageHeader';
import { Paper } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';
import { AppStorageKeys } from '../common/AppStorageKeys';
import { StudyPlanService } from '../service/StudyPlanService';

@Component
export struct PaperDetailPage {
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @StorageLink(AppStorageKeys.USER_ROLE) role: string = 'parent';
  @Prop paperId: number = 1;
  @State isAdding: boolean = false;
  private paper: Paper = MockDataService.getPaper(this.paperId);

  private async addTask(): Promise<void> {
    if (this.isAdding) return;
    if (this.studentProfileId <= 0) {
      promptAction.showToast({ message: '请先创建或绑定学生档案' });
      return;
    }
    this.isAdding = true;
    try {
      await StudyPlanService.addTask(this.studentProfileId, '试卷', this.paper.id);
      promptAction.showToast({ message: '已加入本周训练计划' });
    } catch (error) {
      const message: string = `${error}`.includes('409') ? '该试卷已经在学习计划中' : '添加失败，请稍后重试';
      promptAction.showToast({ message: message });
    } finally {
      this.isAdding = false;
    }
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
            if (this.role === 'parent') {
              Button(this.isAdding ? '添加中...' : '加入训练计划').width('100%').backgroundColor('#2F6BFF')
                .enabled(!this.isAdding).onClick(() => void this.addTask())
            } else {
              Text('试卷任务由家长账号统一安排').fontSize(13).fontColor('#667085').width('100%').textAlign(TextAlign.Center)
                .padding(12).backgroundColor('#EEF4FF').borderRadius(10)
            }
          }.padding(20).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
