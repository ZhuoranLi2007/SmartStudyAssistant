import json
import re
from typing import Any

from server.ai.intent.intent_types import IntentResult, IntentType
from server.ai.providers import ProviderError, ProviderRouter


INTENT_KEYWORDS: dict[IntentType, tuple[str, ...]] = {
    IntentType.ORDER_CREATION: ("确认报名", "创建订单", "立即报名", "生成订单"),
    IntentType.MY_ORDERS: ("我的订单", "订单状态", "查订单", "待支付订单"),
    IntentType.MY_COURSES: ("我的课程", "已买课程", "已购课程", "在哪里学习"),
    IntentType.COURSE_RECOMMENDATION: ("报什么", "推荐课程", "推荐班", "选课", "基础班", "提高班", "拔高班"),
    IntentType.COURSE_SEARCH: ("找课程", "搜索课程", "有哪些课程", "课程列表", "多少钱的课"),
    IntentType.PAPER_SEARCH: ("试卷", "卷子", "专项练习", "找题", "练习题"),
    IntentType.STUDY_PLAN_GENERATION: ("学习计划", "一周计划", "安排学习", "七天计划"),
    IntentType.LEARNING_REPORT: ("学习报告", "本周报告", "完成率", "正确率"),
    IntentType.WRONG_QUESTION_ANALYSIS: ("错题", "错误分析", "为什么做错", "薄弱题"),
    IntentType.LEARNING_ANALYSIS: ("学情", "分析成绩", "学习情况", "薄弱知识点"),
    IntentType.KNOWLEDGE_QA: ("怎么学", "是什么", "为什么", "知识点", "解题方法"),
}

RESOURCE_INTENT_PATTERNS: dict[IntentType, tuple[str, ...]] = {
    IntentType.COURSE_RECOMMENDATION: (
        r"(?:推荐|介绍|选)(?:给我|一下|一个|一门|一些|几门)?[^，。！？\n]{0,8}(?:课程|课|班)",
        r"(?:课程|课|班)[^，。！？\n]{0,8}(?:推荐|怎么选|选什么)",
    ),
    IntentType.PAPER_SEARCH: (
        r"(?:推荐|找|来)(?:给我|一下|一个|一道|一套|一份|一组|一些|几道|几套|几份|几组)?"
        r"[^，。！？\n]{0,8}(?:习题|练习题|练习|题目|试卷|卷子|专项练习|应用题)",
    ),
}

EXPLICIT_RESOURCE_INTENTS = {
    IntentType.COURSE_RECOMMENDATION,
    IntentType.COURSE_SEARCH,
    IntentType.PAPER_SEARCH,
}

WEAKNESS_MARKERS = ("比较弱", "较弱", "薄弱", "不擅长", "不会", "总出错", "容易错", "掌握不好", "有困难")

REQUIRED_FIELDS: dict[IntentType, tuple[str, ...]] = {
    IntentType.COURSE_RECOMMENDATION: ("grade", "subject", "score", "weakPoints", "learningGoal"),
    IntentType.COURSE_SEARCH: ("grade", "subject"),
    IntentType.PAPER_SEARCH: ("grade", "subject"),
    IntentType.STUDY_PLAN_GENERATION: ("studentId",),
    IntentType.LEARNING_ANALYSIS: ("studentId",),
    IntentType.LEARNING_REPORT: ("studentId",),
    IntentType.WRONG_QUESTION_ANALYSIS: ("studentId",),
    IntentType.ORDER_CREATION: ("studentId", "courseId"),
}

CLARIFICATIONS: dict[str, str] = {
    "studentId": "请先选择或创建要分析的学生档案。",
    "grade": "孩子当前是几年级？",
    "subject": "需要咨询语文、数学还是英语？",
    "score": "最近一次考试成绩大约是多少分？",
    "weakPoints": "主要薄弱知识点是什么？",
    "learningGoal": "学习目标是巩固基础、提高成绩还是竞赛拓展？",
    "courseId": "请先告诉我想报名哪一门课程。",
}


def extract_entities(message: str, context: dict[str, Any] | None = None) -> dict[str, Any]:
    result: dict[str, Any] = dict(context or {})
    grade_match = re.search(r"([一二三四五六七八九]|初[一二三]|高[一二三])年级", message)
    if grade_match:
        value = grade_match.group(0)
        result["grade"] = value.replace("初一年级", "初一").replace("初二年级", "初二").replace("初三年级", "初三")
    if "数学" in message:
        result["subject"] = "数学"
    elif "英语" in message:
        result["subject"] = "英语"
    elif "语文" in message:
        result["subject"] = "语文"
    score_match = re.search(r"(?<!\d)(100|[1-9]?\d)\s*分", message)
    if score_match:
        result["score"] = int(score_match.group(1))
    points = [point for point in ("应用题", "百分数", "计算", "几何", "词汇", "语法", "阅读", "听力", "写作") if point in message]
    if points:
        result["weakPoints"] = points
        result.setdefault("knowledgePoint", points[0])
    for goal in ("巩固基础", "提高成绩", "冲刺重点学校", "竞赛", "拓展学习"):
        if goal in message:
            result["learningGoal"] = goal
            break
    for level in ("基础巩固型", "同步提高型", "中等提升型", "拔高拓展型"):
        if level in message:
            result["courseLevel"] = "中等提升型" if level == "同步提高型" else level
    for prefix, key in (("课程", "courseId"), ("试卷", "paperId")):
        match = re.search(rf"{prefix}(?:ID|id|编号)?\s*[：:#]?\s*(\d+)", message)
        if match:
            result[key] = int(match.group(1))
    price_match = re.search(r"(?:不超过|低于|预算)\s*(\d+(?:\.\d+)?)\s*元", message)
    if price_match:
        result["maxPrice"] = float(price_match.group(1))
    for difficulty in ("基础", "中等", "较难"):
        if difficulty in message:
            result["difficulty"] = difficulty
    for status in ("待支付", "已支付", "已取消"):
        if status in message:
            result["orderStatus"] = {"待支付": "PENDING", "已支付": "PAID", "已取消": "CANCELLED"}[status]
    return result


