/**
 * 格式化工具
 */
export class FormatUtil {

  /** 分 -> ¥399.00 */
  static money(fen: number): string {
    if (!fen) {
      return '¥0.00';
    }
    return '¥' + (fen / 100).toFixed(2);
  }

  /** 2026-10-14T10:00:00 -> 2026-10-14 10:00 */
  static dateTime(iso: string): string {
    if (!iso) {
      return '';
    }
    return iso.replace('T', ' ').substring(0, 16);
  }

  /** 订单状态码 -> 文案 */
  static orderStatus(status: number): string {
    const map: Record<number, string> = {
      0: '待付款',
      1: '待发货',
      2: '待收货',
      3: '已完成',
      4: '已取消',
      5: '退款中',
      6: '已退款'
    };
    return map[status] ?? '未知状态';
  }

  /** 解析 JSON 快照，失败返回空对象 */
  static parseSnapshot(json: string): Record<string, string> {
    try {
      return JSON.parse(json) as Record<string, string>;
    } catch (e) {
      return {};
    }
  }

  /**
   * 规格快照 → 可读文本
   * 数据库/接口里规格存的是原始 JSON（如 {"规格":"高质双头…"}），
   * 直接展示会露出 JSON 符号，统一转成「值1 / 值2」；非 JSON 内容原样返回
   */
  static specText(raw: string): string {
    if (!raw || raw.charAt(0) !== '{') {
      return raw;
    }
    const specs: Record<string, string> = FormatUtil.parseSnapshot(raw);
    const keys: string[] = Object.keys(specs);
    const parts: string[] = [];
    for (const key of keys) {
      parts.push(specs[key]);
    }
    return parts.length > 0 ? parts.join(' / ') : raw;
  }
}
