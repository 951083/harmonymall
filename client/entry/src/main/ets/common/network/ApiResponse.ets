/**
 * 与后端统一响应体对应：{ code, message, data }
 * code = 0 表示成功
 */
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}
