import http from '@ohos.net.http';
import router from '@ohos.router';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../AppConfig';
import { ApiResponse } from './ApiResponse';
import { UserStore } from '../store/UserStore';

/**
 * 网络层：基于 @ohos.net.http 的 Promise 封装
 * - 自动携带 JWT token
 * - 统一解析 { code, message, data }
 * - code = 40100 时清理登录态并跳转登录页
 * - 关键节点打 console 日志（hilog tag: JSAPP），便于联调排查
 */
export class HttpClient {

  private static readonly TIMEOUT: number = 15000;

  private static async request<T>(method: http.RequestMethod, url: string, body?: object): Promise<T> {
    hilog.info(0x0000, 'HarmonyMall', '[HttpClient] 开始请求 ' + method + ' ' + url);
    const httpRequest = http.createHttp();
    hilog.info(0x0000, 'HarmonyMall', '[HttpClient] http 对象已创建');
    const fullUrl: string = AppConfig.BASE_URL + url;
    try {
      const header: Record<string, string> = {
        'Content-Type': 'application/json'
      };
      const token: string = UserStore.token();
      if (token.length > 0) {
        header['Authorization'] = 'Bearer ' + token;
      }
      const options: http.HttpRequestOptions = {
        method: method,
        header: header,
        readTimeout: HttpClient.TIMEOUT,
        connectTimeout: HttpClient.TIMEOUT,
        expectDataType: http.HttpDataType.STRING,
        extraData: body === undefined ? undefined : JSON.stringify(body)
      };

      hilog.info(0x0000, 'HarmonyMall', '[HttpClient] 即将发起网络请求: ' + fullUrl);
      let response: http.HttpResponse;
      try {
        response = await httpRequest.request(fullUrl, options);
        hilog.info(0x0000, 'HarmonyMall', '[HttpClient] 收到响应: ' + response.responseCode);
      } catch (netErr) {
        hilog.error(0x0000, 'HarmonyMall', '[HttpClient] 网络错误 ' + fullUrl + ' : ' + ((netErr as Error).message ?? String(netErr)));
        throw new Error('网络异常，请检查后端地址与网络');
      }

      if (response.responseCode !== 200) {
        throw new Error('HTTP ' + response.responseCode);
      }
      let result: ApiResponse<T>;
      try {
        result = JSON.parse(response.result as string) as ApiResponse<T>;
      } catch (parseErr) {
        hilog.error(0x0000, 'HarmonyMall', '[HttpClient] 解析失败: ' + fullUrl);
        throw new Error('数据解析失败');
      }
      hilog.info(0x0000, 'HarmonyMall', '[HttpClient] 响应体解析完成 code=' + result.code);
      if (result.code === 0) {
        return result.data as T;
      }
      if (result.code === 40100) {
        UserStore.logout();
        router.pushUrl({ url: 'pages/LoginPage' }).catch(() => { });
      }
      throw new Error(result.message || '请求失败');
    } finally {
      httpRequest.destroy();
    }
  }

  static get<T>(url: string): Promise<T> {
    return HttpClient.request<T>(http.RequestMethod.GET, url);
  }

  static post<T>(url: string, body?: object): Promise<T> {
    return HttpClient.request<T>(http.RequestMethod.POST, url, body);
  }

  static put<T>(url: string, body?: object): Promise<T> {
    return HttpClient.request<T>(http.RequestMethod.PUT, url, body);
  }

  static delete<T>(url: string): Promise<T> {
    return HttpClient.request<T>(http.RequestMethod.DELETE, url);
  }
}
