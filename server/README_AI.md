# AI 全链路运行说明

## 安全准备

不要使用曾经发到聊天、截图或提交记录中的 API Key。先在 DeepSeek 控制台撤销旧 Key，再生成新 Key。真实 Key 只能写入被 Git 忽略的 `server/.env` 或当前终端环境变量。

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
```

没有 Key 时服务仍可启动，并在允许兜底时使用 Mock Provider。`fallbackUsed=true` 表示本次没有使用真实模型。

## 启动

```powershell
python -m pip install -r server\requirements.txt
python -m alembic upgrade head
python -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

检查：

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/health
Invoke-RestMethod http://127.0.0.1:8000/api/ai/health
```

## AI 处理链

```text
JWT 与学生权限校验
→ 会话历史与结构化摘要
→ 规则优先的意图和实体提取
→ 缺失字段追问
→ 八个显式业务工具
→ 中文字符 n-gram TF-IDF RAG
→ DeepSeek/Mock Provider
→ 结构化卡片与来源
→ 消息、推荐、请求和工具日志持久化
```

AI 不写入原始思维链。课程 ID、试卷 ID、订单 ID、价格、成绩和状态只来自数据库及工具结果。订单工具只创建 `PENDING` 订单，不执行自动支付。

## RAG

知识库来源包括课程、试卷和 `server/knowledge` 下的 Markdown/JSON 文件。开发环境中，家长账号可调用：

```text
POST /api/ai/rag/rebuild
```

重建按来源 ID 和内容哈希去重。空知识库不会中断普通问答。

## 自动化测试

```powershell
python -m pytest -q
```

测试强制使用 SQLite 和 Mock Provider，不读取真实 AI Key，也不会产生模型费用。真实模型只在人工配置轮换后的 Key 后进行一次小范围冒烟测试。

## 鸿蒙端

`AppConfig.API_BASE_URL` 必须填写电脑在手机或模拟器可访问的局域网地址，不能写设备自身的 `localhost`。SSE 默认由 `ENABLE_SSE=false` 关闭；普通接口稳定后可改为 `true`。流式连接若在首个有效响应前失败，会携带相同 `clientMessageId` 自动降级到普通接口。
