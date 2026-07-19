import { AppRoutes } from '../common/AppRoutes';
import {
  HomeBanner, HomeCourseItem, HomeData, HomeOverview, HomePaperItem, PracticeQuestion, TodayTaskSummary
} from '../model/HomeModels';

export class MockHomeData {
  static getHomeData(): HomeData {
    const banners: HomeBanner[] = [
      { id: 1, title: 'AI 智能选课', subtitle: '结合成绩与薄弱点，推荐更合适的课程', actionText: '立即咨询', routeName: AppRoutes.AI_ASSISTANT, imageKey: 'AI' },
      { id: 2, title: '专项试卷训练', subtitle: '按年级、学科和知识点精准练习', actionText: '查看试卷', routeName: AppRoutes.PAPERS, imageKey: 'PAPER' },
      { id: 3, title: '本周学习计划', subtitle: '拆分每日任务，让学习更有节奏', actionText: '查看计划', routeName: AppRoutes.STUDY_PLAN, imageKey: 'PLAN' }
    ];
    const overview: HomeOverview = {
      studentBound: true, studentName: '小明', grade: '六年级', subject: '数学', recentScore: 75,
      weakPoints: ['应用题', '百分数'], totalTasks: 5, completedTasks: 3
    };
    const recommendedCourse: HomeCourseItem = {
      id: 5, name: '六年级数学应用题专项提高', grade: '六年级', subject: '数学', difficulty: '中等',
      courseType: '中等提升型', priceText: '¥99', imageKey: 'COURSE_4',
      recommendReason: '基础知识掌握较好，但综合应用题正确率仍有提升空间。'
    };
    const popularCourses: HomeCourseItem[] = [
      { id: 2, name: '五年级数学应用题提高', grade: '五年级', subject: '数学', difficulty: '中等', courseType: '同步提高', priceText: '¥79', imageKey: 'COURSE_1', recommendReason: '' },
      { id: 10, name: '六年级英语阅读启蒙', grade: '六年级', subject: '英语', difficulty: '基础', courseType: '阅读专项', priceText: '免费', imageKey: 'COURSE_9', recommendReason: '' },
      { id: 4, name: '六年级数学基础巩固', grade: '六年级', subject: '数学', difficulty: '基础', courseType: '基础巩固', priceText: '¥59', imageKey: 'COURSE_3', recommendReason: '' },
      { id: 12, name: '六年级英语拓展训练', grade: '六年级', subject: '英语', difficulty: '较难', courseType: '拔高拓展', priceText: '¥129', imageKey: 'COURSE_10', recommendReason: '' }
    ];
    const latestCourses: HomeCourseItem[] = [
      { id: 7, name: '六年级英语词汇基础课', grade: '六年级', subject: '英语', difficulty: '基础', courseType: '今日上新', priceText: '¥49', imageKey: 'COURSE_5', recommendReason: '' },
      { id: 6, name: '六年级数学思维拓展', grade: '六年级', subject: '数学', difficulty: '较难', courseType: '昨日上新', priceText: '¥119', imageKey: 'COURSE_10', recommendReason: '' },
      { id: 8, name: '六年级英语语法提升', grade: '六年级', subject: '英语', difficulty: '中等', courseType: '2天前上新', priceText: '¥89', imageKey: 'COURSE_4', recommendReason: '' },
      { id: 1, name: '五年级数学计算基础', grade: '五年级', subject: '数学', difficulty: '基础', courseType: '3天前上新', priceText: '免费', imageKey: 'COURSE_1', recommendReason: '' }
    ];
    const recommendedPapers: HomePaperItem[] = [
      { id: 9, name: '分数应用题专项', grade: '六年级', subject: '数学', difficulty: '中等', questionCount: 20, imageKey: 'PAPER_MATH' },
      { id: 10, name: '百分数专项训练', grade: '六年级', subject: '数学', difficulty: '中等', questionCount: 25, imageKey: 'PAPER_MATH' },
      { id: 19, name: '英语阅读理解', grade: '六年级', subject: '英语', difficulty: '基础', questionCount: 20, imageKey: 'PAPER_ENGLISH' },
      { id: 20, name: '英语语法强化', grade: '六年级', subject: '英语', difficulty: '中等', questionCount: 25, imageKey: 'PAPER_ENGLISH' }
    ];
    const todayTask: TodayTaskSummary = { totalCount: 3, completedCount: 1, nextTask: '完成百分数应用题专项训练' };
    return { studentProfileId: 1, banners: banners, overview: overview, recommendedCourse: recommendedCourse, popularCourses: popularCourses,
      latestCourses: latestCourses, recommendedPapers: recommendedPapers, todayTask: todayTask };
  }

