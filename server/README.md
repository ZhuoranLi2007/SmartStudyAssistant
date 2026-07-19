# FastAPI 后端

后端采用 Router → Service → Repository/SQLAlchemy → AI Orchestrator → Tool Registry 的分层思路。运行环境默认使用MySQL 8.x，自动化测试使用独立SQLite数据库。默认 `AI_PROVIDER=mock`，模拟模型只负责把结构化工具结果组织成自然语言，不替代规则和数据库查询。

主要目录：

```text
api/        HTTP接口
ai/         意图、字段提取、模型适配与编排
tools/      统一工具注册和调用日志
services/   权限、推荐规则和种子数据
models/     SQLAlchemy实体
schemas/    Pydantic请求模型
database/   异步数据库会话
tests/      API与规则测试
```

测试：

```powershell
.\.venv\Scripts\python.exe -m pytest server\tests -q
```

MySQL启动：

```powershell
Copy-Item server\.env.example server\.env
# 在 server/.env 中填写数据库密码
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn server.main:app --reload
```

不要把真实数据库密码写入 `.env.example` 或提交到Git。测试配置会在导入后端模块前覆盖数据库地址，避免测试中的 `drop_all()` 操作影响MySQL。

安全约束：密码使用带随机盐的PBKDF2-SHA256；受保护接口使用24小时JWT；家庭与学生资源访问均执行服务端授权检查；真实密钥只能写入未提交的 `server/.env`。
