# 智学规划助手 SmartStudyAssistant

面向小学五、六年级学生及家长的 HarmonyOS NEXT 教育辅助应用。系统依据学生年级、科目成绩、薄弱点、学习目标和学习时间，推荐基础巩固型、中等提升型或拔高拓展型课程，并匹配专项试卷与学习计划。

## 已实现

- HarmonyOS NEXT API 24、ArkTS、ArkUI、统一 Navigation/NavPathStack。
- 登录注册、首页、学生档案、AI助手、课程、试卷、学习计划、个人中心共11个页面。
- 12门课程和24份试卷的演示数据，支持筛选、详情和加入计划。
- FastAPI、SQLAlchemy、MySQL 8.x、Alembic、JWT、PBKDF2密码哈希；自动化测试使用隔离的SQLite数据库。
- 独立家长/学生账号、家庭隔离、一次性学生绑定码、任务状态同步接口。
- 六类意图、规则推荐、工具注册、调用日志、多轮会话和SSE兜底端点。
- CoreSpeechKit语音识别/TTS、PhotoViewPicker与CoreVisionKit OCR，包含能力降级。

## 快速启动

### 后端

```powershell
cd D:\ruanjianshixun\MyApplication5
python -m venv --system-site-packages .venv
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
Copy-Item server\.env.example server\.env
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn server.main:app --reload
```

首次启动前需要在 `server/.env` 中填写本机MySQL应用账号密码。浏览器打开 `http://127.0.0.1:8000/docs`；应用启动后会向MySQL加入12门课程和24份试卷样例。

### 鸿蒙前端

1. 使用 DevEco Studio 6.1.1 打开项目根目录。
2. 在 `entry/src/main/ets/common/AppConfig.ets` 设置后端地址；模拟器/真机通常要填写电脑局域网IP。
3. `USE_MOCK_DATA=true` 可脱离后端演示；改为 `false` 后使用真实FastAPI账号和对话接口。
4. 配置签名后运行到设备。语音和OCR若在模拟器不可用，会显示降级提示。

命令行编译：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
```

## MySQL数据库

项目默认使用MySQL 8.x。首次部署时使用管理员账号创建数据库：

```powershell
Get-Content server\sql\mysql_init.sql | & 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe' -u root -p
```

再创建只拥有 `smartstudy` 数据库权限的应用账号，并在未提交的 `server/.env` 中配置：

```text
SMARTSTUDY_DATABASE_URL=mysql+asyncmy://smartstudy:your-password@127.0.0.1:3306/smartstudy?charset=utf8mb4
```

当前开发机已完成MySQL 8.0.45迁移、种子数据和注册登录接口冒烟测试。pytest会强制使用 `server/test_smartstudy.db`，不会清空MySQL开发数据。

## 文档

- [后端说明](server/README.md)
- [接口说明](docs/API.md)
- [AI设计](docs/AI_DESIGN.md)
- [测试记录](docs/TEST_REPORT.md)
- [开发日志](docs/DEVELOPMENT_LOG.md)
- [提示词记录](docs/PROMPTS.md)
- [踩坑复盘](docs/PITFALLS.md)
- [PPT素材](docs/PPT_OUTLINE.md)
