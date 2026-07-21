import { Course, CourseLevel, Paper, StudentProfile, StudyTask, TaskStatus } from '../model/DomainModels';
import { ChatMessage, ChatRole } from '../model/AiModels';
import { RecommendedPaper } from '../model/StudyPlanModels';

export class MockDataService {
  private static tasks: StudyTask[] = MockDataService.createPlanTasks();
  private static studentProfile: StudentProfile = {
    id: 1,
    name: '小明',
    grade: '六年级',
    subject: '数学',
    recentScore: 75,
    weakPoints: ['应用题', '百分数'],
    learningGoal: '提高成绩',
    weeklyStudyMinutes: 180,
    bindCode: 'STU-6A8K'
  };

  private static isoDate(offset: number): string {
    const value = new Date(Date.now() + offset * 24 * 60 * 60 * 1000);
    const month: string = `${value.getMonth() + 1}`.padStart(2, '0');
    const day: string = `${value.getDate()}`.padStart(2, '0');
    return `${value.getFullYear()}-${month}-${day}`;
  }

  private static createPlanTasks(): StudyTask[] {
    return [
      { id: 1, studentProfileId: 1, targetId: 8, name: '六年级数学中等提升课', taskType: '课程', subject: '数学', difficulty: '中等',
        status: TaskStatus.IN_PROGRESS, scheduledDate: MockDataService.isoDate(0), durationMinutes: 40,
        knowledgePoint: '应用题', sourceSessionId: '', createdAt: MockDataService.isoDate(-2) },
      { id: 2, studentProfileId: 1, targetId: 15, name: '六年级数学中等提升型训练卷1', taskType: '试卷', subject: '数学', difficulty: '中等',
        status: TaskStatus.NOT_STARTED, scheduledDate: MockDataService.isoDate(0), durationMinutes: 40,
        knowledgePoint: '百分数', sourceSessionId: '', createdAt: MockDataService.isoDate(-2) },
      { id: 3, studentProfileId: 1, targetId: 20, name: '六年级英语阅读专项训练卷', taskType: '试卷', subject: '英语', difficulty: '基础',
        status: TaskStatus.COMPLETED, scheduledDate: MockDataService.isoDate(-1), durationMinutes: 30,
        knowledgePoint: '阅读', sourceSessionId: '', createdAt: MockDataService.isoDate(-3) },
      { id: 4, studentProfileId: 1, targetId: 8, name: '数学错题复盘与方法总结', taskType: '课程', subject: '数学', difficulty: '中等',
        status: TaskStatus.NOT_STARTED, scheduledDate: MockDataService.isoDate(1), durationMinutes: 35,
        knowledgePoint: '错题复盘', sourceSessionId: '', createdAt: MockDataService.isoDate(-1) },
      { id: 5, studentProfileId: 1, targetId: 16, name: '应用题综合能力检测卷', taskType: '试卷', subject: '数学', difficulty: '中等',
        status: TaskStatus.NOT_STARTED, scheduledDate: MockDataService.isoDate(2), durationMinutes: 45,
        knowledgePoint: '应用题', sourceSessionId: '', createdAt: MockDataService.isoDate(-1) },
      { id: 6, studentProfileId: 1, targetId: 10, name: '英语词汇与阅读巩固课', taskType: '课程', subject: '英语', difficulty: '基础',
        status: TaskStatus.NOT_STARTED, scheduledDate: MockDataService.isoDate(3), durationMinutes: 30,
        knowledgePoint: '词汇', sourceSessionId: '', createdAt: MockDataService.isoDate(-1) },
      { id: 7, studentProfileId: 1, targetId: 3, name: '一般过去时错题复测', taskType: '错题', subject: '英语', difficulty: '错题巩固',
        status: TaskStatus.COMPLETED, scheduledDate: MockDataService.isoDate(-1), durationMinutes: 15,
        knowledgePoint: '一般过去时', sourceSessionId: '', createdAt: MockDataService.isoDate(-3) }
    ];
  }

