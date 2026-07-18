# API说明

统一响应包含 `code`、`message`、`data` 和 `requestId`。受保护接口使用 Bearer JWT。

| 模块 | 接口 |
|---|---|
| 认证 | `POST /api/auth/register`、`POST /api/auth/login`、`GET /api/auth/me` |
| 家庭 | `POST /api/families`、`GET /api/families/current`、`POST /api/families/bind-student` |
| 学生 | `POST /api/students`、`GET/PUT /api/students/{id}` |
| 课程 | `GET /api/courses`、`GET /api/courses/{id}`、`POST /api/courses/recommend` |
| 试卷 | `GET /api/papers`、`GET /api/papers/{id}`、`POST /api/papers/analyze` |
| 计划 | `GET/POST /api/study-plans`、`PUT /api/study-plans/{id}/status`、`DELETE /api/study-plans/{id}` |
| 对话 | `POST /api/chat`、`POST /api/chat/stream`、`GET/DELETE /api/chat/history/{sessionId}` |

课程推荐请求：

```json
{"student_profile_id": 1, "subject": "数学"}
```

AI对话请求：

```json
{"session_id": null, "student_profile_id": 1, "message": "孩子六年级数学75分，应该报什么课？"}
```
