import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';
import { Address } from '../model/Models';

/**
 * 地址编辑：新增 / 修改
 */
@Entry
@Component
struct AddressEditPage {

  @State addressId: number = 0;
  @State receiver: string = '';
  @State phone: string = '';
  @State province: string = '';
  @State city: string = '';
  @State district: string = '';
  @State detail: string = '';
  @State isDefault: boolean = false;
  @State saving: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number>;
    const id: number = params && params['id'] ? Number(params['id']) : 0;
    this.addressId = id;
    if (id > 0 && UserStore.isLogin()) {
      Api.addressList()
        .then((list: Address[]) => {
          for (const address of list) {
            if (address.id === id) {
              this.receiver = address.receiver;
              this.phone = address.phone;
              this.province = address.province;
              this.city = address.city;
              this.district = address.district;
              this.detail = address.detail;
              this.isDefault = address.isDefault === 1;
              return;
            }
          }
        })
        .catch(() => { });
    }
  }

  async save(): Promise<void> {
    if (this.receiver.length === 0 || this.phone.length === 0) {
      promptAction.showToast({ message: '请填写收货人和手机号' });
      return;
    }
    if (this.detail.length === 0) {
      promptAction.showToast({ message: '请填写详细地址' });
      return;
    }
    this.saving = true;
    try {
      const address: Address = {
        receiver: this.receiver,
        phone: this.phone,
        province: this.province,
        city: this.city,
        district: this.district,
        detail: this.detail,
        isDefault: this.isDefault ? 1 : 0
      };
      if (this.addressId > 0) {
        address.id = this.addressId;
        await Api.updateAddress(address);
      } else {
        await Api.saveAddress(address);
      }
      promptAction.showToast({ message: '已保存', duration: 1200 });
      router.back();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '保存失败' });
    } finally {
      this.saving = false;
    }
  }

  @Builder
  field(label: string, placeholder: string, value: string, onChange: (v: string) => void) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(14)
        .fontColor('#182431')
        .width(70)
      TextInput({ placeholder: placeholder, text: value })
        .height(40)
        .backgroundColor('#F5F6F8')
        .borderRadius(8)
        .padding({ left: 12 })
        .layoutWeight(1)
        .onChange(onChange)
    }
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      this.field('收货人', '姓名', this.receiver, (v: string) => {
        this.receiver = v;
      })
      this.field('手机号', '11 位手机号', this.phone, (v: string) => {
        this.phone = v;
      })
      this.field('省', '如：河南省', this.province, (v: string) => {
        this.province = v;
      })
      this.field('市', '如：郑州市', this.city, (v: string) => {
        this.city = v;
      })
      this.field('区/县', '如：二七区', this.district, (v: string) => {
        this.district = v;
      })
      this.field('详细地址', '街道、门牌号等', this.detail, (v: string) => {
        this.detail = v;
      })

      Row() {
        Text('设为默认地址')
          .fontSize(14)
          .fontColor('#182431')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.isDefault })
          .onChange((isOn: boolean) => {
            this.isDefault = isOn;
          })
      }
      .width('100%')

      Button('保存')
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor('#0A59F7')
        .width('100%')
        .height(44)
        .borderRadius(22)
        .margin({ top: 10 })
        .enabled(!this.saving)
        .onClick(() => this.save())
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
