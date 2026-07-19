import { AppConfig } from '../common/AppConfig';
import { ProfileMockData } from '../data/ProfileMockData';
import { CourseOrder, DataLoadResult, DataSource, OrderFilter } from '../model/ProfileModels';
import { HttpClient } from './HttpClient';

export class OrderService {
  static async getOrder(orderId: number): Promise<DataLoadResult<CourseOrder>> {
    if (!AppConfig.USE_MOCK_DATA) {
      try {
        const data: CourseOrder = (await HttpClient.get<CourseOrder>(`/orders/${orderId}`)).data;
        return { data: data, source: DataSource.LIVE, message: '' };
      } catch (error) {
        console.warn(`订单详情接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      }
    }
    const orders: CourseOrder[] = ProfileMockData.getOrders(OrderFilter.ALL);
    for (let index: number = 0; index < orders.length; index++) {
      if (orders[index].id === orderId) return ProfileMockData.mockResult<CourseOrder>(orders[index]);
    }
    return ProfileMockData.mockResult<CourseOrder>(orders[0], '未找到对应订单，显示演示订单');
  }

  static async getOrders(filter: OrderFilter): Promise<DataLoadResult<CourseOrder[]>> {
    if (AppConfig.USE_MOCK_DATA) return ProfileMockData.mockResult<CourseOrder[]>(ProfileMockData.getOrders(filter));
    try {
      const query: string = filter === OrderFilter.ALL ? '' : `?status=${filter}`;
      const data: CourseOrder[] = (await HttpClient.get<CourseOrder[]>(`/orders${query}`)).data;
      return { data: data, source: DataSource.LIVE, message: '' };
    } catch (error) {
      console.warn(`订单接口不可用，使用演示数据: ${JSON.stringify(error)}`);
      return ProfileMockData.mockResult<CourseOrder[]>(ProfileMockData.getOrders(filter));
    }
  }

  static async payOrder(orderId: number): Promise<DataLoadResult<CourseOrder>> {
    if (!AppConfig.USE_MOCK_DATA) {
      try {
        const data: CourseOrder = (await HttpClient.post<CourseOrder>(`/orders/${orderId}/pay`, new Object())).data;
        return { data: data, source: DataSource.LIVE, message: '' };
      } catch (error) {
        console.warn(`支付接口不可用，执行本地演示支付: ${JSON.stringify(error)}`);
      }
    }
    return ProfileMockData.mockResult<CourseOrder>(ProfileMockData.payOrder(orderId), '支付状态仅在当前演示运行期有效');
  }
}
