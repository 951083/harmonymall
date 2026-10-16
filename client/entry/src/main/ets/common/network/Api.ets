import { AppConfig } from '../AppConfig';
import { HttpClient } from './HttpClient';
import {
  Address, Banner, CartVO, Category, Coupon, HomeData, LoginResult, Message,
  Order, OrderDetail, PageResult, Product, ProductDetail,
  ProductQuery, Review, SimpleSku, User
} from '../../model/Models';
import {
  CartAddRequest, CartUpdateRequest, LoginRequest, OrderCreateRequest, OrderReasonBody,
  ProfileUpdateRequest, RegisterRequest, ReviewRequest
} from '../../model/Models';

/**
 * 接口定义：与 harmonymall-server 的 Controller 一一对应
 */
export class Api {

  // ---------- 认证 ----------
  static login(username: string, password: string): Promise<LoginResult> {
    return HttpClient.post<LoginResult>('/auth/login', new LoginRequest(username, password));
  }

  static register(username: string, password: string, phone: string): Promise<void> {
    return HttpClient.post<void>('/auth/register', new RegisterRequest(username, password, phone));
  }

  // ---------- 首页 / 分类 ----------
  static home(): Promise<HomeData> {
    return HttpClient.get<HomeData>('/home');
  }

  static categories(): Promise<Category[]> {
    return HttpClient.get<Category[]>('/categories');
  }

  // ---------- 商品 ----------
  static productList(query: ProductQuery): Promise<PageResult<Product>> {
    const parts: string[] = [];
    if (query.keyword) {
      parts.push('keyword=' + encodeURIComponent(query.keyword));
    }
    if (query.categoryId) {
      parts.push('categoryId=' + query.categoryId);
    }
    if (query.sort) {
      parts.push('sort=' + query.sort);
    }
    parts.push('page=' + (query.page ?? 1));
    parts.push('size=' + (query.size ?? AppConfig.PAGE_SIZE));
    return HttpClient.get<PageResult<Product>>('/products?' + parts.join('&'));
  }

  static productDetail(id: number): Promise<ProductDetail> {
    return HttpClient.get<ProductDetail>('/products/' + id);
  }

  static productReviews(productId: number): Promise<Review[]> {
    return HttpClient.get<Review[]>('/products/' + productId + '/reviews');
  }

  /** 热门搜索词（按真实搜索次数统计） */
  static hotKeywords(): Promise<string[]> {
    return HttpClient.get<string[]>('/products/hot-keywords');
  }

  /** 发表评价（orderItemId 来自订单明细，0 表示非订单评价） */
  static addReview(orderItemId: number, skuId: number, rating: number, content: string): Promise<void> {
    return HttpClient.post<void>('/reviews', new ReviewRequest(orderItemId, skuId, rating, content));
  }

  // ---------- 购物车 ----------
  static cartList(): Promise<CartVO[]> {
    return HttpClient.get<CartVO[]>('/cart');
  }

  static addCart(skuId: number, quantity: number): Promise<number> {
    return HttpClient.post<number>('/cart', new CartAddRequest(skuId, quantity));
  }

  static updateCart(id: number, quantity: number, selected: number): Promise<void> {
    return HttpClient.put<void>('/cart/' + id, new CartUpdateRequest(quantity, selected));
  }

  static deleteCart(id: number): Promise<void> {
    return HttpClient.delete<void>('/cart/' + id);
  }

  // ---------- 订单 ----------
  static createOrder(cartIds: number[], addressId: number, remark: string,
                     couponId: number = 0, clientToken: string = ''): Promise<Order> {
    return HttpClient.post<Order>('/orders',
      new OrderCreateRequest(cartIds, addressId, remark, couponId, clientToken));
  }

  static orderList(status?: number, page: number = 1): Promise<PageResult<Order>> {
    let url = '/orders?page=' + page + '&size=' + AppConfig.PAGE_SIZE;
    if (status !== undefined) {
      url += '&status=' + status;
    }
    return HttpClient.get<PageResult<Order>>(url);
  }

