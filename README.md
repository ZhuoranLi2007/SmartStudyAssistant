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

代码按客户端页面/状态/服务/模型和后端 API/Service/AI Tool/数据访问分层，具体约定见[代码分层与注释规范](docs/CODE_STRUCTURE.md)。

## 已实现功能

### 学习业务

- 账号注册、登录、JWT 会话恢复及退出登录。
- 学生与家长角色、家庭关系、学生绑定码和数据访问控制。
- 学生档案维护：年级、学科、近期成绩、薄弱知识点、学习目标和每周学习时长。
- 首页提供账号问候、课程/试卷搜索、四类学习入口和“开启今日学习”快捷入口。
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
- DeepSeek 负责主要意图理解、只读工具选择和自然语言回答，规则分类仅用于安全拦截与模型异常降级。
- 业务工具覆盖学生档案、课程推荐与搜索、试卷搜索、学习计划、学习报告、错题分析和知识检索。
- 课程、试卷和学习计划结构化卡片；写操作必须经过服务端二次确认守卫。
- 中文字符 n-gram TF-IDF RAG、年级/学科/知识点元数据过滤、来源展示和工具调用日志。
- 相同 `clientMessageId` 的请求幂等，避免流式降级造成重复业务操作。
- DeepSeek 与 Mock Provider 统一封装；未配置模型密钥时可按配置降级。
- AI 学习计划根据最新学科档案、成绩、薄弱点和学习时长生成 7 天预览，不写入学习任务表。
- 学习计划卡片提供“添加到我的学习计划”演示按钮，当前只更新本地状态，不修改数据库。

### HarmonyOS 端能力

- HarmonyOS NEXT、ArkTS、ArkUI；目标 API 24，最低兼容 API 23。
- 统一使用 `Navigation + NavPathStack + PageMap` 管理页面跳转。
- `NetworkKit` HTTP 通信、JWT 认证和 SSE 增量解析。
- `CoreSpeechKit` 语音识别与 TTS 朗读；系统能力不可用时可调用后端语音识别降级。
- `CoreVisionKit` OCR 服务封装已经保留，但目前尚未接入正式业务页面。
- 后端不可用时，部分非关键展示页面可回退到集中式演示数据。

### HarmonyOS 原生分布式能力

- 使用 `distributedDataObject` 发布轻量业务变更事件，覆盖档案、课程、试卷、错题、学习计划、报告和 AI 会话等页面。
- 接收设备通过统一刷新协调器重新请求 FastAPI/MySQL；支持500ms防抖、忙碌补刷新、失败重试和多事件顺序发送。
- 使用 `UIAbility.onContinue` 接续白名单业务页面及安全页面上下文。
- 设置页提供“跨设备学习接续（实验）”开关，仅在用户主动开启时申请 `DISTRIBUTED_DATASYNC` 权限。
- 分布式会话按应用账号生成稳定 ID，同步载荷不包含 JWT、成绩详情、答案、AI 正文或输入草稿。
- 所有业务变化先由 FastAPI 保存到 MySQL，再发布失效事件；MySQL始终是最终事实来源。
- 设置页显示授权、等待设备、已连接、异常状态以及最近一次收到的同步事件。
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
| 鸿蒙客户端 | HarmonyOS NEXT、ArkTS、ArkUI（目标 API 24，最低 API 23） | 页面、交互与设备能力 |
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
- HarmonyOS SDK API 24（构建产物最低兼容 API 23）
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

## HarmonyOS 真机调试与后端联调

本项目已使用 HarmonyOS 真机完成无线 HDC 连接、签名 HAP 安装和客户端运行。真机只运行 HarmonyOS 客户端，FastAPI、MySQL 和 AI 服务仍运行在开发电脑上：

```text
HarmonyOS 手机
    │  同一 Wi-Fi 下的 HTTP 请求
    ▼
开发电脑上的 FastAPI
    ├── MySQL
    └── DeepSeek / Mock Provider
```

手机与电脑需要连接同一个 Wi-Fi。无线 HDC 地址用于调试连接，客户端 `API_BASE_URL` 使用的是电脑 IPv4，两者不能混用。

### 1. 找到并启用 HDC 命令

如果 PowerShell 提示“无法将 `hdc` 识别为 cmdlet、函数、脚本文件或可运行程序”，说明 HDC 所在目录没有加入 Windows Path。本机 DevEco Studio 的 HDC 路径为：

