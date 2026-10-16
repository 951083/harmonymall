import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { AppConfig } from '../common/AppConfig';
import { UserStore } from '../common/store/UserStore';
import { User } from '../model/Models';

/**
 * 编辑个人资料：昵称 / 手机号 / 头像
 * 保存成功后写回 AppStorage（UserStore.updateUser），让「我的」页即时刷新
 */
@Entry
@Component
struct ProfileEditPage {

  @State nickname: string = '';
  @State phone: string = '';
  @State avatar: string = '';
  @State username: string = '';
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @StorageProp('token') @Watch('onTokenChange') token: string = '';

  onTokenChange(): void {
    this.load();
  }

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.loading = false;
      return;
    }
    // 先用本地缓存的用户信息填充表单，接口返回后再覆盖，避免白屏
    const cached: User | null = UserStore.user();
    if (cached) {
      this.apply(cached);
    }
    this.loading = true;
    try {
      const user: User = await Api.profile();
      this.apply(user);
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '加载失败' });
    } finally {
      this.loading = false;
    }
  }

  apply(user: User): void {
    this.username = user.username;
    this.nickname = user.nickname ?? '';
    this.phone = user.phone ?? '';
    this.avatar = user.avatar ?? '';
  }

  validPhone(value: string): boolean {
    if (value.length === 0) {
      return true;
    }
    return value.length === 11 && value.charAt(0) === '1';
  }

  async save(): Promise<void> {
    if (this.nickname.length === 0) {
      promptAction.showToast({ message: '昵称不能为空' });
      return;
    }
    if (!this.validPhone(this.phone)) {
      promptAction.showToast({ message: '请填写 11 位手机号' });
      return;
    }
    this.submitting = true;
    try {
      await Api.updateProfile(this.nickname, this.avatar, this.phone);
      // 同步更新本地缓存，MePage 等页面无需重新拉接口即可显示新昵称
      const current: User | null = UserStore.user();
      if (current) {
        const next: User = {
          id: current.id,
          username: current.username,
          nickname: this.nickname,
          avatar: this.avatar,
          phone: this.phone
        };
        UserStore.updateUser(next);
      }
      promptAction.showToast({ message: '保存成功', duration: 1200 });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '保存失败' });
    } finally {
      this.submitting = false;
    }
  }

  /** 只读展示行（用户名不可改） */
  @Builder
  readonlyRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#182431')
        .width(64)
      Text(value)
        .fontSize(14)
        .fontColor('#8A9199')
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  field(label: string, value: string, placeholder: string, isNumber: boolean, onChange: (v: string) => void) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(14)
        .fontColor('#182431')
        .width(64)
      TextInput({ placeholder: placeholder, text: value })
        .type(isNumber ? InputType.Number : InputType.Normal)
        .height(40)
        .backgroundColor('#F5F6F8')
        .borderRadius(6)
        .padding({ left: 12, right: 12 })
        .layoutWeight(1)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
  }

  build() {
    Column() {
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontColor('#0A59F7')
          .padding({ top: 9, bottom: 9, right: 16 })
          .onClick(() => {
            router.back();
          })
        Text('编辑资料')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Blank()
      }
      .width('100%')
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor('#FFFFFF')

      if (!UserStore.isLogin()) {
        Column({ space: 12 }) {
          Text('请先登录')
            .fontSize(14)
            .fontColor('#8A9199')
          Button('去登录')
            .fontSize(13)
            .backgroundColor('#0A59F7')
            .fontColor('#FFFFFF')
            .height(34)
            .onClick(() => router.pushUrl({ url: 'pages/LoginPage' }))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 头像预览
            Column({ space: 8 }) {
              if (this.avatar.length > 0) {
                // 头像可能是相对路径（/img/avatar.png），必须补全图片域名前缀
                Image(AppConfig.imgUrl(this.avatar))
                  .width(72)
                  .height(72)
                  .borderRadius(36)
                  .objectFit(ImageFit.Cover)
              } else {
                Stack() {
                  Circle({ width: 72, height: 72 }).fill('#0A59F7')
                  Text(this.nickname.length > 0 ? this.nickname.substring(0, 1) : '客')
                    .fontSize(26)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                }
              }
              Text('当前头像预览（留空则使用首字母头像）')
                .fontSize(11)
                .fontColor('#8A9199')
            }
            .width('100%')
            .padding({ top: 16, bottom: 8 })

            Column({ space: 0 }) {
              this.readonlyRow('用户名', this.username.length > 0 ? this.username : '—')
              Divider().color('#EEF0F3').strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.field('昵称', this.nickname, '请输入昵称', false, (v: string) => {
                this.nickname = v;
              })
              Divider().color('#EEF0F3').strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.field('手机号', this.phone, '请输入 11 位手机号', true, (v: string) => {
                this.phone = v;
              })
              Divider().color('#EEF0F3').strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.field('头像', this.avatar, '图片链接，选填', false, (v: string) => {
                this.avatar = v;
              })
            }
            .borderRadius(8)
            .clip(true)

            Text('用户名不可修改；昵称会作为商品评价的展示名。')
              .fontSize(11)
              .fontColor('#8A9199')

            Button(this.submitting ? '保存中…' : '保存')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('#0A59F7')
              .height(44)
              .width('100%')
              .borderRadius(22)
              .enabled(!this.submitting)
              .onClick(() => this.save())
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ minHeight: '100%' })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
