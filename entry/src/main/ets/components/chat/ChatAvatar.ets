import { ChatRole } from '../../model/AiModels';

@Component
export struct ChatAvatar {
  @Prop role: ChatRole = ChatRole.ASSISTANT;
  @Prop avatarSize: number = 40;

  build() {
    if (this.role === ChatRole.ASSISTANT) {
      Image($r('app.media.ai_assistant_avatar'))
        .width(this.avatarSize).height(this.avatarSize).objectFit(ImageFit.Cover).borderRadius(this.avatarSize / 2)
        .border({ width: 1, color: '#D9E5FF' })
    } else {
      Image($r('app.media.avatar'))
        .width(this.avatarSize).height(this.avatarSize).objectFit(ImageFit.Cover).borderRadius(this.avatarSize / 2)
        .border({ width: 1, color: '#E4E7EC' })
    }
  }
}
