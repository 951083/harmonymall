/**
 * 数据模型：与后端实体 / 视图对象对应（字段名与后端 JSON 一致）
 * 金额单位：分
 */

export interface User {
  id: number;
  username: string;
  nickname?: string;
  avatar?: string;
  phone?: string;
}

export interface Banner {
  id: number;
  image: string;
  linkType?: string;
  linkValue?: string;
}

export interface Category {
  id: number;
  parentId: number;
  name: string;
  level: number;
  children?: Category[];
}

export interface Product {
  id: number;
  categoryId: number;
  name: string;
  subtitle?: string;
  /** 图文详情（富文本 HTML） */
  detail?: string;
  mainImage: string;
  /** 最低价（分） */
  price: number;
  /** 原价（分） */
  originalPrice?: number;
  sales: number;
}

export interface ProductSku {
  id: number;
  productId: number;
  /** 规格 JSON，如 {"颜色":"皓月白","尺码":"M"} */
  specs: string;
  /** 售价（分） */
  price: number;
  stock: number;
  image: string;
}

export interface ProductDetail {
  product: Product;
  skus: ProductSku[];
}

export interface ProductQuery {
  keyword?: string;
  categoryId?: number;
  sort?: string;
  page?: number;
  size?: number;
}

export interface PageResult<T> {
  list: T[];
  total: number;
  page: number;
  size: number;
}

export interface CartVO {
  id: number;
  skuId: number;
  productId: number;
  productName: string;
  image: string;
  specs: string;
  price: number;
  quantity: number;
  selected: number;
  /** 当前 SKU 库存：0 表示售罄 */
  stock?: number;
}

export interface Address {
  id?: number;
  receiver: string;
  phone: string;
  province: string;
  city: string;
  district: string;
  detail: string;
  isDefault?: number;
}

export interface Order {
  id: number;
  orderNo: string;
  userId: number;
  totalAmount: number;
  /** 优惠金额（分） */
  discountAmount?: number;
  payAmount: number;
  addressSnapshot: string;
  remark?: string;
  status: number;
  payTime?: string;
  createdAt: string;
}

export interface OrderItem {
  id: number;
  orderId: number;
  skuId: number;
  productId: number;
  price: number;
  quantity: number;
  productSnapshot: string;
  /** 是否已评价（后端按订单明细回填，用于决定「评价」入口是否展示） */
  reviewed?: boolean;
}

export interface OrderDetail {
  id: number;
  orderNo: string;
  userId: number;
  totalAmount: number;
  discountAmount?: number;
  payAmount: number;
  addressSnapshot: string;
  remark?: string;
  status: number;
  payTime?: string;
  shipTime?: string;
  finishTime?: string;
  /** 取消原因（已取消订单展示） */
  cancelReason?: string;
  /** 退款原因（退款中 / 已退款订单展示） */
  refundReason?: string;
  /** 退款完成时间（已退款订单展示） */
  refundTime?: string;
  createdAt: string;
  items: OrderItem[];
}

export interface Review {
  id: number;
  orderItemId?: number;
  userId: number;
  /** 评价人昵称（后端脱敏后返回） */
  nickname?: string;
  avatar?: string;
  skuId: number;
  rating: number;
  content: string;
  createdAt: string;
}

export interface SimpleSku {
  skuId: number;
  productId: number;
  name: string;
  image: string;
  price: number;
  /** 规格 JSON（收藏 / 足迹列表展示用） */
  specs?: string;
  /** 库存：0 表示售罄，端上置灰 */
  stock?: number;
}

export interface Message {
  id: number;
  title: string;
  content: string;
  type: string;
  isRead: number;
  createdAt: string;
}

/**
 * 优惠券（领券中心 / 我的优惠券 共用）
 * status：null 领券中心未领取；0 未使用 1 已使用 2 已过期
 */
export interface Coupon {
  /** 我的券 ID（未领取时为 null） */
  id?: number;
  couponId: number;
  name: string;
  amount: number;
  threshold: number;
  validDays?: number;
  description?: string;
  /** 剩余可领数量，-1 不限量 */
  remain?: number;
  /** 当前用户是否已领取 */
  claimed?: boolean;
  expireTime?: string;
  status?: number;
}

export interface HomeData {
  banners: Banner[];
  categories: Category[];
  recommend: Product[];
}

export interface LoginResult {
  token: string;
  user: User;
}

/* ---------------- 请求体 DTO ----------------
 * ArkTS 不允许无类型的对象字面量(arkts-no-untyped-obj-literals)，
 * 因此 POST/PUT 的请求体统一用类实例构造。
 */

export class LoginRequest {
  username: string = '';
  password: string = '';

  constructor(username: string, password: string) {
    this.username = username;
    this.password = password;
  }
}

export class RegisterRequest {
  username: string = '';
  password: string = '';
  phone: string = '';

  constructor(username: string, password: string, phone: string) {
    this.username = username;
    this.password = password;
    this.phone = phone;
  }
}

export class ReviewRequest {
  /** 订单明细 ID：从订单详情页评价时必填，后端据此校验归属与重复评价 */
  orderItemId: number = 0;
  skuId: number = 0;
  rating: number = 5;
  content: string = '';

  constructor(orderItemId: number, skuId: number, rating: number, content: string) {
    this.orderItemId = orderItemId;
    this.skuId = skuId;
    this.rating = rating;
    this.content = content;
  }
}

export class CartAddRequest {
  skuId: number = 0;
  quantity: number = 1;

  constructor(skuId: number, quantity: number) {
    this.skuId = skuId;
    this.quantity = quantity;
  }
}

export class CartUpdateRequest {
  quantity: number = 1;
  selected: number = 1;

  constructor(quantity: number, selected: number) {
    this.quantity = quantity;
    this.selected = selected;
  }
}

export class OrderCreateRequest {
  cartIds: number[] = [];
  addressId: number = 0;
  /** 使用的优惠券 ID（t_user_coupon.id），不用券传 0 */
  couponId: number = 0;
  /** 幂等令牌：防止重复提交生成两笔相同订单 */
  clientToken: string = '';
  remark: string = '';

  constructor(cartIds: number[], addressId: number, remark: string, couponId: number, clientToken: string) {
    this.cartIds = cartIds;
    this.addressId = addressId;
    this.remark = remark;
    this.couponId = couponId;
    this.clientToken = clientToken;
  }
}

/** 取消订单 / 申请退款时携带的原因（body） */
export class OrderReasonBody {
  reason: string;

  constructor(reason: string) {
    this.reason = reason;
  }
}

export class ProfileUpdateRequest {
  nickname: string = '';
  avatar: string = '';
  phone: string = '';

  constructor(nickname: string, avatar: string, phone: string) {
    this.nickname = nickname;
    this.avatar = avatar;
    this.phone = phone;
  }
}
