# 智学规划助手 SmartStudyAssistant

智学规划助手是一套面向中小学生与家长的个性化学习应用，由 HarmonyOS NEXT 客户端、FastAPI 后端、MySQL 数据库和 AI Agent 组成。系统围绕学生档案、课程资源、试卷练习、错题复测、学习计划和学习报告建立数据闭环，并通过 DeepSeek 或本地 Mock Provider 提供可解释的智能问答与学习建议。

当前演示数据以小学五、六年级数学和英语为主，适合课程设计、软件实训和项目答辩。

## 系统架构

```text
学生 / 家长
    │
    ▼
HarmonyOS NEXT 客户端（ArkTS + ArkUI）
    │  HTTP/JSON + JWT / SSE
    ▼
FastAPI API 与学习业务服务
    ├── AI Agent ── DeepSeek / Mock Provider
    ├── RAG、会话记忆与业务工具
    └── SQLAlchemy Async
             │
             ▼
           MySQL

可信鸿蒙设备之间：
distributedDataObject + UIAbility.onContinue
```

客户端不会直接访问数据库。AI Agent 通过后端业务工具读取真实档案、课程、试卷、错题和报告数据，大模型主要负责意图理解和结果表达。

## 已实现功能

### 学习业务

- 账号注册、登录、JWT 会话恢复及退出登录。
- 学生与家长角色、家庭关系、学生绑定码和数据访问控制。
- 学生档案维护：年级、学科、近期成绩、薄弱知识点、学习目标和每周学习时长。
- 首页学习概览、课程与试卷推荐、热门资源、今日任务及统一搜索。
- 基于成绩层次和薄弱知识点的课程分层推荐。
- 课程详情、报名状态、我的课程、课程进度与收藏。
- 试卷资源、试卷详情、在线答题、自动评分和练习结果。
- AI 数学组卷、生成试卷列表与试卷删除。
- 错题自动沉淀、原题复测、掌握状态更新和专项复习。
- 今日、本周及已完成学习任务管理。
- 周学习报告：课程、试卷、正确率、任务完成率、薄弱点与进步点。

### AI 学习顾问

- 普通对话与 SSE 流式回答，首段流式失败时可降级到普通接口。
- 多轮会话、历史恢复、新会话、清空历史与客户端重试。
- 13 类意图识别和实体提取，信息不足时主动追问。
- 8 个显式业务工具：学生档案、课程推荐、课程搜索、试卷搜索、学习计划、学习报告、错题分析和订单。
- 课程、试卷、学习计划和订单结构化卡片。
- 中文字符 n-gram TF-IDF RAG、来源展示、工具调用日志和推荐记录。
- 相同 `clientMessageId` 的请求幂等，避免流式降级造成重复业务操作。
- DeepSeek 与 Mock Provider 统一封装；未配置模型密钥时可按配置降级。
- AI 学习计划根据最新学科档案、成绩、薄弱点和学习时长生成 7 天预览，不写入学习任务表。
- 学习计划卡片提供“添加到我的学习计划”演示按钮，当前只更新本地状态，不修改数据库。

### HarmonyOS 端能力

- HarmonyOS NEXT API 24、ArkTS、ArkUI。
- 统一使用 `Navigation + NavPathStack + PageMap` 管理页面跳转。
- `NetworkKit` HTTP 通信、JWT 认证和 SSE 增量解析。
- `CoreSpeechKit` 语音识别与 TTS 朗读；系统能力不可用时可调用后端语音识别降级。
- `CoreVisionKit` OCR 服务封装已经保留，但目前尚未接入正式业务页面。
- 后端不可用时，部分非关键展示页面可回退到集中式演示数据。

### HarmonyOS 原生分布式能力

