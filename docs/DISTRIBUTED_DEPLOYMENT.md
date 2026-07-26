# HarmonyOS 原生分布式部署与验收说明

## 1. 能力范围

本项目实现的是 HarmonyOS 原生跨设备学习接续：

- 使用 `distributedDataObject` 在可信设备间同步学习任务变化和页面上下文。
- 使用 `UIAbility.onContinue` 将学习计划页面接续到另一台设备。
- FastAPI 与 MySQL 继续保存和校验真实业务数据。

这不是 Redis、Kafka 或后端微服务集群，也不是把普通云端账号同步包装成分布式功能。分布式对象只承担“变化通知”和“接续上下文”传递。

## 2. 架构与数据流

```text
HarmonyOS 设备 A                         HarmonyOS 设备 B
学习任务提交 ──HTTP/JWT──> FastAPI ──> MySQL
      │                                     ▲
      └── distributedDataObject 变化通知 ───┤
                                            │
                              收到通知后重新请求后端

设备 A EntryAbility.onContinue
      └── Want 接续参数 ──> 设备 B onCreate/onNewWant
                              └── 登录与账号校验后恢复学习计划页面
```

同步顺序固定为：先由后端保存任务，再发布分布式快照；接收设备只刷新后端数据，不直接根据快照修改数据库。

## 3. 代码与配置证据

- `entry/src/main/module.json5`
  - 声明 `ohos.permission.DISTRIBUTED_DATASYNC`。
  - 为 `EntryAbility` 配置 `continuable: true`。
- `entry/src/main/ets/service/DistributedStudyService.ets`
  - 创建分布式数据对象、申请权限、加入账号会话、监听状态和变化并释放资源。
- `entry/src/main/ets/entryability/EntryAbility.ets`
  - 通过 `onContinue` 输出快照，通过 `onCreate` 和 `onNewWant` 接收接续参数。
- `entry/src/main/ets/pages/SettingsPage.ets`
  - 提供“跨设备学习接续”实验开关和能力状态。
- `entry/src/main/ets/pages/StudyPlanPage.ets`
  - 发布任务变化、订阅远端通知并刷新后端数据。

