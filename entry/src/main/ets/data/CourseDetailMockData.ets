import { CourseDetailData, CourseHighlight, CourseOutlineItem, CourseReview,
  CourseServiceItem, CourseTeacher } from '../model/CourseDetailModels';
import { Course, CourseLevel } from '../model/DomainModels';

export class CourseDetailMockData {
  private static teacherFor(subject: string): CourseTeacher {
    if (subject === '语文') {
      return {
        name: '林婉清', tag: '资深语文教师', avatarKey: 'avatar',
        descriptionLines: ['10年小学语文教学经验', '熟悉小学语文阅读与写作体系', '擅长用情境教学提升理解能力', '注重阅读习惯和表达能力培养']
      };
    }
    if (subject === '英语') {
      return {
        name: '陈思雅', tag: '少儿英语教师', avatarKey: 'avatar',
        descriptionLines: ['8年少儿英语教学经验', '熟悉自然拼读与小学英语体系', '擅长通过语境帮助学生掌握词汇', '注重听说读写综合能力培养']
      };
    }
    return {
      name: '沈晶晶', tag: '资深数学教师', avatarKey: 'avatar',
      descriptionLines: ['10年小学数学教学经验', '熟悉小学高年级数学知识体系', '擅长将复杂知识讲得清晰易懂', '注重培养学生解题思路和学习习惯']
    };
  }

  private static outlineFor(course: Course): CourseOutlineItem[] {
    const durations: string[] = ['10:30', '10:20', '12:10', '09:40', '11:20', '13:00', '10:50', '15:00'];
    let titles: string[] = [];
    if (course.grade === '六年级' && course.subject === '数学') {
      titles = ['分数的意义与基本性质', '分数的加减法', '分数的乘除法', '百分数的意义与应用',
        '比和比例基础', '应用题解题方法', '图形面积复习', '阶段综合检测'];
    } else {
      const pointOne: string = course.knowledgePoints.length > 0 ? course.knowledgePoints[0] : '核心知识';
      const pointTwo: string = course.knowledgePoints.length > 1 ? course.knowledgePoints[1] : pointOne;
      const pointThree: string = course.knowledgePoints.length > 2 ? course.knowledgePoints[2] : pointTwo;
      titles = [`${pointOne}基础导入`, `${pointOne}方法精讲`, `${pointTwo}核心概念`, `${pointTwo}典型例题`,
        `${pointThree}专项训练`, '易错问题辨析', '综合能力提升', '阶段综合检测'];
    }
    const result: CourseOutlineItem[] = [];
    for (let index: number = 0; index < titles.length; index++) {
      result.push({ sequence: index + 1, title: titles[index], duration: durations[index], playable: index === 0 });
    }
    return result;
  }

  private static highlights(): CourseHighlight[] {
    return [
      { iconText: '本', title: '紧扣教材', description: '同步小学课程重点' },
      { iconText: '精', title: '知识点精讲', description: '核心概念深入剖析' },
      { iconText: '例', title: '典型例题解析', description: '举一反三掌握方法' },
      { iconText: '练', title: '阶段练习巩固', description: '随堂练习及时巩固' }
    ];
  }

  private static services(): CourseServiceItem[] {
    return [
      { iconText: '计', title: '个性化学习计划', description: '结合学情安排学习任务' },
      { iconText: '练', title: '配套练习', description: '知识点专项训练' },
      { iconText: 'AI', title: 'AI在线答疑', description: '学习问题及时解答' },
      { iconText: '错', title: '错题复盘', description: '针对薄弱点反复巩固' },
      { iconText: '录', title: '学习进度记录', description: '持续跟踪课程完成情况' }
    ];
  }

  private static reviews(subject: string): CourseReview[] {
    return [
      { id: 1, nickname: '小宇同学家长', score: 5.0, date: '2026-07-18',
        content: `老师讲解很清楚，例题也很典型，孩子学习${subject}比以前更有思路了。` },
      { id: 2, nickname: '六年级学生', score: 4.8, date: '2026-07-16',
        content: '重点知识讲得很容易理解，配套练习也很有针对性。' }
    ];
  }

  static build(course: Course): CourseDetailData {
    const originalPrice: number = course.level === CourseLevel.FOUNDATION ? 99 :
      course.level === CourseLevel.IMPROVEMENT ? 139 : 199;
    const mainPoint: string = course.knowledgePoints.length > 0 ? course.knowledgePoints.join('、') : '核心知识点';
    return {
      course: course,
      originalPrice: originalPrice,
      enrollmentCount: 1200 + course.id * 37,
      teacher: CourseDetailMockData.teacherFor(course.subject),
      teachingGoal: `帮助学生系统掌握${mainPoint}等重点内容，建立清晰的知识结构。`,
      learningMethod: '课程视频讲解、典型例题分析、配套练习和阶段检测相结合。',
      learningOutcome: `学完后能够理解${course.subject}核心概念，掌握常见题型方法并独立完成阶段训练。`,
      highlights: CourseDetailMockData.highlights(),
      suitableUsers: [`${course.grade}学生`, course.suitableFor, `需要系统巩固${course.subject}知识的学生`, '希望提高解题与应用能力的学生'],
      knowledgeTags: course.knowledgePoints.slice(),
      outline: CourseDetailMockData.outlineFor(course),
      services: CourseDetailMockData.services(),
      rating: 4.9,
      reviewCount: 98,
      reviews: CourseDetailMockData.reviews(course.subject)
    };
  }
}