- 使用 `distributedDataObject` 在可信设备之间同步学习页面、任务 ID、任务状态、日期和筛选条件。
- 使用 `UIAbility.onContinue` 接续学习计划页面。
- 设置页提供“跨设备学习接续（实验）”开关，仅在用户主动开启时申请 `DISTRIBUTED_DATASYNC` 权限。
- 分布式会话按应用账号生成稳定 ID，同步载荷不包含 JWT、成绩、答案或 AI 对话。
- 任务状态先由 FastAPI 保存到 MySQL，接收设备收到通知后重新请求后端，MySQL始终是最终事实来源。
- 模拟器或设备不支持时会明确提示并自动回退，不影响其他功能。

## 数据闭环

```text
学生档案
   ↓
成绩分层 + 薄弱点匹配
   ↓
课程 / 试卷推荐
   ↓
学习计划与在线练习
   ↓
自动评分与错题沉淀
   ↓
错题复测与学习报告
   └────────→ 更新后续学习建议
```

## 核心技术栈

| 层级 | 技术 | 作用 |
| --- | --- | --- |
| 鸿蒙客户端 | HarmonyOS NEXT API 24、ArkTS、ArkUI | 页面、交互与设备能力 |
| 页面路由 | Navigation、NavPathStack | 页面跳转与返回栈 |
| 网络通信 | NetworkKit、HTTP、SSE | API 调用与流式回答 |
| 端侧能力 | CoreSpeechKit、CoreVisionKit | 语音、朗读与 OCR 服务封装 |
| 原生分布式 | distributedDataObject、UIAbility.onContinue | 跨设备状态同步与应用接续 |
| 后端 | Python、FastAPI、Pydantic v2 | API、参数校验和业务编排 |
| 数据访问 | SQLAlchemy 2.x Async、Alembic | 异步持久化与数据库迁移 |
| 数据库 | MySQL 8.x | 账号、资源与学习过程数据 |
| AI Agent | DeepSeek、工具调用、会话记忆 | 意图理解与结构化回答 |
| RAG 与安全 | TF-IDF、JWT、PBKDF2-SHA256 | 知识检索、认证与密码保护 |

## 项目结构

```text
SmartStudyAssistant/
├── entry/                         HarmonyOS NEXT 客户端
│   └── src/
│       ├── main/ets/
│       │   ├── ai/                语音与 OCR 服务
│       │   ├── common/            配置、路由与 AppStorage 键
│       │   ├── components/        首页、个人中心和聊天组件
│       │   ├── data/              集中式演示数据
│       │   ├── model/             ArkTS 类型模型
│       │   ├── pages/             页面与统一 PageMap
│       │   ├── service/           HTTP、会话、业务与分布式服务
│       │   └── viewModel/         页面状态和 AI 对话编排
│       ├── test/                  本地单元测试
│       └── ohosTest/              HarmonyOS 设备测试
├── server/                        FastAPI 后端
│   ├── api/                       已挂载的 HTTP Router
│   ├── ai/                        Provider、意图、记忆、RAG 与编排器
│   ├── tools/                     AI 业务工具
│   ├── models/                    SQLAlchemy 实体
│   ├── services/                  学习、账号和资源业务服务
│   ├── alembic/                   数据库迁移
│   ├── knowledge/                 RAG 本地知识资料
│   └── tests/                     隔离数据库自动化测试
└── docs/                          接口、设计、测试与答辩文档
```

## 快速开始

### 环境要求

- DevEco Studio 6.1.1
- HarmonyOS SDK API 24
- Python 3.11 或兼容版本
- MySQL 8.x
- Windows PowerShell（本文命令示例）

### 1. 初始化 MySQL

```powershell
Get-Content server\sql\mysql_init.sql |
  & 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe' -u root -p
```

建议使用只拥有 `smartstudy` 数据库权限的独立账号，不要让应用直接使用 MySQL 管理员账号。

