# 测试记录（2026-07-20）

## 自动化测试

- 命令：`python -m pytest -q`
- 最近结果：`17 passed in 32.87s`
- 测试环境强制使用隔离的 SQLite 数据库与 Mock Provider，不读取真实 DeepSeek Key，不产生模型费用，也不会清理开发 MySQL 数据。

主要覆盖：

- 注册登录、JWT、学生档案、家庭隔离与越权访问。
- 首页聚合和已失效学生档案 ID 的安全降级。
- 课程推荐 59/60/69/70/89/90 分边界、薄弱点降级、基础目标限制和竞赛目标约束。
- 13 类意图、缺字段追问、8 个工具、结构化 cards/sources 与 RAG 重建。
- 订单明确确认保护、请求幂等和重复提交防护。
- 真实试题读取、练习提交、错题生成及学习报告聚合。
- AI 卡片字段来自数据库且 ID 有效。
- 未绑定学生时普通教育咨询可用，个性化请求返回建档引导。
- 普通响应与 SSE 响应的数据结构兼容。

## 数据库验证

- MySQL Alembic 版本：`0002_ai_full_stack (head)`。
- 迁移保留原有 12 门课程和 24 份试卷。
- 种子数据包含课程价格与课时、试卷题目和 RAG 基础资料。
- 自动化测试不直接对 MySQL 执行 `drop_all()`。

## API 冒烟

已验证的关键路由包括：

- `GET /api/health`
- `GET /api/home`
- `GET /api/ai/health`
- `POST /api/ai/chat`
- 认证、课程、试卷、学习计划、家庭、订单和练习相关接口

服务缺少真实模型 Key 时仍能启动；允许兜底时 AI 响应返回 `fallbackUsed=true`。

## HarmonyOS 构建

构建命令：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
```

最近结果：`BUILD SUCCESSFUL in 5.790s`。首页、个人中心、AI 消息组件、SSE、卡片路由、订单详情和在线答题代码均通过 ArkTS 编译。构建提示未配置 `signingConfigs`，不影响 HAP 编译，但真机安装前必须补充有效签名。

验证过程中还确认：旧 `.venv` 若未重新安装 `server/requirements.txt`，会因缺少 `openai` 在测试收集阶段失败；使用依赖完整的环境后测试全部通过。

## 已完成的手工检查

- 四个主入口：首页、AI 助手、学习计划、我的。
- 首页轮播、课程/试卷详情与在线答题入口。
- 个人中心各子页面、订单筛选、收藏取消、FAQ、设置弹窗和退出确认。
- AI 快捷问题、Markdown、消息级卡片、来源折叠、新会话、清空和错误重试。
- 后端关闭时首页/个人中心 Mock 降级，AI 页面保留用户消息并显示可重试错误。

## 待真机验收

- CoreSpeechKit 语音识别与 TTS。
- CoreVisionKit OCR 与图片选择授权。
- SSE 长连接在真实网络切换下的稳定性。
- 签名、安装、后台切换和不同屏幕尺寸适配。
- 轮换后的真实 DeepSeek Key 小范围冒烟测试。
