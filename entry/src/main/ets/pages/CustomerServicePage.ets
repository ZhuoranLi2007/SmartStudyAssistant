import { AppRoutes } from '../common/AppRoutes';
import { PageHeader } from '../components/PageHeader';
import { ProfileMockData } from '../data/ProfileMockData';
import { FaqItem } from '../model/ProfileModels';

@Component
export struct CustomerServicePage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State expandedId: number = 0;
  private faqs: FaqItem[] = ProfileMockData.getFaqs();

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '客服中心' })
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 10 }) {
              Text('需要帮助？').fontSize(22).fontWeight(FontWeight.Bold).width('100%')
              Text('在线客服为本地演示，可帮助您快速了解平台功能。').fontSize(13).fontColor('#667085').width('100%')
              Row({ space: 10 }) {
                Button('在线客服').layoutWeight(1).backgroundColor('#2F6BFF').onClick(() => this.appPathStack.pushPathByName(AppRoutes.CUSTOMER_CHAT, null))
                Button('意见反馈').layoutWeight(1).backgroundColor('#7A5AF8').onClick(() => this.appPathStack.pushPathByName(AppRoutes.FEEDBACK, null))
              }.width('100%')
            }.padding(18).width('100%').backgroundColor(Color.White).borderRadius(18)
            Text('常见问题').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
            ForEach(this.faqs, (faq: FaqItem) => {
              Column({ space: 8 }) {
                Row() {
                  Text(faq.question).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1)
                  Text(this.expandedId === faq.id ? '⌃' : '⌄').fontSize(18).fontColor('#667085')
                }.width('100%')
                if (this.expandedId === faq.id) {
                  Text(faq.answer).fontSize(13).fontColor('#667085').lineHeight(21).width('100%')
                }
              }.padding(15).width('100%').backgroundColor(Color.White).borderRadius(14)
                .onClick(() => this.expandedId = this.expandedId === faq.id ? 0 : faq.id)
            }, (faq: FaqItem) => `${faq.id}`)
            Column({ space: 7 }) {
              Text('人工服务').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
              Text('客服电话：400-800-2026').fontSize(14).fontColor('#2F6BFF').width('100%')
              Text('服务时间：周一至周日 08:00-21:00').fontSize(12).fontColor('#667085').width('100%')
            }.padding(16).width('100%').backgroundColor(Color.White).borderRadius(16)
          }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