### 2. 配置并启动后端

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
Copy-Item server\.env.example server\.env
```

编辑被 Git 忽略的 `server/.env`：

```dotenv
SMARTSTUDY_DATABASE_URL=mysql+asyncmy://smartstudy:your-password@127.0.0.1:3306/smartstudy?charset=utf8mb4
SMARTSTUDY_JWT_SECRET=replace-with-a-long-random-secret
SMARTSTUDY_AI_PROVIDER=deepseek
SMARTSTUDY_AI_ENABLED=true
SMARTSTUDY_AI_MOCK_FALLBACK=true
SMARTSTUDY_DEEPSEEK_API_KEY=
```

不要提交真实数据库密码、JWT Secret 或模型密钥。

执行迁移并启动服务：

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

检查服务：

- Swagger：`http://127.0.0.1:8000/docs`
- 服务健康：`http://127.0.0.1:8000/api/health`
- AI 健康：`http://127.0.0.1:8000/api/ai/health`

端口被占用并出现 Windows `10048` 时，说明已有进程正在监听 8000 端口，不要重复启动第二个服务。

### 3. 配置并运行 HarmonyOS 客户端

1. 使用 DevEco Studio 打开项目根目录。
2. 查看开发电脑的局域网 IPv4 地址。
3. 修改 `entry/src/main/ets/common/AppConfig.ets` 中的 `API_BASE_URL`，保留结尾的 `/api`。
4. 确保设备与电脑网络互通，并允许防火墙访问 8000 端口。
5. 配置签名后选择模拟器或真机运行 `entry` 模块。

设备中的 `127.0.0.1` 指向设备自身，不能用于访问电脑上运行的 FastAPI。

命令行构建：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  assembleHap --mode module -p module=entry@default -p product=default `
  -p buildMode=debug --no-daemon
```

## 分布式能力验收

跨设备学习接续默认关闭。登录后进入“我的 → 设置 → 跨设备学习接续（实验）”主动开启。

双设备验收需要：

1. 两台可信 HarmonyOS 设备安装相同签名的应用。
2. 两端登录同一智学账号并开启实验开关。
3. A 端完成学习任务后，B 端应收到变更并刷新后端任务数据。
4. 通过系统应用接续入口迁移应用，目标设备应恢复学习计划页、日期和筛选条件。

单设备或不支持分布式能力的模拟器只能验证权限声明、能力检测和降级提示。

## 测试

后端测试使用隔离的 SQLite 数据库和 Mock AI Provider，不连接开发 MySQL，也不消耗真实模型额度：

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

HarmonyOS 主模块和设备测试模块可分别构建：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  assembleHap --mode module -p module=entry@default -p product=default `
  -p buildMode=debug --no-daemon
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  assembleHap --mode module -p module=entry@ohosTest -p product=default `
  -p buildMode=debug --no-daemon
```

当前代码已经通过 API 24 主 HAP 和 ohosTest HAP 编译。后端完整测试仍有部分旧测试与当前接口契约不一致，合并前应以实际测试输出为准，不在 README 中宣称全部通过。

## 当前边界

- AI 生成的七天学习计划是预览，不自动写入 `study_tasks`。
- “添加到我的学习计划”是答辩演示按钮，当前不调用接口。
- `orders_api.py` 已实现，但尚未挂载到正式 API Router；客户端订单页面存在演示数据降级。
- OCR 服务已经封装，尚未接入正式页面流程。
- 原生分布式能力需要可信设备、相同签名和系统能力支持，单模拟器无法展示双设备效果。
- 当前构建配置未包含可发布签名，命令行生成的是 unsigned HAP。

## 文档

- [后端说明](server/README.md)
- [AI 运行说明](server/README_AI.md)
- [接口说明](docs/API.md)
- [AI 架构设计](docs/AI_DESIGN.md)
- [分布式学习接续设计](docs/DISTRIBUTED_DESIGN.md)
- [开发日志](docs/DEVELOPMENT_LOG.md)
- [测试记录](docs/TEST_REPORT.md)
- [提示词设计](docs/PROMPTS.md)
- [踩坑复盘](docs/PITFALLS.md)
- [答辩 PPT 素材](docs/PPT_OUTLINE.md)