  static getPracticeQuestions(paperId: number): PracticeQuestion[] {
    if (paperId <= 0 || paperId > 24) return [];
    if (paperId >= 13) {
      return [
        { id: 1, stem: 'Yesterday, Tom ____ to school by bus.', options: [{ label: 'A', content: 'go' }, { label: 'B', content: 'goes' }, { label: 'C', content: 'went' }, { label: 'D', content: 'going' }], correctIndex: 2, explanation: 'Yesterday表示过去时间，go的过去式是went。' },
        { id: 2, stem: 'Which word means“图书馆”？', options: [{ label: 'A', content: 'library' }, { label: 'B', content: 'hospital' }, { label: 'C', content: 'museum' }, { label: 'D', content: 'station' }], correctIndex: 0, explanation: 'library表示图书馆。' },
        { id: 3, stem: 'She ____ reading books after school.', options: [{ label: 'A', content: 'like' }, { label: 'B', content: 'likes' }, { label: 'C', content: 'liked to' }, { label: 'D', content: 'liking' }], correctIndex: 1, explanation: '主语She是第三人称单数，一般现在时使用likes。' },
        { id: 4, stem: 'Choose the opposite of “difficult”.', options: [{ label: 'A', content: 'easy' }, { label: 'B', content: 'heavy' }, { label: 'C', content: 'early' }, { label: 'D', content: 'quiet' }], correctIndex: 0, explanation: 'difficult的反义词是easy。' },
        { id: 5, stem: 'There ____ two books on the desk.', options: [{ label: 'A', content: 'is' }, { label: 'B', content: 'are' }, { label: 'C', content: 'be' }, { label: 'D', content: 'am' }], correctIndex: 1, explanation: 'two books是复数，There be句型使用are。' }
      ];
    }
    return [
      { id: 1, stem: '一件商品降价20%后售价80元，原价是多少元？', options: [{ label: 'A', content: '96' }, { label: 'B', content: '100' }, { label: 'C', content: '120' }, { label: 'D', content: '160' }], correctIndex: 1, explanation: '现价是原价的80%，80÷80%=100元。' },
      { id: 2, stem: '3/5化成百分数是多少？', options: [{ label: 'A', content: '30%' }, { label: 'B', content: '50%' }, { label: 'C', content: '60%' }, { label: 'D', content: '80%' }], correctIndex: 2, explanation: '3÷5=0.6，即60%。' },
      { id: 3, stem: '甲每小时行5千米，2.5小时行多少千米？', options: [{ label: 'A', content: '10' }, { label: 'B', content: '12.5' }, { label: 'C', content: '15' }, { label: 'D', content: '20' }], correctIndex: 1, explanation: '路程=速度×时间，5×2.5=12.5千米。' },
      { id: 4, stem: '一个数的25%是20，这个数是多少？', options: [{ label: 'A', content: '5' }, { label: 'B', content: '45' }, { label: 'C', content: '60' }, { label: 'D', content: '80' }], correctIndex: 3, explanation: '20÷25%=80。' },
      { id: 5, stem: '六（1）班40人，女生占55%，女生有多少人？', options: [{ label: 'A', content: '18' }, { label: 'B', content: '20' }, { label: 'C', content: '22' }, { label: 'D', content: '24' }], correctIndex: 2, explanation: '40×55%=22人。' }
    ];
  }
}
