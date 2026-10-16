import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';

/**
 * 注册页：创建新账号，注册成功后自动登录并返回
 * 账号规则：3-20 位字母/数字/下划线；密码 6-20 位；手机号 11 位
 */
@Entry
@Component
struct RegisterPage {

  @State username: string = '';
  @State phone: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State submitting: boolean = false;

  /** 表单校验：通过返回空串，否则返回错误提示 */
  private validate(): string {
    if (!/^[a-zA-Z0-9_]{3,20}$/.test(this.username)) {
      return '账号需为 3-20 位字母、数字或下划线';
    }
    if (!/^1\d{10}$/.test(this.phone)) {
      return '请输入 11 位手机号';
    }
    if (this.password.length < 6 || this.password.length > 20) {
      return '密码长度需为 6-20 位';
    }
    if (this.password !== this.confirmPassword) {
      return '两次输入的密码不一致';
    }
    return '';
  }

  async doRegister(): Promise<void> {
    const err = this.validate();
    if (err.length > 0) {
      promptAction.showToast({ message: err });
      return;
    }
    this.submitting = true;
    try {
      await Api.register(this.username, this.password, this.phone);
      // 注册成功：立即登录并保存登录态
      const result = await Api.login(this.username, this.password);
      UserStore.saveLogin(result.token, result.user);
      promptAction.showToast({ message: '注册成功，已自动登录', duration: 1500 });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '注册失败，请重试' });
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  field(placeholder: string, value: string, isPassword: boolean, onChange: (v: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .height(46)
      .backgroundColor('#F5F6F8')
      .borderRadius(8)
      .padding({ left: 14 })
      .type(isPassword ? InputType.Password : InputType.Normal)
      .onChange(onChange)
  }

  build() {
    Column({ space: 14 }) {
      // 顶部返回
      Row() {
        Text('← 返回')
          .fontSize(15)
          .fontColor('#0A59F7')
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')

      // 标题
      Column({ space: 6 }) {
        Text('创建账号')
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Text('注册成功后自动登录')
          .fontSize(13)
          .fontColor('#8A9199')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 8, bottom: 10 })

      // 表单
      this.field('账号（3-20 位字母、数字或下划线）', this.username, false, (v: string) => {
        this.username = v;
      })
      this.field('手机号（11 位）', this.phone, false, (v: string) => {
        this.phone = v;
      })
      this.field('密码（6-20 位）', this.password, true, (v: string) => {
        this.password = v;
      })
      this.field('确认密码', this.confirmPassword, true, (v: string) => {
        this.confirmPassword = v;
      })

      Button('注 册')
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor('#0A59F7')
        .width('100%')
        .height(44)
        .borderRadius(22)
        .margin({ top: 10 })
        .enabled(!this.submitting)
        .onClick(() => this.doRegister())

      Row({ space: 4 }) {
        Text('已有账号？')
          .fontSize(13)
          .fontColor('#8A9199')
        Text('去登录')
          .fontSize(13)
          .fontColor('#0A59F7')
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 6 })
    }
    .padding(28)
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Center)
  }
}