```text
C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe
```

可以直接使用完整路径：

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe' list targets
```

也可以只为当前 PowerShell 临时添加 Path：

```powershell
$env:Path += ';C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains'
hdc -v
hdc list targets
```

关闭终端后临时 Path 会失效。长期使用时可将 `toolchains` 目录加入 Windows 用户环境变量 Path。

### 2. 区分文件传输与 HDC 调试

手机开启开发人员模式、USB 调试和文件传输后，Windows 资源管理器能够看到手机，但 `hdc list targets` 仍可能显示：

```text
[Empty]
```

这是因为 MTP 文件传输和 HDC 调试是两个不同的 USB 接口。电脑能够传输文件，只能说明数据线和 MTP 基本正常，不能证明 HDC 通道已经建立。

### 3. 检查并修复 HDC Interface 驱动

使用 PowerShell 查看相关设备：

```powershell
Get-PnpDevice -PresentOnly |
  Where-Object {
    $_.FriendlyName -match 'HDC|NDIS|Harmony|Huawei|ADB'
  } |
  Format-Table Status, Class, FriendlyName, InstanceId -AutoSize
```

本次调试曾出现 `Error  HDC Interface`，说明 Windows 已发现 HDC 接口，但驱动异常。处理步骤如下：

1. 打开 Windows“设备管理器”。
2. 选择“查看 → 显示隐藏的设备”。
3. 找到带黄色感叹号的 `HDC Interface`。
4. 右键选择“更新驱动程序”。
5. 选择“浏览我的电脑以查找驱动程序”。
6. 选择“让我从计算机上的可用驱动程序列表中选取”。
7. 硬件类型选择“通用串行总线设备”。
8. 制造商和型号均选择“WinUSB 设备”。
9. 确认安装，并重新插拔设备。

不要为 HDC Interface 选择 Belkin USB 轻松传送电缆、USB 轻松传送电缆或 MTP 便携设备驱动。修复后可再次检查：

```powershell
Get-PnpDevice -PresentOnly |
  Where-Object { $_.FriendlyName -match 'HDC' } |
  Format-Table Status, Class, FriendlyName, InstanceId -AutoSize
```

正常状态应类似：

```text
OK  USBDevice  HDC Interface
```

### 4. 重启 HDC 服务并判断 USB 结果

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'

& $hdc -v
& $hdc checkserver
& $hdc kill
& $hdc start -r
& $hdc list targets -v
```

本次客户端和服务端版本均为 `Ver: 3.2.0d`。如果列表中只有 `COM3 UART Ready`、`COM4 UART Ready` 等内容，它们是电脑串口，不是 HarmonyOS 手机；真正的 USB 调试设备类型应显示为 USB。

本次 USB HDC 通道最终没有稳定建立，因此改用无线调试完成真机连接。

### 5. 通过无线 HDC 连接真机

1. 确保手机和电脑连接同一个 Wi-Fi。
2. 在手机开发者选项中开启“无线调试”。
3. 记录页面显示的 IP 地址和端口。
4. 在 PowerShell 中连接该地址：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'

& $hdc start -r
& $hdc tconn 10.130.39.188:33537
& $hdc list targets -v
```

`10.130.39.188:33537` 是本次真机调试的实际示例，使用时必须替换为手机无线调试页面当前显示的地址。连接成功会返回：

```text
Connect OK
10.130.39.188:33537  TCP  Connected  localhost  hdc
```

其中 `TCP` 表示无线连接，`Connected` 表示连接成功；设备名显示 `localhost` 属于手机返回信息，不是错误。此时可以在 DevEco Studio 右上角设备列表中选择对应 IP。

### 6. 配置真机调试签名

真机运行 HAP 需要调试签名。在 DevEco Studio 中进入：

```text
File → Project Structure → Signing Configs
```

为 `default` 产品配置自动签名，然后选择 `entry` 模块和已连接的真机，点击 Run 或按 `Shift + F10`。DevEco Studio 会完成编译、签名、安装和启动。

仓库中的 `build-profile.json5` 保持 `"signingConfigs": []` 是正常且安全的：证书、Profile、密钥库、本机绝对路径和密码都不应提交到 GitHub。

如果命令行签名提示 `Algorithm HmacPBESHA256 not available`，说明默认 Java 版本过旧。可在当前 PowerShell 临时使用 DevEco Studio 自带 JBR：

```powershell
$env:JAVA_HOME='C:\Program Files\Huawei\DevEco Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
```

重新构建前仍需在本机配置有效签名材料，不要把签名配置提交到仓库。

### 7. 启动电脑端后端服务

真机能显示登录页，只说明客户端已经安装。登录、课程、试卷、学生档案、学习计划、AI 助手、语音降级和 AI 组卷仍依赖电脑上的 MySQL 与 FastAPI。

启动 MySQL 后，在项目根目录执行：

```powershell
.\.venv\Scripts\python.exe -m uvicorn server.main:app `
  --host 0.0.0.0 --port 8000 --reload
```

