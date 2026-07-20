@Component
export struct TypingIndicator {
  build() {
    Row({ space: 6 }) {
      Text('●').fontSize(8).fontColor('#4777F5')
      Text('●').fontSize(8).fontColor('#7A5AF8')
      Text('●').fontSize(8).fontColor('#9FB5F9')
      Text('智学助手正在分析学习情况…').fontSize(12).fontColor('#667085')
    }.padding({ left: 4, right: 4, top: 4, bottom: 4 })
  }
}
