# 智学规划助手 SmartStudyAssistant

智学规划助手是一款面向中小学生及家长的 HarmonyOS NEXT 教育应用。系统根据学生年级、学科成绩、薄弱知识点、学习目标和每周学习时间，提供课程分层推荐、专项试卷、学习计划、在线练习与学习报告，并通过 AI 学习顾问解释推荐依据。

当前演示范围以小学五、六年级的数学和英语为主，课程分为基础巩固型、中等提升型和拔高拓展型。

## 当前功能

### HarmonyOS 前端

- HarmonyOS NEXT API 24、ArkTS、ArkUI，使用唯一的 `Navigation + NavPathStack + PageMap`。
- 首页采用教育平台布局，包含欢迎信息、Swiper 轮播、快捷入口、学习概览、AI 推荐、热门课程、最新课程、推荐试卷和今日任务。
- 登录注册、学生档案、课程与试卷详情、在线答题、学习计划、订单详情等业务页面。
- “我的”模块包含我的课程、我的订单、收藏、错题本、学习报告、客服、反馈、设置和家庭学生信息。
- AI 学习顾问支持多轮会话、历史恢复、SSE 流式回复、快捷问题、轻量 Markdown、课程/试卷/计划/订单卡片、RAG 来源、重试、语音输入和 TTS 朗读。
- `CoreSpeechKit` 语音识别/TTS、`PhotoViewPicker` 与 `CoreVisionKit` OCR；设备不支持时提供明确降级提示。
- 后端不可用时，首页和个人中心的非关键展示数据可降级为集中式 Mock，避免白屏和无限加载。

### FastAPI 后端

- FastAPI、Pydantic v2、SQLAlchemy 2.x、Alembic、MySQL 8.x、JWT 与 PBKDF2-SHA256 密码哈希。
- 家长/学生独立账号、家庭数据隔离、学生档案绑定码与学习任务同步。
- 13 类意图、8 个显式业务工具、可解释课程分层规则、多轮记忆、RAG、结构化卡片和工具调用日志。
- DeepSeek 与 Mock Provider 使用统一接口；未配置密钥时可按配置安全降级。
- 课程、试卷、订单、报名、练习、错题、学习报告和 AI 会话接口。
- 开发数据使用 MySQL；自动化测试强制使用隔离的 SQLite 和 Mock Provider，不消耗真实模型额度。

## 项目结构

```text
MyApplication5/
├── entry/                         HarmonyOS NEXT 前端
│   └── src/main/ets/
│       ├── ai/                    语音与 OCR 服务
│       ├── common/                配置、路由和全局键
│       ├── components/            home/profile/chat 等组件
│       ├── data/                  集中式演示数据
│       ├── model/                 ArkTS 明确类型模型
│       ├── pages/                 页面与统一 PageMap
│       ├── service/               HTTP、会话及业务服务
│       └── viewModel/             页面状态编排
├── server/                        FastAPI 后端
│   ├── api/                       HTTP Router
│   ├── ai/                        Provider、意图、记忆、RAG 与编排
│   ├── tools/                     业务工具注册表
│   ├── models/                    SQLAlchemy 实体
│   ├── services/                  业务服务
│   ├── alembic/                   增量迁移
│   ├── tests/                     自动化测试
│   └── knowledge/                 RAG 本地知识资料
└── docs/                          设计、接口、日志和测试文档
```

## 完整启动

### 1. 配置并启动 MySQL

项目默认使用 MySQL 8.x。首次部署先创建数据库：

```powershell
cd D:\ruanjianshixun\MyApplication5
Get-Content server\sql\mysql_init.sql | & 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe' -u root -p
```

建议创建仅拥有 `smartstudy` 数据库权限的应用账号，不要让应用直接使用 MySQL 管理员账号。

### 2. 配置并启动后端

```powershell
cd D:\ruanjianshixun\MyApplication5
python -m venv --system-site-packages .venv
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
Copy-Item server\.env.example server\.env
```

编辑被 Git 忽略的 `server/.env`，至少设置数据库地址、JWT Secret 和 AI 配置：

```dotenv
SMARTSTUDY_DATABASE_URL=mysql+asyncmy://smartstudy:your-password@127.0.0.1:3306/smartstudy?charset=utf8mb4
SMARTSTUDY_JWT_SECRET=replace-with-a-long-random-secret
SMARTSTUDY_AI_PROVIDER=deepseek
SMARTSTUDY_DEEPSEEK_API_KEY=your-rotated-key
SMARTSTUDY_AI_MOCK_FALLBACK=true
```

不要提交真实数据库密码或模型密钥。曾发送到聊天、截图或公开记录中的 Key 应先撤销，再生成新 Key。

执行迁移并启动：

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

如果项目已有旧 `.venv`，更新代码后仍应重新执行 `pip install -r server/requirements.txt`；否则可能因缺少后续新增的 `openai` 等依赖而在导入阶段失败。

浏览器检查：

- Swagger：`http://127.0.0.1:8000/docs`
- 服务健康：`http://127.0.0.1:8000/api/health`
- AI 健康：`http://127.0.0.1:8000/api/ai/health`

### 3. 配置并启动鸿蒙前端

1. 使用 DevEco Studio 6.1.1 打开项目根目录。
2. 查看电脑当前局域网 IPv4：`ipconfig`。
3. 修改 `entry/src/main/ets/common/AppConfig.ets` 中的 `API_BASE_URL`，例如 `http://192.168.1.10:8000/api`。
4. 保证电脑和模拟器/真机网络互通，并允许防火墙访问 8000 端口。
5. 在 DevEco Studio 选择设备后运行 `entry` 模块。真机安装需要有效签名。

设备中的 `127.0.0.1` 指向设备自身，不能用它访问电脑上的 FastAPI。当前 `ENABLE_SSE=true`，首段流式连接失败时会复用相同 `clientMessageId` 降级到普通接口。

命令行构建：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
```

## 验证

```powershell
cd D:\ruanjianshixun\MyApplication5
.\.venv\Scripts\python.exe -m pytest -q
```

2026-07-20 最近一次验证结果为 `17 passed in 32.87s`、HarmonyOS `BUILD SUCCESSFUL in 5.790s`。语音识别、TTS、OCR、长连接稳定性和签名安装仍应在目标真机上完成最终验收。

## 文档索引

- [后端说明](server/README.md)
- [AI 运行说明](server/README_AI.md)
- [接口说明](docs/API.md)
- [AI 架构设计](docs/AI_DESIGN.md)
- [开发日志](docs/DEVELOPMENT_LOG.md)
- [测试记录](docs/TEST_REPORT.md)
- [提示词设计](docs/PROMPTS.md)
- [踩坑复盘](docs/PITFALLS.md)
- [答辩 PPT 素材](docs/PPT_OUTLINE.md)
