import { AiCard } from '../../model/AiModels';

/** 订单功能已移除，保留空组件避免历史引用报错。 */
@Component
export struct OrderCard {
  @Prop card: AiCard;

  build() {
    Column()
  }
}
