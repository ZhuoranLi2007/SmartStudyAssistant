# API 说明

## 公共约定

成功响应保持现有兼容结构：

```json
{
  "code": 0,
  "message": "success",
  "data": {},
  "requestId": "uuid"
}
```

受保护接口使用：

```http
Authorization: Bearer <JWT>
```

JWT 中的用户身份是授权依据。客户端传入的用户或学生标识仍需经过家庭、角色和资源归属校验。

## 接口目录

| 模块 | 方法与路径 |
|---|---|
| 健康 | `GET /api/health`、`GET /api/ai/health` |
| 认证 | `POST /api/auth/register`、`POST /api/auth/login`、`GET /api/auth/me` |
| 家庭 | `POST /api/families`、`GET /api/families/current`、`POST /api/families/bind-student` |
| 首页 | `GET /api/home?student_profile_id={id}` |
| 学生 | `POST /api/students`、`GET /api/students/{id}`、`PUT /api/students/{id}` |
| 课程 | `GET /api/courses`、`GET /api/courses/my`、`GET /api/courses/{id}`、`POST /api/courses/recommend` |
| 试卷 | `GET /api/papers`、`GET /api/papers/{id}`、`POST /api/papers/analyze` |
| 练习 | `GET /api/papers/{id}/questions`、`POST /api/papers/{id}/attempts` |
| 学习计划 | `GET/POST /api/study-plans`、`PUT /api/study-plans/{id}/status`、`DELETE /api/study-plans/{id}` |
| 订单 | `GET/POST /api/orders`、`GET /api/orders/{id}`、`POST /api/orders/{id}/pay` |
| 学习记录 | `GET /api/students/{id}/wrong-questions`、`PUT /api/students/{id}/wrong-questions/{wrongId}/mastered`、`GET /api/students/{id}/learning-report` |
| AI | `POST /api/ai/chat`、`POST /api/ai/chat/stream` |
| AI 会话 | `GET /api/ai/sessions/{sessionId}/messages`、`DELETE /api/ai/sessions/{sessionId}` |
| RAG | `POST /api/ai/rag/rebuild`（开发环境、已登录家长） |
| 兼容 AI | `POST /api/chat`、`POST /api/chat/stream`、`GET/DELETE /api/chat/history/{sessionId}` |

## AI 请求

接口同时接受 camelCase 和旧版 snake_case 字段：

```json
{
  "sessionId": null,
  "studentProfileId": 1,
  "clientMessageId": "client_1720000000000_001",
  "message": "孩子六年级数学82分，应用题较弱，请推荐课程"
}
```

`clientMessageId` 由客户端生成，同一次发送、SSE 降级和人工重试必须保持不变。

主要响应字段：

| 字段 | 含义 |
|---|---|
| `sessionId` | 当前多轮会话 ID |
| `intent` / `confidence` | 意图和置信度 |
| `answer` | AI 最终文本 |
| `missingFields` | 个性化业务仍缺少的字段 |
| `clarificationQuestion` | 下一步追问 |
| `toolCalls` | 已执行工具与结构化结果 |
| `cards` | 课程、试卷、计划或订单卡片 |
| `sources` | RAG 来源与相似度 |
| `fallbackUsed` | 是否使用 Mock Provider |
| `requestId` | 服务端请求追踪 ID |

### 卡片类型

- `COURSE`：课程 ID、年级、学科、等级、难度、价格、课时、知识点和推荐理由。
- `PAPER`：试卷 ID、年级、学科、难度、题量和知识点。
- `STUDY_PLAN`：任务日期、类型、时长、知识点和目标资源 ID。
- `ORDER`：订单 ID、订单号、金额和状态。

客户端只根据卡片类型和真实 ID 使用本地路由白名单，不执行服务端传入的任意页面路径。

## SSE

事件顺序：

```text
meta
→ intent
→ tool_start / tool_result
→ source
→ delta（可多次）
→ done
```

失败事件为 `error`。鸿蒙端按 `\n\n` 缓冲完整事件：首个 `delta` 前失败可使用相同 `clientMessageId` 降级普通接口；已收到内容后中断则保留部分回复，不自动重复业务操作。

## 常见错误

- `401`：未登录、JWT 无效或过期。
- `403`：角色、家庭或学生资源不属于当前用户。
- `404`：资源或路由不存在；若新增接口始终 404，应确认启动的是当前项目和最新代码。
- `409`：重复用户名、手机号、绑定或幂等冲突。
- `422`：请求字段校验失败。
- `503`：AI 被禁用且不允许 Mock 兜底，或必要外部服务不可用。
