import {
  CourseOrder, CustomerMessage, DataLoadResult, DataSource, FavoriteItem, FavoriteType, FaqItem,
  LearningReport, MyCourse, OrderFilter, OrderStatus, ProfileOverview, WrongQuestion
} from '../model/ProfileModels';

export class ProfileMockData {
  private static courses: MyCourse[] = [
    { id: 1, courseId: 5, name: '六年级数学应用题提升课', grade: '六年级', subject: '数学', completed: false,
      progress: { completedLessons: 8, totalLessons: 16, progress: 50, nextLesson: '百分数应用题专项' } },
    { id: 2, courseId: 8, name: '六年级英语阅读进阶课', grade: '六年级', subject: '英语', completed: false,
      progress: { completedLessons: 5, totalLessons: 12, progress: 42, nextLesson: '上下文词义推断' } },
    { id: 3, courseId: 1, name: '五年级数学计算基础课', grade: '五年级', subject: '数学', completed: true,
      progress: { completedLessons: 10, totalLessons: 10, progress: 100, nextLesson: '课程已完成' } }
  ];

  private static orders: CourseOrder[] = [
    { id: 1, orderNo: 'SS20260719001', courseId: 5, courseName: '六年级数学应用题提升课', amount: 299, createTime: '2026-07-19 09:30', status: OrderStatus.PAID },
    { id: 2, orderNo: 'SS20260718002', courseId: 8, courseName: '六年级英语阅读进阶课', amount: 269, createTime: '2026-07-18 15:20', status: OrderStatus.PENDING },
    { id: 3, orderNo: 'SS20260712003', courseId: 11, courseName: '六年级英语拓展训练课', amount: 399, createTime: '2026-07-12 11:05', status: OrderStatus.CANCELLED }
  ];

  private static favorites: FavoriteItem[] = [
    { id: 1, targetId: 5, type: FavoriteType.COURSE, title: '六年级数学应用题提升课', subtitle: '六年级 · 数学', tag: '中等提升型' },
    { id: 2, targetId: 10, type: FavoriteType.PAPER, title: '六年级数学百分数专项卷', subtitle: '20题 · 中等', tag: '百分数' },
    { id: 3, targetId: 0, type: FavoriteType.KNOWLEDGE, title: '行程问题', subtitle: '数学重点知识', tag: '六年级' }
  ];

  private static wrongQuestions: WrongQuestion[] = [
    { id: 1, subject: '数学', knowledgePoint: '百分数', question: '一件商品降价20%后售价为80元，原价是多少？', userAnswer: '96元', correctAnswer: '100元', explanation: '现价是原价的80%，所以原价为80÷80%=100元。', mastered: false },
    { id: 2, subject: '数学', knowledgePoint: '行程问题', question: '甲每小时走5千米，2.5小时走多少千米？', userAnswer: '10千米', correctAnswer: '12.5千米', explanation: '路程=速度×时间，即5×2.5=12.5千米。', mastered: false },
    { id: 3, subject: '英语', knowledgePoint: '一般过去时', question: 'Yesterday, Tom ____ to school by bus.', userAnswer: 'go', correctAnswer: 'went', explanation: 'Yesterday表示过去时间，go的过去式是went。', mastered: true }
  ];

  static getOverview(): ProfileOverview {
    return {
      familyCode: 'FAM-2026', studentBindCode: 'STU-6A8K', studentName: '小明', studentBound: true,
      learning: { courseCount: 3, weeklyTaskCount: 5, favoriteCount: ProfileMockData.favorites.length, wrongQuestionCount: ProfileMockData.wrongQuestions.length }
    };
  }

  static getCourses(): MyCourse[] { return ProfileMockData.courses.slice(); }

  static getOrders(filter: OrderFilter): CourseOrder[] {
    if (filter === OrderFilter.ALL) return ProfileMockData.orders.slice();
    return ProfileMockData.orders.filter((item: CourseOrder) => item.status === filter.toString());
  }

  static payOrder(orderId: number): CourseOrder {
    for (let index: number = 0; index < ProfileMockData.orders.length; index++) {
      if (ProfileMockData.orders[index].id === orderId) ProfileMockData.orders[index].status = OrderStatus.PAID;
    }
    return ProfileMockData.orders.filter((item: CourseOrder) => item.id === orderId)[0];
  }

  static getFavorites(type: FavoriteType): FavoriteItem[] {
    return ProfileMockData.favorites.filter((item: FavoriteItem) => item.type === type);
  }

  static removeFavorite(id: number): void {
    ProfileMockData.favorites = ProfileMockData.favorites.filter((item: FavoriteItem) => item.id !== id);
  }

  static getWrongQuestions(subject: string): WrongQuestion[] {
    if (subject === '全部') return ProfileMockData.wrongQuestions.slice();
    return ProfileMockData.wrongQuestions.filter((item: WrongQuestion) => item.subject === subject);
  }

  static masterQuestion(id: number): void {
    for (let index: number = 0; index < ProfileMockData.wrongQuestions.length; index++) {
      if (ProfileMockData.wrongQuestions[index].id === id) ProfileMockData.wrongQuestions[index].mastered = true;
    }
  }

  static getReport(): LearningReport {
    return { completedCourseCount: 3, completedPaperCount: 6, averageAccuracy: 86, taskCompletionRate: 78,
      improvedPoints: ['分数计算', '英语阅读定位'], weakPoints: ['百分数应用题', '一般过去时'],
      aiSuggestion: '本周任务完成情况良好。建议下周将数学学习重点放在百分数应用题，每次训练后整理一道典型错题；英语继续保持每日15分钟阅读。' };
  }

  static getFaqs(): FaqItem[] {
    return [
      { id: 1, question: '如何绑定学生档案？', answer: '家长在学生档案中生成绑定码，学生登录后在“我的”页面输入该绑定码即可。' },
      { id: 2, question: '如何查看课程订单？', answer: '进入“我的-我的订单”，可以按全部、待支付、已支付和已取消筛选。' },
      { id: 3, question: '课程购买后在哪里学习？', answer: '已支付课程会出现在“我的课程”中，也可以加入学习计划。' },
      { id: 4, question: '如何取消收藏？', answer: '进入“我的收藏”，点击收藏卡片右侧的“取消收藏”。' },
      { id: 5, question: 'AI 推荐结果是否可以调整？', answer: '可以。完善成绩、薄弱知识点和学习目标后重新咨询，系统会重新计算。' },
      { id: 6, question: '如何找回学习记录？', answer: '登录原账号后，学习计划和报告会按学生档案恢复。演示数据仅在当前运行期有效。' }
    ];
  }

  static getCustomerMessages(): CustomerMessage[] {
    return [{ id: 'welcome', fromUser: false, content: '您好，我是在线客服。请问有什么可以帮助您？', createTime: '现在' }];
  }

  static mockResult<T>(data: T, message: string = '当前部分内容为演示数据'): DataLoadResult<T> {
    return { data: data, source: DataSource.MOCK, message: message };
  }
}
