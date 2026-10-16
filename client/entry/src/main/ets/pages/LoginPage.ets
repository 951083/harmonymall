import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';

/**
 * 登录 / 注册
 * 演示账号：zhangsan / 123456
 */
@Entry
@Component
struct LoginPage {

  @State currentTab: number = 0;
  @State username: string = '';
  @State password: string = '';
  @State phone: string = '';
  @State code: string = '';
  @State submitting: boolean = false;

  async doLogin(): Promise<void> {
    if (this.username.length === 0 || this.password.length === 0) {
      promptAction.showToast({ message: '请输入账号和密码' });
      return;
    }
    this.submitting = true;
    try {
      const result = await Api.login(this.username, this.password);
      UserStore.saveLogin(result.token, result.user);
      promptAction.showToast({ message: '登录成功', duration: 1200 });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '登录失败' });
    } finally {
      this.submitting = false;
    }
  }

  goRegister(): void {
    router.pushUrl({ url: 'pages/RegisterPage' });
  }

  build() {
    Column({ space: 20 }) {
      Column({ space: 6 }) {
        Text('鸿蒙商城')
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Text('HarmonyOS 原生电商应用')
          .fontSize(13)
          .fontColor('#8A9199')
      }
      .margin({ bottom: 12 })

      // 登录方式 Tab
      Row({ space: 24 }) {
        Text('账号登录')
          .fontSize(15)
          .fontWeight(this.currentTab === 0 ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.currentTab === 0 ? '#0A59F7' : '#8A9199')
          .onClick(() => {
            this.currentTab = 0;
          })
        Text('验证码登录')
          .fontSize(15)
          .fontWeight(this.currentTab === 1 ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.currentTab === 1 ? '#0A59F7' : '#8A9199')
          .onClick(() => {
            this.currentTab = 1;
          })
      }

      if (this.currentTab === 0) {
        Column({ space: 14 }) {
          TextInput({ placeholder: '账号', text: this.username })
            .height(44)
            .backgroundColor('#F5F6F8')
            .borderRadius(8)
            .padding({ left: 14 })
            .onChange((value: string) => {
              this.username = value;
            })
          TextInput({ placeholder: '密码', text: this.password })
            .height(44)
            .type(InputType.Password)
            .backgroundColor('#F5F6F8')
            .borderRadius(8)
            .padding({ left: 14 })
            .onChange((value: string) => {
              this.password = value;
            })
          Button('登 录')
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor('#0A59F7')
            .height(44)
            .borderRadius(22)
            .enabled(!this.submitting)
            .onClick(() => this.doLogin())
          Row({ space: 4 }) {
            Text('没有账号？')
              .fontSize(13)
              .fontColor('#8A9199')
            Text('注册新账号')
              .fontSize(13)
              .fontColor('#0A59F7')
              .onClick(() => this.goRegister())
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      } else {
        Column({ space: 14 }) {
          TextInput({ placeholder: '手机号', text: this.phone })
            .height(44)
            .type(InputType.PhoneNumber)
            .backgroundColor('#F5F6F8')
            .borderRadius(8)
            .padding({ left: 14 })
            .onChange((value: string) => {
              this.phone = value;
            })
          Row({ space: 10 }) {
            TextInput({ placeholder: '验证码', text: this.code })
              .height(44)
              .type(InputType.Number)
              .backgroundColor('#F5F6F8')
              .borderRadius(8)
              .padding({ left: 14 })
              .layoutWeight(1)
              .onChange((value: string) => {
                this.code = value;
              })
            Button('获取验证码')
              .fontSize(13)
              .fontColor('#0A59F7')
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#0A59F7' })
              .height(44)
              .onClick(() => {
                promptAction.showToast({ message: '学习演示环境：请使用账号密码登录', duration: 2000 });
              })
          }
          Button('登 录')
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor('#0A59F7')
            .height(44)
            .borderRadius(22)
            .onClick(() => {
              promptAction.showToast({ message: '学习演示环境：请使用账号密码登录', duration: 2000 });
            })
        }
      }

      Text('演示账号：zhangsan / 123456')
        .fontSize(12)
        .fontColor('#8A9199')
        .margin({ top: 8 })
    }
    .padding(28)
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Center)
  }
}
