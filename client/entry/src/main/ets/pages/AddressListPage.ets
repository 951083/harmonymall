import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Api } from '../common/network/Api';
import { UserStore } from '../common/store/UserStore';
import { Address } from '../model/Models';
import { EmptyView } from '../components/EmptyView';
import { LoadingView } from '../components/LoadingView';

/**
 * 地址管理：列表 / 默认地址 / 编辑 / 删除 / 选择（pick 模式供确认订单使用）
 */
@Entry
@Component
struct AddressListPage {

  @State addresses: Address[] = [];
  @State loading: boolean = true;
  @State pickMode: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.pickMode = !!(params && params['pick']);
    this.load();
  }

  async load(): Promise<void> {
    if (!UserStore.isLogin()) {
      this.loading = false;
      return;
    }
    this.loading = true;
    try {
      const list: Address[] = await Api.addressList();
      this.addresses = list ?? [];
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '加载失败' });
    } finally {
      this.loading = false;
    }
  }

  async setDefault(address: Address): Promise<void> {
    if (!address.id) {
      return;
    }
    try {
      await Api.setDefaultAddress(address.id);
      promptAction.showToast({ message: '已设为默认地址', duration: 1200 });
      this.load();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '操作失败' });
    }
  }

  async remove(address: Address): Promise<void> {
    if (!address.id) {
      return;
    }
    try {
      await Api.deleteAddress(address.id);
      this.load();
    } catch (e) {
      promptAction.showToast({ message: (e as Error).message ?? '删除失败' });
    }
  }

  onItemClick(address: Address): void {
    if (this.pickMode && address.id) {
      this.setDefault(address).then(() => {
        router.back();
      });
      return;
    }
    router.pushUrl({ url: 'pages/AddressEditPage', params: { id: address.id ?? 0 } });
  }

  build() {
    Column() {
      if (!UserStore.isLogin()) {
        EmptyView({
          text: '登录后管理地址',
          actionText: '去登录',
          onAction: () => router.pushUrl({ url: 'pages/LoginPage' })
        })
      } else if (this.loading) {
        LoadingView()
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.addresses, (address: Address) => {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text(address.receiver)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#182431')
                    Text(address.phone)
                      .fontSize(12)
                      .fontColor('#8A9199')
                    if (address.isDefault === 1) {
                      Text('默认')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .backgroundColor('#0A59F7')
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .borderRadius(3)
                    }
                  }
                  Text(address.province + address.city + address.district + ' ' + address.detail)
                    .fontSize(12)
                    .fontColor('#8A9199')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (address.isDefault !== 1) {
                  Text('设默认')
                    .fontSize(12)
                    .fontColor('#0A59F7')
                    .onClick(() => this.setDefault(address))
                }
                Text('删除')
                  .fontSize(12)
                  .fontColor('#8A9199')
                  .onClick(() => this.remove(address))
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => this.onItemClick(address))
            })

            if (this.addresses.length === 0) {
              EmptyView({ text: '还没有收货地址' })
            }
          }
          .padding(12)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)

        Button('新增地址')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#0A59F7')
          .width('90%')
          .height(42)
          .borderRadius(21)
          .margin({ bottom: 14 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/AddressEditPage' });
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
