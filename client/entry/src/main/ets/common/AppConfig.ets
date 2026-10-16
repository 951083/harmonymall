/**
 * 全局配置
 * 注意：BASE_URL / IMG_BASE 中的 IP 必须换成你电脑的局域网 IP（ipconfig 查看），
 * 手机模拟器和真机访问不到 localhost。
 */
export class AppConfig {

  /**
   * 后端接口地址。
   * - 模拟器调试：走 hdc 端口反向转发（电脑执行 `hdc rport tcp:8080 tcp:8080`），
   *   应用用 127.0.0.1 经调试通道直达电脑的 8080（模拟器 QEMU 虚拟网访问不到宿主机网卡 IP）。
   * - 真机调试：换回电脑的局域网 IP（如 http://10.240.12.125:8080/api）。
   */
  static readonly BASE_URL: string = 'http://127.0.0.1:8080/api';

  /** 图片资源地址（后端静态目录，不带 /api） */
  static readonly IMG_BASE: string = 'http://127.0.0.1:8080';

  /** 每页数量 */
  static readonly PAGE_SIZE: number = 10;

  /** 把后端返回的相对路径补全为绝对地址 */
  static imgUrl(path: string): string {
    if (!path) {
      return '';
    }
    if (path.startsWith('http')) {
      return path;
    }
    return AppConfig.IMG_BASE + path;
  }
}
