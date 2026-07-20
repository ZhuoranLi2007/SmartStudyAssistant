@Component
export struct ChatInputBar {
  @Link text: string;
  @Prop isSending: boolean = false;
  @Prop isRecording: boolean = false;
  onSend: () => void = (): void => {};
  onVoice: () => void = (): void => {};

  build() {
    Row({ space: 8 }) {
      Button(this.isRecording ? '■' : '◉')
        .width(42).height(42).fontSize(15)
        .fontColor(this.isRecording ? Color.White : '#5B65E8')
        .backgroundColor(this.isRecording ? '#F04438' : '#EEF1FF')
        .onClick(() => this.onVoice())
      TextArea({ text: this.text, placeholder: '描述学生学情或直接提问…' })
        .layoutWeight(1).height(48).fontSize(14).backgroundColor('#F6F8FC').borderRadius(22)
        .padding({ left: 13, right: 13, top: 9, bottom: 8 }).maxLength(2000)
        .onChange((value: string) => this.text = value)
      Button(this.isSending ? '…' : '发送')
        .width(62).height(42).fontSize(13).fontWeight(FontWeight.Medium)
        .backgroundColor('#356DF3').enabled(!this.isSending && this.text.trim().length > 0)
        .onClick(() => this.onSend())
    }
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .width('100%').backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#E9EDF5' })
  }
}
