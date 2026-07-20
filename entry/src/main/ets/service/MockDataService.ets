import { Course, CourseLevel, Paper, StudentProfile, StudyTask, TaskStatus } from '../model/DomainModels';
import { ChatMessage, ChatRole } from '../model/AiModels';

export class MockDataService {
  private static tasks: StudyTask[] = [
    { id: 1, name: '六年级数学应用题提升', taskType: '课程', subject: '数学', difficulty: '中等', createDate: '2026-07-17', status: TaskStatus.IN_PROGRESS },
    { id: 2, name: '英语阅读理解专项卷', taskType: '试卷', subject: '英语', difficulty: '中等', createDate: '2026-07-17', status: TaskStatus.NOT_STARTED }
  ];

  static getStudentProfile(): StudentProfile {
    return {
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
  }

  static getCourses(): Course[] {
    const grades: string[] = ['五年级', '六年级'];
    const subjects: string[] = ['数学', '英语'];
    const levels: string[] = [CourseLevel.FOUNDATION, CourseLevel.IMPROVEMENT, CourseLevel.EXTENSION];
    const result: Course[] = [];
    let id: number = 1;
    for (let gradeIndex: number = 0; gradeIndex < grades.length; gradeIndex++) {
      for (let subjectIndex: number = 0; subjectIndex < subjects.length; subjectIndex++) {
        for (let levelIndex: number = 0; levelIndex < levels.length; levelIndex++) {
          const subject: string = subjects[subjectIndex];
          const level: string = levels[levelIndex];
          result.push({
            id: id,
            name: `${grades[gradeIndex]}${subject}${level.replace('型', '')}课`,
            grade: grades[gradeIndex],
            subject: subject,
            level: level,
            difficulty: levelIndex === 0 ? '基础' : levelIndex === 1 ? '中等' : '较难',
            suitableFor: levelIndex === 0 ? '基础知识需要巩固的学生' : levelIndex === 1 ? '希望稳定提高成绩的学生' : '成绩优秀且希望拓展的学生',
            knowledgePoints: subject === '数学' ? ['计算', '应用题', '几何'] : ['词汇', '语法', '阅读'],
            description: `围绕${subject}核心知识点设计的${level}课程，包含讲解、例题与阶段练习。`
          });
          id++;
        }
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
    return MockDataService.tasks;
  }

  static addTask(name: string, taskType: string, subject: string, difficulty: string): void {
    MockDataService.tasks.push({
      id: Date.now(),
      name: name,
      taskType: taskType,
      subject: subject,
      difficulty: difficulty,
      createDate: '2026-07-17',
      status: TaskStatus.NOT_STARTED
    });
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

  static welcomeMessages(): ChatMessage[] {
    return [{
      id: 'welcome',
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
