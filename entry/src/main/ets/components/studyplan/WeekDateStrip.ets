import { WeekDayItem } from '../../model/StudyPlanModels';

@Component
export struct WeekDateStrip {
  @Prop days: WeekDayItem[] = [];
  @Prop selectedDate: string = '';
  onSelect: (date: string) => void = (_date: string): void => {};

  build() {
    Row({ space: 4 }) {
      ForEach(this.days, (item: WeekDayItem) => {
        Column({ space: 5 }) {
          Text(item.dayLabel).fontSize(10).fontColor(this.selectedDate === item.date ? Color.White : '#667085')
          Text(item.dateLabel).fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor(this.selectedDate === item.date ? Color.White : '#344054')
          if (item.isToday) {
            Circle().width(4).height(4).fill(this.selectedDate === item.date ? Color.White : '#2F6BFF')
          } else {
            Blank().height(4)
          }
        }
        .layoutWeight(1).padding({ top: 8, bottom: 7 })
        .backgroundColor(this.selectedDate === item.date ? '#2F6BFF' : Color.White)
        .borderRadius(12)
        .onClick(() => this.onSelect(item.date))
      }, (item: WeekDayItem) => item.date)
    }.width('100%')
  }
}
