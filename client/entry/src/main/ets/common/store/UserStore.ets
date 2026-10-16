import { User } from '../../model/Models';

/**
 * 登录态管理（基于 AppStorage，应用生命周期内有效）
 */
export class UserStore {

  private static readonly KEY_TOKEN: string = 'token';
  private static readonly KEY_USER: string = 'userInfo';

  static isLogin(): boolean {
    return UserStore.token().length > 0;
  }

  static token(): string {
    return AppStorage.get<string>(UserStore.KEY_TOKEN) ?? '';
  }

  static user(): User | null {
    const raw = AppStorage.get<string>(UserStore.KEY_USER);
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw) as User;
    } catch (e) {
      return null;
    }
  }

  static saveLogin(token: string, user: User): void {
    // 【重要】必须用 setOrCreate：AppStorage.set() 在 key 不存在时会
    // 「什么都不做并返回 false」（SDK 明确语义），登录态是首次写入，用 set 会静默失败
    AppStorage.setOrCreate(UserStore.KEY_TOKEN, token);
    AppStorage.setOrCreate(UserStore.KEY_USER, JSON.stringify(user));
  }

  static updateUser(user: User): void {
    AppStorage.setOrCreate(UserStore.KEY_USER, JSON.stringify(user));
  }

  static logout(): void {
    AppStorage.delete(UserStore.KEY_TOKEN);
    AppStorage.delete(UserStore.KEY_USER);
  }
}
