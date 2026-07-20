import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { VisionAiService, VisionOcrResult } from '../ai/VisionAiService';
import { AppConfig } from '../common/AppConfig';
import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { Paper } from '../model/DomainModels';
import { MockDataService } from '../service/MockDataService';
import { PaperAnalysis, PaperService } from '../service/PaperService';

@Component
export struct PaperResourcePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State searchText: string = '';
  @State grade: string = '全部';
  @State subject: string = '全部';
  @State allPapers: Paper[] = MockDataService.getPapers();
  @State papers: Paper[] = MockDataService.getPapers();
  @State ocrText: string = '';
  @State ocrSuggestion: string = '';
  @State isRecognizing: boolean = false;
  @State usingMockData: boolean = true;

  aboutToAppear(): void {
    void this.loadPapers();
  }

  private async loadPapers(): Promise<void> {
    if (AppConfig.USE_MOCK_DATA) {
      this.allPapers = MockDataService.getPapers();
      this.usingMockData = true;
      this.refresh();
      return;
    }
    try {
      this.allPapers = await PaperService.getPapers();
      this.usingMockData = false;
    } catch (error) {
      console.warn(`试卷目录加载失败，使用演示数据: ${JSON.stringify(error)}`);
      this.allPapers = MockDataService.getPapers();
      this.usingMockData = true;
    }
    this.refresh();
  }

  private refresh(): void {
    const keyword: string = this.searchText.trim();
    this.papers = this.allPapers.filter((paper: Paper) =>
      (this.grade === '全部' || paper.grade === this.grade) &&
      (this.subject === '全部' || paper.subject === this.subject) &&
      (!keyword || paper.name.includes(keyword) || paper.knowledgePoints.join('、').includes(keyword)));
  }

  private async selectAndRecognize(): Promise<void> {
    if (this.isRecognizing) return;
    this.isRecognizing = true;
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const selected = await picker.select(options);
      if (selected.photoUris.length === 0) return;
      const ocrResult: VisionOcrResult = await VisionAiService.recognizeText(selected.photoUris[0]);
      if (!ocrResult.success) {
        promptAction.showToast({ message: ocrResult.message });
        return;
      }
      this.ocrText = ocrResult.text;
      if (AppConfig.USE_MOCK_DATA) {
        this.ocrSuggestion = '识别建议：请确认科目、知识点和难度后再保存';
      } else {
        const analysis: PaperAnalysis = await PaperService.analyze(ocrResult.text);
        this.ocrSuggestion = `识别建议：${analysis.subject} · ${analysis.knowledgePoints.join('、')} · ${analysis.difficulty}`;
      }
      promptAction.showToast({ message: ocrResult.message });
    } catch (error) {
      promptAction.showToast({ message: '图片选择或 OCR 识别失败' });
      console.error(`试卷 OCR 失败: ${JSON.stringify(error)}`);
    } finally {
      this.isRecognizing = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '试卷资源' })
        Column({ space: 10 }) {
          Search({ placeholder: '搜索试卷或知识点', value: this.searchText })
            .onChange((value: string) => { this.searchText = value; this.refresh(); })
          Scroll() { Row({ space: 8 }) {
            ForEach(['全部', '一年级', '二年级', '三年级', '四年级', '五年级', '六年级'], (item: string) => {
              Button(item).fontSize(12).height(34).backgroundColor(this.grade === item ? '#2F6BFF' : '#D0D5DD')
                .onClick(() => { this.grade = item; this.refresh(); })
            }, (item: string) => item)
          } }.scrollable(ScrollDirection.Horizontal)
          Scroll() { Row({ space: 8 }) {
            ForEach(['全部', '语文', '数学', '英语'], (item: string) => {
              Button(item).fontSize(12).height(34).backgroundColor(this.subject === item ? '#2F6BFF' : '#D0D5DD')
                .onClick(() => { this.subject = item; this.refresh(); })
            }, (item: string) => item)
            Button(this.isRecognizing ? '识别中...' : '上传图片 OCR').enabled(!this.isRecognizing)
              .height(34).backgroundColor('#7A5AF8').onClick(() => void this.selectAndRecognize())
          } }.scrollable(ScrollDirection.Horizontal)
          if (this.usingMockData) {
            Text('当前试卷目录为演示数据').fontSize(11).fontColor('#B54708').width('100%')
          }
          if (this.ocrText) {
            Column({ space: 8 }) {
              Text('OCR 文字（确认后再保存）').fontWeight(FontWeight.Bold).width('100%')
              TextArea({ text: this.ocrText }).height(90).onChange((value: string) => this.ocrText = value)
              Text(this.ocrSuggestion).fontSize(13).fontColor('#2F6BFF').width('100%')
            }.padding(12).backgroundColor('#EEF4FF').borderRadius(12)
          }
        }.padding({ left: 16, right: 16, bottom: 10 }).width('100%')
        List({ space: 10 }) {
          ForEach(this.papers, (paper: Paper) => {
            ListItem() {
              Column({ space: 7 }) {
                Text(paper.name).fontSize(17).fontWeight(FontWeight.Bold).width('100%')
                Text(`${paper.grade} · ${paper.subject} · ${paper.difficulty} · ${paper.questionCount}题`).fontSize(13).fontColor('#667085').width('100%')
                Text(`知识点：${paper.knowledgePoints.join('、')}`).fontSize(12).fontColor('#667085').width('100%')
              }.padding(15).width('100%').backgroundColor(Color.White).borderRadius(15).onClick(() => {
                const param: IdRouteParam = new IdRouteParam();
                param.id = paper.id;
                this.appPathStack.pushPathByName(AppRoutes.PAPER_DETAIL, param);
              })
            }
          }, (paper: Paper) => `${paper.id}`)
        }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