  static orderDetail(id: number): Promise<OrderDetail> {
    return HttpClient.get<OrderDetail>('/orders/' + id);
  }

  static payOrder(id: number): Promise<void> {
    return HttpClient.post<void>('/orders/' + id + '/pay');
  }

  /** 取消订单；reason 为取消原因（可选，后端会落默认值） */
  static cancelOrder(id: number, reason?: string): Promise<void> {
    return HttpClient.post<void>('/orders/' + id + '/cancel',
      reason ? new OrderReasonBody(reason) : undefined);
  }

  /** 模拟商家发货（无管理端，用于打通 收货 → 评价 链路） */
  static shipOrder(id: number): Promise<void> {
    return HttpClient.post<void>('/orders/' + id + '/ship');
  }

  static confirmOrder(id: number): Promise<void> {
    return HttpClient.post<void>('/orders/' + id + '/confirm');
  }

  /** 申请退款（进入退款中，由后端定时任务模拟商家审核后自动完成）；reason 可选 */
  static refundOrder(id: number, reason?: string): Promise<void> {
    return HttpClient.post<void>('/orders/' + id + '/refund',
      reason ? new OrderReasonBody(reason) : undefined);
  }

  // ---------- 地址 ----------
  static addressList(): Promise<Address[]> {
    return HttpClient.get<Address[]>('/address');
  }

  static saveAddress(address: Address): Promise<void> {
    return HttpClient.post<void>('/address', address);
  }

  static updateAddress(address: Address): Promise<void> {
    return HttpClient.put<void>('/address/' + address.id, address);
  }

  static deleteAddress(id: number): Promise<void> {
    return HttpClient.delete<void>('/address/' + id);
  }

  static setDefaultAddress(id: number): Promise<void> {
    return HttpClient.put<void>('/address/' + id + '/default');
  }

  // ---------- 用户中心 ----------
  static profile(): Promise<User> {
    return HttpClient.get<User>('/user/profile');
  }

  static updateProfile(nickname: string, avatar: string, phone: string): Promise<void> {
    return HttpClient.put<void>('/user/profile', new ProfileUpdateRequest(nickname, avatar, phone));
  }

  static favorites(): Promise<SimpleSku[]> {
    return HttpClient.get<SimpleSku[]>('/user/favorites');
  }

  static addFavorite(skuId: number): Promise<void> {
    return HttpClient.post<void>('/user/favorites?skuId=' + skuId);
  }

  static removeFavorite(skuId: number): Promise<void> {
    return HttpClient.delete<void>('/user/favorites/' + skuId);
  }

  static footprints(): Promise<SimpleSku[]> {
    return HttpClient.get<SimpleSku[]>('/user/footprints');
  }

  static addFootprint(skuId: number): Promise<void> {
    return HttpClient.post<void>('/user/footprints?skuId=' + skuId);
  }

  static messages(): Promise<Message[]> {
    return HttpClient.get<Message[]>('/user/messages');
  }

  static readMessage(id: number): Promise<void> {
    return HttpClient.put<void>('/user/messages/' + id + '/read');
  }

  // ---------- 优惠券 ----------
  /** 领券中心 */
  static coupons(): Promise<Coupon[]> {
    return HttpClient.get<Coupon[]>('/coupons');
  }

  /** 领取优惠券 */
  static claimCoupon(id: number): Promise<void> {
    return HttpClient.post<void>('/coupons/' + id + '/claim');
  }

  /** 我的优惠券（status 不传返回全部） */
  static myCoupons(status?: number): Promise<Coupon[]> {
    let url = '/coupons/mine';
    if (status !== undefined) {
      url += '?status=' + status;
    }
    return HttpClient.get<Coupon[]>(url);
  }

  /** 下单可用券（amount 为订单金额，单位分） */
  static usableCoupons(amount: number): Promise<Coupon[]> {
    return HttpClient.get<Coupon[]>('/coupons/usable?amount=' + amount);
  }
}