必须使用 `--host 0.0.0.0`，否则 FastAPI 只能被电脑本机访问。

### 8. 配置客户端后端地址

执行 `ipconfig`，找到电脑当前 Wi-Fi 对应的 IPv4 地址，然后修改：

```text
entry/src/main/ets/common/AppConfig.ets
```

示例：

```typescript
export class AppConfig {
  static readonly API_BASE_URL: string =
    'http://电脑当前IPv4:8000/api';

  static readonly USE_MOCK_DATA: boolean = false;
  static readonly ENABLE_SSE: boolean = true;
  static readonly REQUEST_TIMEOUT_MS: number = 10000;
}
```

注意：

- 这里填写电脑 IPv4，不是手机的无线调试 IP。
- 地址必须保留 `/api`。
- 修改后需要重新 Run，将新客户端安装到真机。
- 更换 Wi-Fi 后电脑 IPv4 可能变化，需要重新检查。

### 9. 检查真机能否访问后端

先在电脑浏览器访问：

```text
http://127.0.0.1:8000/api/health
```

再在手机浏览器访问：

```text
http://电脑IPv4:8000/api/health
```

电脑可以访问但手机不能访问时，检查是否处于同一 Wi-Fi、FastAPI 是否监听 `0.0.0.0`、公共 Wi-Fi 是否启用了设备隔离，以及 Windows 防火墙是否允许 TCP 8000 端口。可在管理员 PowerShell 中按需添加规则：

```powershell
netsh advfirewall firewall add rule name="SmartStudy FastAPI 8000" `
  dir=in action=allow protocol=TCP localport=8000
