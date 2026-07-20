import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes } from '../../common/AppRoutes';
import { AppStorageKeys } from '../../common/AppStorageKeys';
import { ProfileOverview } from '../../model/ProfileModels';
import { ProfileService } from '../../service/ProfileService';
import { SessionSnapshot, SessionStorageService } from '../../service/SessionStorageService';

@Component
export struct FamilyInfoCard {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageLink(AppStorageKeys.STUDENT_PROFILE_ID) studentProfileId: number = 0;
  @Prop role: string = 'parent';
  @Prop overview: ProfileOverview = {
    familyCode: 'FAM-2026', studentBindCode: 'STU-6A8K', studentName: '小明', studentBound: true,
    learning: { courseCount: 0, weeklyTaskCount: 0, favoriteCount: 0, wrongQuestionCount: 0 }
  };
  @State bindInput: string = '';
  @State isBinding: boolean = false;

  private async copyText(text: string, label: string): Promise<void> {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: `${label}已复制` });
    } catch (error) {
      console.error(`复制失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '复制失败，请稍后重试' });
    }
  }

  private async bindStudent(): Promise<void> {
    const code: string = this.bindInput.trim();
    if (!code) { promptAction.showToast({ message: '请输入学生绑定码' }); return; }
    if (this.isBinding) return;
    this.isBinding = true;
    try {
      const boundStudentProfileId: number = await ProfileService.bindStudent(code);
      this.studentProfileId = boundStudentProfileId;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const snapshot: SessionSnapshot = await SessionStorageService.load(context);
      snapshot.studentProfileId = boundStudentProfileId;
      await SessionStorageService.save(context, snapshot);
      promptAction.showToast({ message: '学生档案绑定成功' });
    } catch (error) {
      console.error(`绑定失败: ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '绑定失败，请检查绑定码' });
    } finally {
      this.isBinding = false;
    }
  }

  @Builder
  private codeRow(label: string, value: string) {
    Row() {
      Column({ space: 4 }) {
        Text(label).fontSize(12).fontColor('#667085')
        Text(value).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#101828')
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Button('复制').fontSize(12).height(34).backgroundColor('#EEF4FF').fontColor('#2F6BFF')
        .onClick(() => void this.copyText(value, label))
    }.width('100%')
  }

  build() {
    Column({ space: 14 }) {
      Text('家庭与学生').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      if (this.role === 'parent') {
        this.codeRow('家庭邀请码', this.overview.familyCode)
        Divider().color('#EAECF0')
        this.codeRow('学生档案绑定码', this.overview.studentBindCode)
        Row() {
          Text(`当前学生：${this.overview.studentName}`).fontSize(14).layoutWeight(1)
          Text('查看档案 ›').fontSize(13).fontColor('#2F6BFF')
        }.width('100%').onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
      } else if (this.studentProfileId > 0) {
        Text(`已绑定学生档案：${this.overview.studentName}`).fontColor('#12B76A').width('100%')
        Button('查看学生档案').width('100%').backgroundColor('#2F6BFF')
          .onClick(() => this.appPathStack.pushPathByName(AppRoutes.STUDENT_PROFILE, null))
      } else {
        Text('尚未绑定家庭，请向家长获取一次性绑定码。').fontSize(13).fontColor('#667085').width('100%')
        TextInput({ placeholder: '输入学生档案绑定码', text: this.bindInput })
          .onChange((value: string) => this.bindInput = value)
        Button(this.isBinding ? '绑定中...' : '绑定学生档案').width('100%').enabled(!this.isBinding)
          .backgroundColor('#2F6BFF').onClick(() => void this.bindStudent())
      }
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
  }
}
