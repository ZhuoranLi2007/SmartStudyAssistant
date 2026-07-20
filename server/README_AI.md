# AI 全链路运行说明

## 安全准备

不要使用曾经发到聊天、截图或提交记录中的 API Key。应先在 DeepSeek 控制台撤销旧 Key，再生成新 Key。真实 Key 只能写入被 Git 忽略的 `server/.env` 或当前进程环境变量。

```powershell
Copy-Item server\.env.example server\.env
```

编辑 `server/.env`：

```dotenv
SMARTSTUDY_AI_PROVIDER=deepseek
SMARTSTUDY_DEEPSEEK_API_KEY=替换为轮换后的新Key
SMARTSTUDY_DEEPSEEK_BASE_URL=https://api.deepseek.com
SMARTSTUDY_DEEPSEEK_MODEL=deepseek-v4-flash
SMARTSTUDY_AI_ENABLED=true
SMARTSTUDY_AI_MOCK_FALLBACK=true
SMARTSTUDY_AI_REQUEST_TIMEOUT=30
SMARTSTUDY_AI_MAX_HISTORY_MESSAGES=20
SMARTSTUDY_RAG_TOP_K=4
```

没有 Key 时服务仍可启动。允许兜底时使用 Mock Provider，并在响应中返回 `fallbackUsed=true`。

## 启动与检查

```powershell
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/health
Invoke-RestMethod http://127.0.0.1:8000/api/ai/health
```

`/api/ai/health` 用于确认 AI 是否启用、当前 Provider、模型和是否允许 Mock 兜底，不返回密钥。

## AI 处理链

```text
JWT 与学生权限校验
→ 会话历史与结构化摘要
→ 规则优先的意图和实体提取
→ 缺失字段追问
→ 八个显式业务工具
→ 中文字符 n-gram TF-IDF RAG
→ DeepSeek/Mock Provider
→ 事实校验、结构化卡片与来源
→ 消息、推荐、AI 请求和工具日志持久化
```

AI 不保存原始思维链。课程 ID、试卷 ID、订单 ID、价格、成绩和状态只来自数据库或工具结果。订单工具仅创建 `PENDING` 订单，不执行自动支付。

## RAG

知识库来源包括课程、试卷和 `server/knowledge` 下的 Markdown/JSON。开发环境中，已登录家长可以调用：

```text
POST /api/ai/rag/rebuild
```

重建按来源 ID 和内容哈希去重。空知识库只会返回空 `sources`，不会中断普通问答。

## SSE 与幂等

SSE 端点：

```text
POST /api/ai/chat/stream
```

事件顺序为 `meta → intent → tool_start/tool_result → source → delta → done`，异常事件为 `error`。相同 `clientMessageId` 会复用结果，保证首段流式连接失败后降级普通接口不会重复创建订单或计划。

HarmonyOS 前端当前 `ENABLE_SSE=true`。如果设备网络或系统 HTTP 流式能力不稳定，可临时改为 `false` 使用普通接口；切换只影响传输方式，不改变后端编排与响应结构。

## 鸿蒙端 AI 顾问

- `AiService` 负责普通请求、SSE 解析、会话历史和清空接口。
- `ChatViewModel` 负责历史恢复、发送、降级、重试、新会话与 Preferences 持久化。
- cards、sources、错误和流式状态绑定具体消息。
- 前端仅渲染轻量 Markdown 白名单，不执行 HTML 或任意服务端路由。
- 课程、试卷、计划和订单卡片使用真实 ID 进入本地白名单页面。
- 页面退出时停止录音和 TTS。

`AppConfig.API_BASE_URL` 必须填写电脑在设备可访问的局域网地址，不能使用设备自己的 `localhost`。

## 自动化测试

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

测试强制 SQLite + Mock Provider，不读取真实 AI Key。真实模型仅在人工配置轮换后的新 Key 后进行小范围冒烟测试。

## 常见问题

- `/api/ai/chat` 返回 404：检查是否从项目根目录启动 `server.main:app`，并查看 `/docs` 是否包含 `/api/ai/*`。
- AI 健康正常但设备无法连接：检查电脑 IP、8000 端口、防火墙和 `API_BASE_URL`。
- `fallbackUsed=true`：当前请求使用了 Mock，检查 Provider、Key、网络和 `SMARTSTUDY_AI_MOCK_FALLBACK`。
- SSE 中断：首段失败会自动降级；已收到内容后中断不会自动重复提交，可在页面点击重试。
