import { Course } from './DomainModels';

export interface CourseTeacher {
  name: string;
  tag: string;
  descriptionLines: string[];
  avatarKey: string;
}

export interface CourseHighlight {
  iconText: string;
  title: string;
  description: string;
}

export interface CourseOutlineItem {
  sequence: number;
  title: string;
  duration: string;
  playable: boolean;
}

export interface CourseServiceItem {
  iconText: string;
  title: string;
  description: string;
}

export interface CourseReview {
  id: number;
  nickname: string;
  score: number;
  date: string;
  content: string;
}

export interface CourseDetailData {
  course: Course;
  originalPrice: number;
  enrollmentCount: number;
  teacher: CourseTeacher;
  teachingGoal: string;
  learningMethod: string;
  learningOutcome: string;
  highlights: CourseHighlight[];
  suitableUsers: string[];
  knowledgeTags: string[];
  outline: CourseOutlineItem[];
  services: CourseServiceItem[];
  rating: number;
  reviewCount: number;
  reviews: CourseReview[];
}
