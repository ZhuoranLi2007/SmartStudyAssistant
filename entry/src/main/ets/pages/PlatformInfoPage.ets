import { PageHeader } from '../components/PageHeader';

@Component
export struct PlatformInfoPage {
  @Prop infoType: string = 'ABOUT';

  private title(): string {
    if (this.infoType === 'ACCOUNT') return '账号与安全';
    if (this.infoType === 'AGREEMENT') return '用户协议';
    if (this.infoType === 'PRIVACY') return '隐私政策';
    return '关于平台';
  }

  private content(): string {
    if (this.infoType === 'ACCOUNT') {
      return '账号登录状态由应用统一会话服务管理，密码不会保存在页面状态中。退出登录会清除本地令牌、用户ID、角色和学生档案关联信息。后续接入真实接口后，可在此扩展修改密码与设备管理功能。';
    }
    if (this.infoType === 'AGREEMENT') {
      return '欢迎使用智学规划助手。用户应合法使用课程、试卷与AI咨询功能，不得上传违法或侵犯他人权益的内容。课程购买为结课项目中的模拟流程，不产生真实交易。';
    }
    if (this.infoType === 'PRIVACY') {
      return '平台仅为提供学习规划服务而处理账号、学生档案和学习记录。模型密钥不会保存在鸿蒙前端；麦克风与图片能力仅在用户主动操作时使用。演示数据不代表真实用户信息。';
    }
    return '智学规划助手是一款面向中小学生与家长的教育辅助应用，通过规则推荐、课程和试卷数据以及AI解释，帮助家庭选择更合适的学习方案。\n\n当前版本：1.0.0\n技术栈：HarmonyOS NEXT + ArkTS + FastAPI + MySQL';
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: this.title() })
        Scroll() {
          Column({ space: 18 }) {
            Image($r('app.media.realImageGen_education_0')).width(96).height(96).borderRadius(22)
            Text(this.title()).fontSize(22).fontWeight(FontWeight.Bold)
            Text(this.content()).fontSize(15).fontColor('#475467').lineHeight(25).width('100%')
          }.padding(22).width('100%')
        }.layoutWeight(1)
      }.width('100%').height('100%').backgroundColor('#F8FAFC')
    }.hideTitleBar(true)
  }
}