  static getStudentProfile(): StudentProfile {
    return {
      id: MockDataService.studentProfile.id,
      name: MockDataService.studentProfile.name,
      grade: MockDataService.studentProfile.grade,
      subject: MockDataService.studentProfile.subject,
      recentScore: MockDataService.studentProfile.recentScore,
      weakPoints: MockDataService.studentProfile.weakPoints.slice(),
      learningGoal: MockDataService.studentProfile.learningGoal,
      weeklyStudyMinutes: MockDataService.studentProfile.weeklyStudyMinutes,
      bindCode: MockDataService.studentProfile.bindCode
    };
  }

  static saveStudentProfile(profile: StudentProfile): StudentProfile {
    MockDataService.studentProfile = {
      id: profile.id > 0 ? profile.id : 1,
      name: profile.name,
      grade: profile.grade,
      subject: profile.subject,
      recentScore: profile.recentScore,
      weakPoints: profile.weakPoints.slice(),
      learningGoal: profile.learningGoal,
      weeklyStudyMinutes: profile.weeklyStudyMinutes,
      bindCode: profile.bindCode || MockDataService.studentProfile.bindCode
    };
    return MockDataService.getStudentProfile();
  }

  private static knowledgePoints(grade: string, subject: string): string[] {
    const lowerGrade: boolean = grade === '一年级' || grade === '二年级';
    const middleGrade: boolean = grade === '三年级' || grade === '四年级';
    if (subject === '语文') {
      if (lowerGrade) return ['拼音', '识字写字', '看图写话'];
      if (middleGrade) return ['字词基础', '阅读理解', '习作'];
      return ['阅读理解', '古诗文', '作文'];
    }
    if (subject === '数学') {
      if (lowerGrade) return ['口算', '加减法', '应用题'];
      if (middleGrade) return ['乘除法', '小数', '图形面积'];
      return ['分数', '百分数', '应用题'];
    }
    if (lowerGrade) return ['字母', '自然拼读', '基础词汇'];
    if (middleGrade) return ['词汇', '句型', '听力'];
    return ['词汇', '语法', '阅读理解'];
  }