def classify_by_rules(message: str, context: dict[str, Any] | None = None) -> IntentResult:
    entities = extract_entities(message, context)
    message_weak_points = [point for point in (entities.get("weakPoints") or []) if point in message]
    scores = {intent: sum(1 for word in words if word in message) for intent, words in INTENT_KEYWORDS.items()}
    for resource_intent, patterns in RESOURCE_INTENT_PATTERNS.items():
        scores[resource_intent] += sum(2 for pattern in patterns if re.search(pattern, message))
    intent, hits = max(scores.items(), key=lambda item: item[1], default=(IntentType.GENERAL_CHAT, 0))
    # 单纯陈述“某知识点比较弱”属于学情反馈；只有没有更明确的推荐、试卷等动作时才接管意图。
    if hits == 0 and message_weak_points and any(marker in message for marker in WEAKNESS_MARKERS):
        intent = IntentType.LEARNING_ANALYSIS
        confidence = 0.92
        missing = [field for field in REQUIRED_FIELDS.get(intent, ()) if not entities.get(field)]
        clarification = CLARIFICATIONS.get(missing[0]) if missing else None
        return IntentResult(intent, confidence, entities, missing, clarification)
    if hits == 0:
        intent = IntentType.GENERAL_CHAT if len(message.strip()) >= 2 else IntentType.UNKNOWN
        confidence = 0.45 if intent == IntentType.GENERAL_CHAT else 0.2
    else:
        confidence = min(0.72 + hits * 0.1, 0.98)
    missing = [field for field in REQUIRED_FIELDS.get(intent, ()) if not entities.get(field)]
    clarification = CLARIFICATIONS.get(missing[0]) if missing else None
    return IntentResult(intent, confidence, entities, missing, clarification)


class IntentClassifier:
    def __init__(self, provider: ProviderRouter):
        self.provider = provider

    async def classify(self, message: str, context: dict[str, Any] | None = None) -> IntentResult:
        rule = classify_by_rules(message, context)
        # 本地 Mock 和未配置模型时保留确定性规则；真实 DeepSeek 可用时由模型承担主要意图理解。
        if not self.provider.configured or self.provider.provider.name == "mock":
            return rule
        fallback = json.dumps({"intent": rule.intent.value, "confidence": rule.confidence}, ensure_ascii=False)
        safe_context = {
            key: value for key, value in (context or {}).items()
            if key in {"grade", "subject", "score", "weakPoints", "learningGoal"}
        }
        prompt = (
            "请根据用户本轮消息和学习上下文判断最主要的教育咨询意图，只输出 JSON 对象，"
            "字段为 intent 和 confidence，不要解释。用户陈述某类题较弱通常属于 LEARNING_ANALYSIS；"
            "询问知识概念或解题方法属于 KNOWLEDGE_QA；只有明确要求创建订单才属于 ORDER_CREATION。"
            f"允许的 intent：{','.join(item.value for item in IntentType)}。"
            f"学习上下文：{json.dumps(safe_context, ensure_ascii=False)}。用户消息：{message}"
        )
        try:
            response = await self.provider.complete(
                [{"role": "system", "content": "你是教育意图分类器，必须输出 JSON。"}, {"role": "user", "content": prompt}],
                json_mode=True,
                fallback_content=fallback,
                temperature=0.0,
                max_tokens=300,
            )
        except ProviderError:
            return rule
        try:
            parsed = json.loads(response.content)
            if not isinstance(parsed, dict):
                return rule
            intent = IntentType(str(parsed.get("intent", rule.intent.value)))
            confidence = float(parsed.get("confidence", rule.confidence))
        except (AttributeError, KeyError, ValueError, TypeError, json.JSONDecodeError):
            return rule
        # 用户明确要求课程或练习资源时保留确定性意图，避免模型把可执行推荐降成纯文字聊天。
        if rule.intent in EXPLICIT_RESOURCE_INTENTS and rule.confidence >= 0.82:
            intent = rule.intent
            confidence = rule.confidence
        # 写操作属于安全边界：模型不能把普通咨询提升为创建订单，明确写入词仍以规则结果为准。
        if intent == IntentType.ORDER_CREATION and rule.intent != IntentType.ORDER_CREATION:
            intent = rule.intent
            confidence = rule.confidence
        entities = extract_entities(message, context)
        missing = [field for field in REQUIRED_FIELDS.get(intent, ()) if not entities.get(field)]
        return IntentResult(intent, max(0.0, min(confidence, 1.0)), entities, missing, CLARIFICATIONS.get(missing[0]) if missing else None)
