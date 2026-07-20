# FastAPI 后端说明

后端采用 Router → Service/SQLAlchemy → AI Orchestrator → Tool Registry → RAG/Provider 的分层结构。开发运行使用 MySQL 8.x，自动化测试使用隔离 SQLite。

## 目录

```text
server/
├── api/             HTTP 路由
├── ai/              Provider、意图、记忆、RAG 与编排
├── tools/           业务工具与注册表
├── services/        认证、推荐、订单、练习等业务服务
├── models/          SQLAlchemy 实体
├── schemas/         Pydantic 请求与响应模型
├── database/        异步数据库会话
├── alembic/         0001/0002 增量迁移
├── knowledge/       RAG Markdown/JSON 资料
├── tests/           API、规则和 AI 全链路测试
├── .env.example     无密钥配置模板
└── main.py          FastAPI 入口
```

## 环境配置

```powershell
cd D:\ruanjianshixun\MyApplication5
python -m venv --system-site-packages .venv
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
Copy-Item server\.env.example server\.env
```

在 `server/.env` 中填写本机数据库账号、JWT Secret 和可选的 DeepSeek Key。不要把真实密码或 Key 写入 `.env.example` 或提交到 Git。

## 数据库与启动

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

启动后访问：

- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/api/health`
- `http://127.0.0.1:8000/api/ai/health`

应用会安全补充课程、试卷、题目和知识资料种子数据，不覆盖已有用户业务数据。

## 测试

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

测试配置会在导入应用前强制覆盖为 SQLite + Mock Provider，不会清理 MySQL 开发数据，也不会调用真实 DeepSeek。最近一次完整结果为 17 项通过。

## 安全约束

- 密码使用随机盐 PBKDF2-SHA256 哈希。
- 受保护接口使用默认 24 小时 JWT。
- 家庭、学生、会话、任务和学习记录均执行服务端授权检查。
- AI 日志只记录 requestId、sessionId、意图、工具、耗时、Provider 和错误码等必要信息。
- 模型不能覆盖数据库返回的 ID、价格、成绩和状态。
- 真实密钥只允许位于未提交的 `server/.env` 或进程环境变量。

完整接口和 AI 说明参见 [API 文档](../docs/API.md) 与 [AI 运行说明](README_AI.md)。
