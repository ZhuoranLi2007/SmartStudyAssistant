import re

INTENTS = {
    "COURSE_RECOMMENDATION", "PAPER_RECOMMENDATION", "STUDENT_ANALYSIS",
    "COURSE_QUERY", "STUDY_PLAN", "GENERAL_CHAT",
}


def classify_intent(message: str) -> str:
    if any(word in message for word in ("报什么", "推荐课程", "基础班", "提升班", "拔高班", "选课")):
        return "COURSE_RECOMMENDATION"
    if any(word in message for word in ("试卷", "卷子", "练习题")):
        return "PAPER_RECOMMENDATION"
    if any(word in message for word in ("学情", "分析成绩", "薄弱")):
        return "STUDENT_ANALYSIS"
    if any(word in message for word in ("有哪些课程", "查询课程", "课程列表")):
        return "COURSE_QUERY"
    if any(word in message for word in ("学习计划", "安排学习", "加入计划")):
        return "STUDY_PLAN"
    return "GENERAL_CHAT"


def extract_fields(message: str, context: dict) -> dict:
    result = dict(context)
    if "五年级" in message:
        result["grade"] = "五年级"
    elif "六年级" in message:
        result["grade"] = "六年级"
    if "数学" in message:
        result["subject"] = "数学"
    elif "英语" in message:
        result["subject"] = "英语"
    score_match = re.search(r"(?<!\d)(\d{1,3})(?:分|左右)?", message)
    if score_match and 0 <= int(score_match.group(1)) <= 100:
        result["score"] = int(score_match.group(1))
    known_points = ["应用题", "百分数", "计算", "几何", "词汇", "语法", "阅读", "听力"]
    points = [point for point in known_points if point in message]
    if points:
        result["weak_points"] = points
    for goal in ("巩固基础", "提高成绩", "冲刺重点学校", "竞赛", "拓展学习"):
        if goal in message:
            result["learning_goal"] = goal
            break
    return result
