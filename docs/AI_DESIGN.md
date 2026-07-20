# AI、工具、RAG 与记忆设计

## 设计目标

AI 学习顾问不是直接把用户问题交给大模型，而是将身份校验、意图识别、业务工具、规则推荐、知识检索和自然语言解释串成可测试、可追踪的完整链路。

```text
HarmonyOS AI 助手
→ JWT 与学生数据权限
→ 会话历史与结构化摘要
→ 意图识别和实体提取
→ 信息不足时澄清
→ 业务工具调用
→ RAG 检索
→ DeepSeek/Mock Provider
→ 事实校验与结构化卡片
→ 消息、请求和工具日志持久化
```

## 意图体系

系统支持 13 类意图：

- `COURSE_RECOMMENDATION`：课程推荐
- `COURSE_SEARCH`：课程搜索
- `PAPER_SEARCH`：试卷搜索
- `STUDY_PLAN_GENERATION`：学习计划
- `LEARNING_ANALYSIS`：学情分析
- `KNOWLEDGE_QA`：知识问答
- `LEARNING_REPORT`：学习报告
- `WRONG_QUESTION_ANALYSIS`：错题分析
- `ORDER_CREATION`：创建待支付订单
- `MY_COURSES`：查询我的课程
- `MY_ORDERS`：查询我的订单
- `GENERAL_CHAT`：普通教育咨询
- `UNKNOWN`：无法可靠判断的请求

规则优先识别清晰请求；置信度不足时再使用 Provider 的 JSON 模式分类。空 JSON、非法 JSON 或越界意图会回退到规则结果。

## 业务工具

`ToolRegistry` 统一注册八个工具：

1. 学生档案工具
2. 课程推荐工具
3. 课程搜索工具
4. 试卷搜索工具
5. 七天学习计划工具
6. 学习报告工具
7. 错题分析工具
8. 订单工具

工具只能通过服务层访问数据库。课程 ID、试卷 ID、订单 ID、价格、分数、状态和统计数据始终以数据库或工具结果为准，模型不能覆盖这些事实。订单工具仅在检测到明确确认语句后创建 `PENDING` 订单，不自动支付。

## 课程分层规则

- 成绩低于 70 分：基础巩固型。
- 70–89 分：中等提升型。
- 90 分及以上：拔高拓展型。
- 薄弱知识点达到 3 项及以上：推荐等级下调一级。
- 学习目标为“巩固基础”：最高推荐基础巩固型。
- 竞赛或拓展目标：仅当成绩不低于 90 且薄弱点不超过 1 项时允许拔高。
- 每周学习时间影响任务数量和学习强度，不直接改变课程等级。

命中规则、修正原因、课程、试卷和解释会保存到推荐记录，便于答辩展示推荐依据。

## RAG

RAG 使用中文字符 2–4 gram TF-IDF 与余弦相似度，默认返回 Top 4。数据来源包括：

- 数据库中的课程介绍与知识点。
- 数据库中的试卷信息与知识点。
- `server/knowledge` 下的 Markdown/JSON 教育资料。

`rag_documents` 和 `rag_chunks` 保存来源、正文、元数据与哈希，按来源 ID 和内容哈希去重。TF-IDF 矩阵在进程内按需重建；知识库为空时返回空 `sources`，不会中断普通问答。

## 会话与幂等

- `chat_sessions` 和 `chat_messages` 保存完整历史。
- 模型上下文只传结构化摘要和最近 20 条消息，避免上下文无限增长。
- 会话按 JWT 用户与学生档案双重隔离。
- HarmonyOS 端只将最近 `sessionId` 写入 Preferences，不把完整对话放进 AppStorage。
- 相同 `clientMessageId` 会复用已有 AI 请求结果，避免 SSE 失败降级时重复创建订单或学习计划。

未绑定学生时，普通教育咨询可以使用无持久化安全兜底；课程推荐、计划、报告等依赖学生数据的能力会要求先创建或绑定学生档案。

## Provider 与安全

DeepSeek 和 Mock 实现统一 Provider 接口，支持普通响应、SSE、JSON 响应、超时、认证、限流和空响应映射。缺少 Key 或真实服务不可用时，是否回退 Mock 由 `SMARTSTUDY_AI_MOCK_FALLBACK` 控制。

安全原则：

- API Key 只放在被 Git 忽略的 `server/.env` 或进程环境变量。
- 不记录 Authorization、Key、数据库密码和完整用户正文。
- 不保存或展示原始思维链。
- 模型只负责意图补充和自然语言解释，不能直接执行任意路由或写数据库。

## HarmonyOS AI 助手

前端采用 `AiAssistantPage → ChatViewModel → AiService`：

- `ChatMessage` 自身保存流式状态、错误、cards、sources、intent 和 `fallbackUsed`。
- SSE 事件按 `meta → intent → tool_start/tool_result → source → delta → done` 处理，所有 delta 更新同一个 AI 气泡。
- 首个 delta 前失败时使用相同消息 ID 请求普通接口；已经收到 delta 后中断时保留部分文本并显示重试。
- 轻量 Markdown 仅解析标题、段落、列表、分隔线和粗体，不引入 WebView 或第三方 Markdown 包。
- 课程、试卷、学习计划和订单使用专用结构化卡片，并通过本地路由白名单跳转。
- 语音输入和 TTS 复用单例服务；页面离开时停止录音和播报。
