# API 说明

成功响应保持 `code=0`，并包含 `message`、`data`、`requestId`。受保护接口使用 Bearer JWT。

| 模块 | 接口 |
|---|---|
| 健康 | `GET /api/health`、`GET /api/ai/health` |
| 首页 | `GET /api/home?student_profile_id={id}` |
| AI | `POST /api/ai/chat`、`POST /api/ai/chat/stream` |
| 会话 | `GET /api/ai/sessions/{sessionId}/messages`、`DELETE /api/ai/sessions/{sessionId}` |
| RAG | `POST /api/ai/rag/rebuild`（开发环境、家长账号） |
| 兼容对话 | `POST /api/chat`、`POST /api/chat/stream`、`GET/DELETE /api/chat/history/{sessionId}` |
| 课程 | `GET /api/courses`、`GET /api/courses/my`、`GET /api/courses/{id}`、`POST /api/courses/recommend` |
| 订单 | `GET/POST /api/orders`、`GET /api/orders/{id}`、`POST /api/orders/{id}/pay` |
| 试卷 | `GET /api/papers`、`GET /api/papers/{id}`、`GET /api/papers/{id}/questions`、`POST /api/papers/{id}/attempts` |
| 学习记录 | `GET /api/students/{id}/wrong-questions`、`PUT /api/students/{id}/wrong-questions/{wrongId}/mastered`、`GET /api/students/{id}/learning-report` |

AI 请求同时接受 camelCase 与旧 snake_case：

```json
{
  "sessionId": null,
  "studentProfileId": 1,
  "clientMessageId": "由客户端生成且重试时保持不变",
  "message": "孩子六年级数学82分，应用题较弱，请推荐课程"
}
```

响应包含 `sessionId`、`intent`、`confidence`、`answer`、`missingFields`、`toolCalls`、`cards`、`sources`、`fallbackUsed` 和 `requestId`。

SSE 事件顺序：`meta → intent → tool_start/tool_result → source → delta → done`；失败事件为 `error`。同一会话内相同 `clientMessageId` 会复用结果，避免普通请求降级时重复创建订单或学习计划。
