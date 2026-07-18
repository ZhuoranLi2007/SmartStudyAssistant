# FastAPI 后端

后端采用 Router → Service → Repository/SQLAlchemy → AI Orchestrator → Tool Registry 的分层思路。默认 `AI_PROVIDER=mock`，模拟模型只负责把结构化工具结果组织成自然语言，不替代规则和数据库查询。

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

安全约束：密码使用带随机盐的PBKDF2-SHA256；受保护接口使用24小时JWT；家庭与学生资源访问均执行服务端授权检查；真实密钥只能写入未提交的 `server/.env`。
