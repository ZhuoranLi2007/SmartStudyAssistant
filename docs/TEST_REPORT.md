# 测试记录（2026-07-19）

- `python -m pytest -q`：15项全部通过。
- 覆盖 59/60/69/70/89/90 分边界、薄弱点降级和基础目标限制。
- 覆盖注册、学生档案、家庭隔离、首页聚合、过期学生档案ID降级、课程推荐、结构化 AI 响应、RAG 重建、订单确认保护、请求幂等、真实试题提交与学习报告聚合。
- 自动化测试强制 SQLite + Mock Provider，未读取或消耗真实 DeepSeek Key。
- MySQL Alembic 已升级至 `0002_ai_full_stack (head)`。
- MySQL 原有目录保持 12 门课程和 24 份试卷，新增 120 道题目、38条 RAG 文档/分块。
- `/api/health`、`/api/home`、`/api/ai/health` 与 `/api/ai/chat` 路由冒烟成功；无 Key 时后端可正常启动。
- HarmonyOS API 24 `assembleHap` 构建成功；新增 AI、SSE、卡片、订单详情与答题联调代码无 ArkTS 编译错误。

待真机验收：语音识别、TTS、OCR、SSE 长连接稳定性和签名安装。当前工程仍提示未配置签名，这是既有环境项，不影响 HAP 编译。
