import { AppConfig } from '../common/AppConfig';
import { StudentProfile } from '../model/DomainModels';
import { MockDataService } from './MockDataService';
import { HttpClient } from './HttpClient';

interface StudentSubjectItem {
  subject: string;
  recentScore: number;
  weakPoints: string[];
}

interface StudentProfileResponse {
  id: number;
  name: string;
  grade: string;
  learningGoal: string;
  weeklyStudyMinutes: number;
  bindCode: string | null;
  subjects: StudentSubjectItem[];
}

class StudentSaveRequest {
  name: string = '';
  grade: string = '六年级';
  subject: string = '数学';
  recent_score: number = 0;
  weak_points: string[] = [];
  learning_goal: string = '';
  weekly_study_minutes: number = 180;
}

export class StudentService {
  private static convert(data: StudentProfileResponse): StudentProfile {
    const subject: StudentSubjectItem = data.subjects.length > 0 ? data.subjects[0] : {
      subject: '', recentScore: 0, weakPoints: []
    };
    return {
      id: data.id,
      name: data.name,
      grade: data.grade,
      subject: subject.subject,
      recentScore: subject.recentScore,
      weakPoints: subject.weakPoints,
      learningGoal: data.learningGoal,
      weeklyStudyMinutes: data.weeklyStudyMinutes,
      bindCode: data.bindCode || ''
    };
  }

  static async getProfile(studentProfileId: number): Promise<StudentProfile> {
    if (AppConfig.USE_MOCK_DATA) return MockDataService.getStudentProfile();
    const data: StudentProfileResponse =
      (await HttpClient.get<StudentProfileResponse>(`/students/${studentProfileId}`)).data;
    return StudentService.convert(data);
  }

  static async saveProfile(profile: StudentProfile): Promise<StudentProfile> {
    if (AppConfig.USE_MOCK_DATA) {
      profile.id = profile.id > 0 ? profile.id : 1;
      return profile;
    }
    const request: StudentSaveRequest = new StudentSaveRequest();
    request.name = profile.name;
    request.grade = profile.grade;
    request.subject = profile.subject;
    request.recent_score = profile.recentScore;
    request.weak_points = profile.weakPoints;
    request.learning_goal = profile.learningGoal;
    request.weekly_study_minutes = profile.weeklyStudyMinutes;
    const data: StudentProfileResponse = profile.id > 0
      ? (await HttpClient.put<StudentProfileResponse>(`/students/${profile.id}`, request)).data
      : (await HttpClient.post<StudentProfileResponse>('/students', request)).data;
    return StudentService.convert(data);
  }
}
