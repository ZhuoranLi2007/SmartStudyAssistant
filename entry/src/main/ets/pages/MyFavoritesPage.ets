import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppRoutes, IdRouteParam } from '../common/AppRoutes';
import { CourseVideoResolver } from '../common/CourseVideoResolver';
import { PageHeader } from '../components/PageHeader';
import { EmptyStateView } from '../components/profile/EmptyStateView';
import { DataLoadResult, DataSource, FavoriteItem, FavoriteType } from '../model/ProfileModels';
import { FavoriteService } from '../service/FavoriteService';

@Component
export struct MyFavoritesPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @State type: FavoriteType = FavoriteType.COURSE;
  @State items: FavoriteItem[] = [];
  @State source: DataSource = DataSource.MOCK;
  @State isLoading: boolean = false;

  aboutToAppear(): void { void this.load(); }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async load(): Promise<void> {
    if (this.isLoading) return; this.isLoading = true;
    try {
      const result: DataLoadResult<FavoriteItem[]> = await FavoriteService.getFavorites(this.context(), this.type);
      this.items = result.data; this.source = result.source;
    } finally { this.isLoading = false; }
  }

  private select(type: FavoriteType): void { this.type = type; void this.load(); }

  private open(item: FavoriteItem): void {
    if (item.type === FavoriteType.KNOWLEDGE) { this.appPathStack.pushPathByName(AppRoutes.PAPERS, null); return; }
    const param: IdRouteParam = new IdRouteParam(); param.id = item.targetId;
    this.appPathStack.pushPathByName(item.type === FavoriteType.COURSE ? AppRoutes.COURSE_DETAIL : AppRoutes.PAPER_DETAIL, param);
  }

  private async remove(id: number): Promise<void> {
    this.source = await FavoriteService.removeFavorite(this.context(), id);
    promptAction.showToast({ message: '已取消收藏' });
    await this.load();
  }

  @Builder
  private typeButton(label: string, type: FavoriteType) {
    Button(label).layoutWeight(1).backgroundColor(this.type === type ? '#2F6BFF' : '#D0D5DD').onClick(() => this.select(type))
  }

  build() {
    NavDestination() {
      Column() {
        PageHeader({ title: '我的收藏' })
        Row({ space: 8 }) {
          this.typeButton('课程', FavoriteType.COURSE); this.typeButton('试卷', FavoriteType.PAPER); this.typeButton('知识点', FavoriteType.KNOWLEDGE)
        }.padding({ left: 16, right: 16, bottom: 12 }).width('100%')
        if (!this.isLoading && this.items.length === 0) {
          EmptyStateView({ title: '暂无收藏', description: '遇到喜欢的课程或试卷时可以先收藏' }).margin({ left: 16, right: 16 })
        } else {
          List({ space: 10 }) {
            ForEach(this.items, (item: FavoriteItem) => {
              ListItem() {
                Row({ space: 12 }) {
                  if (item.type === FavoriteType.COURSE) {
                    Image(CourseVideoResolver.resolvePreviewByKey(item.coverKey))
                      .width(54).height(54).objectFit(ImageFit.Cover).borderRadius(12)
                  } else {
                    Text(item.type === FavoriteType.PAPER ? '卷' : '知')
                      .width(44).height(44).fontSize(16).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
                      .fontColor('#2F6BFF').backgroundColor('#EEF4FF').borderRadius(12)
                  }
                  Column({ space: 5 }) {
                    Text(item.title).fontSize(15).fontWeight(FontWeight.Bold)
                    Text(`${item.subtitle} · ${item.tag}`).fontSize(12).fontColor('#667085')
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1).onClick(() => this.open(item))
                  Button('取消收藏').fontSize(11).height(34).backgroundColor('#FEF3F2').fontColor('#D92D20').onClick(() => void this.remove(item.id))
                }.padding(14).width('100%').backgroundColor(Color.White).borderRadius(16)
              }
            }, (item: FavoriteItem) => `${item.id}`)
          }.layoutWeight(1).padding({ left: 16, right: 16, bottom: 20 }).width('100%')
        }
        if (this.source === DataSource.LOCAL) Text('收藏保存在当前设备').fontSize(11).fontColor('#98A2B3').margin({ bottom: 10 })
      }.width('100%').height('100%').backgroundColor('#F2F4F7')
    }.hideTitleBar(true)
  }
}