```

### 10. 推荐的答辩演示启动顺序

1. 电脑和手机连接同一个 Wi-Fi。
2. 手机开启无线调试。
3. 使用 `hdc tconn` 连接手机。
4. 使用 `hdc list targets -v` 确认状态为 `TCP Connected`。
5. 启动 MySQL。
6. 使用 `0.0.0.0:8000` 启动 FastAPI。
7. 使用 `ipconfig` 检查电脑当前 IPv4。
8. 确认 `AppConfig.ets` 填写电脑当前 IPv4。
9. 使用手机浏览器访问 `/api/health`。
10. 在 DevEco Studio 中选择真机并运行 `entry`。
11. 依次测试登录、课程、AI 文字问答、语音功能和 AI 组卷。

### 11. 故障排查

| 现象 | 原因 | 处理方法 |
| --- | --- | --- |
| `hdc` 命令无法识别 | HDC 未加入 Path | 使用完整路径或配置临时/用户环境变量 |
| `hdc list targets` 显示 `[Empty]` | HDC 驱动或调试通道异常 | 检查手机调试选项和 Windows `HDC Interface` |
| `HDC Interface` 状态为 Error | WinUSB 驱动异常 | 在设备管理器中为该接口安装 WinUSB 设备驱动 |
| 只出现 COM3、COM4 等 UART | 识别到电脑串口，不是真机 | 不连接 COM 端口，改用正常 USB HDC 或无线调试 |
| `tconn` 返回 `Connect OK` | 无线 HDC 已连接 | 再用 `list targets -v` 确认 `TCP Connected` |
| 真机显示登录页但无法登录 | FastAPI 或 MySQL 未启动 | 启动数据库和监听 `0.0.0.0:8000` 的后端 |
| 电脑能访问后端但手机不能 | 防火墙、设备隔离或网络不同 | 开放 TCP 8000 并确认同一 Wi-Fi |
| 修改后端 IP 后仍访问旧地址 | 真机仍安装旧客户端 | 重新 Run、构建并覆盖安装应用 |
| 更换网络后无法访问后端 | 电脑 IPv4 已变化 | 重新执行 `ipconfig` 并更新 `AppConfig.ets` |
| 签名报 `HmacPBESHA256 not available` | 命令行使用了过旧 Java | 临时切换到 DevEco Studio 自带 JBR 后重新构建 |
| 安装后仍显示旧应用图标 | 桌面缓存或仍使用旧 HAP | 确认新 HAP 已安装，刷新桌面，必要时卸载旧应用后重装 |

## 分布式能力验收

跨设备学习接续默认关闭。登录后进入“我的 → 设置 → 跨设备学习接续（实验）”主动开启。

双设备验收需要：

1. 两台可信 HarmonyOS 设备安装相同签名的应用。
2. 两台设备登录同一系统账号、连接同一无客户端隔离的局域网，并开启 WLAN、蓝牙和系统多设备协同能力。
3. 两端登录同一智学账号并开启实验开关，设置页应从“等待可信设备”变为“已连接可信设备”。
4. A 端完成学习任务后，B 端应在不切换页面的情况下收到事件并重新加载后端任务数据。
5. 通过系统应用接续入口迁移应用，目标设备应恢复对应白名单页面和安全上下文。

单设备或不支持分布式能力的模拟器只能验证权限声明、能力检测和降级提示。

### 当前双机验证状态（2026-07-27）

- 同一签名 HAP 已成功覆盖安装到 API 23、API 24 两台真机，应用均可启动。
- 两台设备均已授予 `DISTRIBUTED_DATASYNC`，系统可信设备列表也能看到对方。
- 当前系统分布式在线设备列表仍为空，应用因此显示“等待可信设备”；这表示可信关系存在，但系统分布式网络尚未上线。
- 验收时应改用同一家庭路由器或第三台设备热点，避免校园网、公司网和公共 Wi-Fi 的 VLAN/客户端隔离；必要时重新建立系统可信关系。
- 在系统在线设备出现并且应用显示“已连接可信设备”前，不宣称已经完成双机静默刷新验收。

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

2026-07-27 验证结果：

- AI 与分布式聚焦测试：`23 passed, 3 failed`。
- 后端完整测试：`33 passed, 10 failed`。失败项主要来自 RAG 文档数量、旧学生档案回退值、学习报告统计口径等接口预期差异，以及部分旧测试仍重复创建注册时已自动生成的学生档案，触发唯一约束；本次没有将这些失败误记为通过。
- API 24 主 HAP 已完成编译，最低兼容 API 23；同一签名包已在 API 23、API 24 两台真机完成覆盖安装。仓库移除本机签名材料后，可继续构建未签名 HAP；真机安装需在本地 DevEco Studio 配置签名。
- 双机已授予分布式权限并建立可信关系，但系统在线分布式设备列表仍为空，因此“前台静默刷新”尚未完成最终双真机验收。

更早的测试记录见 [测试记录](docs/TEST_REPORT.md)。

## 当前边界

- AI 生成的七天学习计划是预览，不自动写入 `study_tasks`。
- “添加到我的学习计划”是答辩演示按钮，当前不调用接口。
- 订单相关后端代码和历史页面仍保留，但未纳入当前正式客户端路由和答辩主流程。
- OCR 服务已经封装，尚未接入正式页面流程。
- 原生分布式能力需要同一系统账号、可信设备、相同应用签名和可互通网络；当前代码与构建已具备，系统在线组网仍需在合适网络环境下完成双机验收。
- 仓库不提交证书、Profile、密钥库、本机绝对路径或密码；真机 HAP 需在本地 DevEco Studio 中配置调试签名。

## 文档

- [后端说明](server/README.md)
- [AI 运行说明](server/README_AI.md)
- [接口说明](docs/API.md)
- [AI 架构设计](docs/AI_DESIGN.md)
- [代码分层与注释规范](docs/CODE_STRUCTURE.md)
- [分布式学习接续设计](docs/DISTRIBUTED_DESIGN.md)
- [分布式部署与双设备验收](docs/DISTRIBUTED_DEPLOYMENT.md)
- [开发日志](docs/DEVELOPMENT_LOG.md)
- [测试记录](docs/TEST_REPORT.md)
- [AI 提示词完整记录](docs/PROMPTS.md)
- [踩坑复盘](docs/PITFALLS.md)
- [答辩 PPT 素材](docs/PPT_OUTLINE.md)