  private static catalogPairs(): string[][] {
    const legacyPairs: string[][] = [
      ['五年级', '数学'], ['五年级', '英语'], ['六年级', '数学'], ['六年级', '英语']
    ];
    const grades: string[] = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];
    const subjects: string[] = ['语文', '数学', '英语'];
    const result: string[][] = legacyPairs.slice();
    for (let gradeIndex: number = 0; gradeIndex < grades.length; gradeIndex++) {
      for (let subjectIndex: number = 0; subjectIndex < subjects.length; subjectIndex++) {
        const exists: boolean = legacyPairs.some((pair: string[]) =>
          pair[0] === grades[gradeIndex] && pair[1] === subjects[subjectIndex]);
        if (!exists) result.push([grades[gradeIndex], subjects[subjectIndex]]);
      }
    }
    return result;
  }

  static getCourses(): Course[] {
    const pairs: string[][] = MockDataService.catalogPairs();
    const levels: string[] = [CourseLevel.FOUNDATION, CourseLevel.IMPROVEMENT, CourseLevel.EXTENSION];
    const result: Course[] = [];
    let id: number = 1;
    for (let pairIndex: number = 0; pairIndex < pairs.length; pairIndex++) {
      const grade: string = pairs[pairIndex][0];
      const subject: string = pairs[pairIndex][1];
      for (let levelIndex: number = 0; levelIndex < levels.length; levelIndex++) {
        const level: string = levels[levelIndex];
        result.push({
          id: id,
          name: `${grade}${subject}${level.replace('型', '')}课`,
          grade: grade,
          subject: subject,
          level: level,
          difficulty: levelIndex === 0 ? '基础' : levelIndex === 1 ? '中等' : '较难',
          suitableFor: levelIndex === 0 ? '基础知识需要巩固的学生' : levelIndex === 1 ? '希望稳定提高成绩的学生' : '成绩优秀且希望拓展的学生',
          knowledgePoints: MockDataService.knowledgePoints(grade, subject),
          description: `围绕${grade}${subject}核心知识点设计的${level}课程，包含讲解、例题与阶段练习。`,
          price: levelIndex === 0 ? 69 : levelIndex === 1 ? 99 : 139,
          totalLessons: 12 + levelIndex * 4
        });
        id++;
      }
    }
    return result;
  }

  static getPapers(): Paper[] {
    const courses: Course[] = MockDataService.getCourses();
    const result: Paper[] = [];
    let id: number = 1;
    for (let index: number = 0; index < courses.length; index++) {
      const course: Course = courses[index];
      for (let setIndex: number = 1; setIndex <= 2; setIndex++) {
        result.push({
          id: id,
          name: `${course.grade}${course.subject}${course.level}训练卷${setIndex}`,
          grade: course.grade,
          subject: course.subject,
          difficulty: course.difficulty,
          knowledgePoints: course.knowledgePoints,
          questionCount: setIndex === 1 ? 20 : 25,
          suitableCourseLevel: course.level,
          ocrText: ''
        });
        id++;
      }
    }
    return result;
  }

  static getCourse(id: number): Course {
    const courses: Course[] = MockDataService.getCourses();
    for (let index: number = 0; index < courses.length; index++) {
      if (courses[index].id === id) {
        return courses[index];
      }
    }
    return courses[0];
  }

  static getPaper(id: number): Paper {
    const papers: Paper[] = MockDataService.getPapers();
    for (let index: number = 0; index < papers.length; index++) {
      if (papers[index].id === id) {
        return papers[index];
      }
    }
    return papers[0];
  }

  static getTasks(): StudyTask[] {
    return MockDataService.tasks.slice();
  }

  static addTask(name: string, taskType: string, subject: string, difficulty: string, targetId: number = 1): StudyTask {
    const task: StudyTask = {
      id: Date.now(),
      studentProfileId: 1,
      targetId: targetId,
      name: name,
      taskType: taskType,
      subject: subject,
      difficulty: difficulty,
      status: TaskStatus.NOT_STARTED,
      scheduledDate: MockDataService.isoDate(1),
      durationMinutes: taskType === '错题' ? 15 : 40,
      knowledgePoint: taskType === '试卷' ? '专项训练' : taskType === '错题' ? '错题复测' : '课程学习',
      sourceSessionId: '',
      createdAt: MockDataService.isoDate(0)
    };
    MockDataService.tasks.push(task);
    return task;
  }

  static updateTaskStatus(id: number, status: string): void {
    for (let index: number = 0; index < MockDataService.tasks.length; index++) {
      if (MockDataService.tasks[index].id === id) {
        MockDataService.tasks[index].status = status;
      }
    }
  }

  static removeTask(id: number): void {
    MockDataService.tasks = MockDataService.tasks.filter((task: StudyTask) => task.id !== id);
  }

  static getRecommendedPapers(): RecommendedPaper[] {
    const papers: Paper[] = MockDataService.getPapers();
    const ids: number[] = [14, 17, 18];
    const reasons: string[] = [
      '针对薄弱知识点应用题进行专项巩固',
      '补充分数与百分数综合训练',
      '用于本周末阶段检测和错题复盘'
    ];
    const result: RecommendedPaper[] = [];
    for (let index: number = 0; index < ids.length; index++) {
      const exists: boolean = MockDataService.tasks.some((task: StudyTask) =>
        task.taskType === '试卷' && task.targetId === ids[index]);
      if (exists) continue;
      const paper: Paper = papers[ids[index] - 1];
      result.push({
        id: paper.id, name: paper.name, grade: paper.grade, subject: paper.subject,
        difficulty: paper.difficulty, knowledgePoints: paper.knowledgePoints,
        questionCount: paper.questionCount, recommendReason: reasons[index]
      });
    }
    return result;
  }

  static welcomeMessages(): ChatMessage[] {
    return [{
      id: 'welcome',
      revision: 0,
      role: ChatRole.ASSISTANT,
      content: '您好！我是您的 AI 学习顾问小智，很高兴为您和孩子提供学习帮助。\n\n您可以告诉我孩子的年级、科目、最近成绩、薄弱知识点或学习目标。',
      createdAt: Date.now(),
      createTime: '现在',
      isStreaming: false,
      fallbackUsed: false,
      intent: '',
      cards: [],
      sources: [],
      errorMessage: '',
      clientMessageId: '',
      retryQuestion: ''
    }];
  }
}