实现参考 HarmonyOS 官方的[分布式数据对象与应用接续示例](https://gitee.com/harmonyos_samples/guide-snippets/blob/master/DistributedAppDev/ContinueSample/entry/src/main/ets/migrationability_asset/MigrationAbility_asset.ets?skip_mobile=true)。

## 4. 部署前提

### 开发环境

- Windows 开发电脑。
- DevEco Studio 6.1.1 或与工程兼容的版本。
- HarmonyOS NEXT SDK API 24。
- Python 3.11、MySQL 8.x 和项目后端依赖。

### 双设备条件

- 两台支持分布式数据对象和应用接续的 HarmonyOS 设备。
- 两台设备已经建立可信关系，并处于系统分布式能力可用的网络环境。
- 两端安装相同 bundle、相同版本且使用同一签名证书签名的 HAP。
- 两端登录同一个智学规划助手账号。
- 两端都能访问同一 FastAPI 服务。

> 当前命令行构建没有配置发布签名，生成的是 unsigned HAP。它可以用于编译检查，但不能作为双真机接续已经通过的证据。真机验收前必须在 DevEco Studio 中配置有效签名。

## 5. 后端部署

### 5.1 初始化配置

在仓库根目录创建并激活虚拟环境，然后安装依赖：

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r server\requirements.txt
```

复制 `server/.env.example` 为 `server/.env`，填写本机 MySQL 连接、JWT Secret 和可选的 DeepSeek Key。真实密钥不得提交到 GitHub。

### 5.2 初始化数据库

```powershell
mysql -u root -p < server\sql\create_database.sql
python -m alembic -c server\alembic.ini upgrade head
```

如开发数据库已经初始化，只执行迁移并保留已有学习数据，不要通过删库解决重复索引或半迁移问题。

### 5.3 启动服务

```powershell
python -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --reload
```

通过以下地址检查服务：

- `http://127.0.0.1:8000/api/health`
- `http://127.0.0.1:8000/docs`

若出现 `[WinError 10048]`，说明 8000 端口已有进程占用。先执行：

```powershell
Get-NetTCPConnection -LocalPort 8000 | Select-Object LocalAddress,LocalPort,State,OwningProcess
```

确认占用进程是否就是已启动的正确后端；不要在没有确认 PID 的情况下批量终止进程。

## 6. 客户端配置、签名与安装

### 6.1 配置局域网地址

将 `entry/src/main/ets/common/AppConfig.ets` 中的 `API_BASE_URL` 改为开发电脑当前局域网 IPv4，例如：

```text
http://192.168.1.10:8000/api
```

设备中的 `127.0.0.1` 指向设备自身，不能用于访问电脑上的 FastAPI。两台设备必须能打开后端健康检查地址，Windows 防火墙也需要允许 8000 端口。

### 6.2 配置相同签名

在 DevEco Studio 的项目签名配置中，为 `entry` 模块选择同一套证书和 Profile。两台设备安装的应用必须具有相同签名身份，否则系统不会把它们识别为可接续的同一应用。

### 6.3 构建

命令行编译检查可使用：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
```

正式双真机验收应从配置好签名的 DevEco Studio 构建并安装 HAP。安装完成后，在两台设备上登录同一个账号。

## 7. 功能开启与状态说明

进入“我的 → 设置”，打开“跨设备学习接续（实验）”。功能只在用户主动开启时申请 `DISTRIBUTED_DATASYNC` 权限。

状态含义：

| 状态 | 含义与处理 |
| --- | --- |
| 未开启 | 功能关闭，没有加入分布式会话 |
| 等待权限 | 系统权限弹窗尚未完成处理 |
| 已开启，等待可信设备 | 本机已加入会话，但还没有可用的另一台设备 |
| 已连接 | 已发现可信设备，可接收分布式变化 |
| 当前设备不支持 | 系统或设备缺少能力，开关自动恢复关闭 |
| 权限被拒绝 | 用户拒绝权限，可在系统设置中重新授权后再开启 |

退出登录、切换账号或关闭开关时，应用会离开当前会话并移除监听，避免旧账号状态残留。

## 8. 双设备验收步骤

### 8.1 学习任务状态同步

1. 两台设备建立可信关系，安装同一签名 HAP，并登录同一智学账号。
2. 两端都开启“跨设备学习接续（实验）”。
3. 设备 A 进入学习计划，选择日期并开始或完成一项真实任务。
4. 确认设备 A 先收到后端保存成功结果。
5. 设备 B 收到分布式变化后重新加载学习计划。
6. 确认设备 B 展示的任务状态与 MySQL 中记录一致。

### 8.2 应用接续

1. 设备 A 停留在学习计划页，选择特定日期和筛选条件。
2. 通过系统提供的应用接续入口迁移到设备 B。
3. 设备 B 接收 `onCreate` 或 `onNewWant` 参数。
4. 若设备 B 未登录，先进入登录流程；登录同一账号后再消费接续状态。
5. 确认设备 B 打开学习计划页，并恢复日期、筛选条件和任务上下文。
6. 使用不同账号登录时，确认旧账号快照不会被恢复。

## 9. 数据与安全边界

分布式快照只允许包含：

- 数据版本。
- 当前页面。
- 学习任务 ID 和任务状态。
- 选中日期。
- 页面筛选条件。
- 更新时间。

不得同步 JWT、用户名、成绩、答案、AI 对话、数据库连接或第三方密钥。接收端必须使用自己的登录令牌重新调用后端；MySQL 始终是最终事实来源。

## 10. 常见问题排查

### 两端一直显示“等待可信设备”

- 检查设备是否已建立可信关系。
- 检查两端系统分布式能力是否开启。
- 检查 HAP 的 bundle、版本和签名是否一致。
- 检查两端是否登录同一智学账号并加入相同账号会话。

### 开关自动恢复关闭

- 检查是否拒绝了 `DISTRIBUTED_DATASYNC` 权限。
- 检查设备或模拟器是否支持分布式数据对象。
- 查看设置页提示和设备日志；不支持时属于预期降级，不影响其他功能。

### B 端收到通知但任务状态没有变化

- 确认 A 端后端保存请求是否成功。
- 确认两端 `API_BASE_URL` 指向同一后端。
- 直接检查后端接口或 MySQL 中的真实任务状态。
- 分布式快照不会直接写数据库，后端未保存成功时 B 端不应伪造完成状态。

### 接续后仍进入登录页

- 这是安全设计：接续状态不能绕过 JWT 登录。
- 登录同一账号后应恢复页面；不同账号不会消费原账号的接续快照。

## 11. 当前验收结论

截至 2026 年 7 月 26 日：

- 权限声明、`continuable` 配置、分布式对象服务、设置入口和接续生命周期代码已实现。
- HarmonyOS API 24 HAP 已完成编译验证。
- 当前构建为 unsigned HAP，且没有两台可用可信设备，因此没有宣称双真机运行效果已经验证。
- 最终答辩可展示代码证据、权限配置、数据流、构建结果和本部署说明；双真机效果应在满足签名与设备条件后按本章步骤补验。

设计说明见 [HarmonyOS 原生分布式学习接续](DISTRIBUTED_DESIGN.md)。
