# 测试记录（2026-07-26）

本文记录当前工作区的真实验证结果。测试通过、编译通过和真机通过是三种不同结论，不能相互替代。

## 1. 后端自动化测试

### 聚焦回归

执行命令：

```powershell
python -m pytest server/tests/test_speech_service.py server/tests/test_auth.py -q
```

最近结果：`4 passed`。

聚焦覆盖：

- 认证基础流程。
- 语音文件校验。
- 阻塞音频识别任务从异步接口线程中移出。
- 识别服务错误的统一转换。

### 完整测试套件

执行命令：

```powershell
python -m pytest -q
```

最近结果：`16 passed, 10 failed`。

当前不能写成“全部测试通过”。通过项覆盖了认证基础能力、语音服务、部分 AI 工具、课程试卷与学习流程；10 个失败主要属于测试预期与当前业务契约不同步：

- 注册接口现在会自动创建学生档案，旧测试仍手动创建同一档案，触发唯一约束。
- 家长角色的 RAG 重建测试与当前权限判断不一致。
- 无效学生档案 ID 的首页降级测试仍期望返回 `0`，当前会回退到账号自动创建的真实档案。
- 仓库存在订单相关代码，但订单路由没有接入当前正式 API 聚合，相关测试返回 404。
- 主目录的旧数据保留顺序、学生跨年级/学科修改等测试仍使用旧业务预期。
- 学习计划、家庭隔离和错题复测中的多个失败同样源于测试辅助逻辑重复创建注册时已经自动生成的档案。

这些失败已如实保留，不能通过修改文档、跳过测试或连接开发 MySQL 来掩盖。后续应先统一当前产品契约，再逐项修正测试或实现。

## 2. 测试隔离与数据库安全

- 自动化测试使用隔离 SQLite 和 Mock AI Provider。
- 测试环境不读取真实 DeepSeek Key，不产生模型费用。
- 测试不得对开发 MySQL 执行 `drop_all()` 或批量清理。
- 真实数据库结构由 Alembic 管理；启动兼容补丁只处理可安全重复执行的旧结构修补。
- `Duplicate key name` 表示目标索引已存在，兼容补丁会记录并跳过，不应因此删除数据库。

## 3. Python 静态检查

后端模块已执行：

```powershell
python -m compileall server
```

结果：通过，未发现 Python 语法错误。

## 4. HarmonyOS API 24 构建

构建命令：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
```

最近结果：`BUILD SUCCESSFUL in 48.390s`。

该结果证明当前 ArkTS 与资源可以通过 API 24 编译，其中包含：

- 登录、课程、试卷、学习计划、错题和学习报告页面。
- AI 文字对话、SSE、结构化卡片、语音输入与播报代码。
- `distributedDataObject`、分布式权限声明和 `UIAbility.onContinue` 接续代码。

构建仍有既有 SDK 弃用提示和未配置 `signingConfigs` 的警告。当前产物是 unsigned HAP，不能据此宣称已经完成签名安装或双设备接续测试。

## 5. API 与业务检查

当前关键接口与流程包括：

- `GET /api/health`、认证与学生档案。
- 课程、试卷、收藏、在线练习和错题。
- 学习计划、任务状态和学习报告。
- `POST /api/ai/chat` 与 SSE 流式对话。
- AI 数学组卷与语音识别接口。

AI 七天学习计划已经改为根据成绩层次、薄弱点和每周学习分钟数生成预览，不依赖课程目录精确匹配；生成前后不新增 `study_tasks`。卡片中的“添加到我的学习计划”是本地演示按钮，不代表数据库已经写入。

## 6. 设备验收状态

当前 `hdc list targets` 结果为 `[Empty]`，没有连接可用于本轮验收的模拟器或真机。因此以下内容仍属于待设备验证：

- 中文输入法组合态在目标系统版本上的完整体验。
- 麦克风授权、真实录音、系统语音播报和不同噪声环境识别。
- SSE 在真机网络切换、后台恢复条件下的稳定性。
- 签名 HAP 安装及不同屏幕尺寸适配。
- 两台可信 HarmonyOS 设备间的任务状态同步和应用接续。

分布式双设备验收步骤见[分布式部署与验收说明](DISTRIBUTED_DEPLOYMENT.md)。

## 7. 结论

- **已确认**：聚焦后端测试通过、Python 编译通过、HarmonyOS API 24 HAP 构建通过。
- **已知问题**：完整 pytest 当前为 16 通过、10 失败，失败原因已分类记录。
- **未完成**：签名安装、真机语音和双真机分布式运行验收。
- **材料口径**：答辩中应表述为“分布式代码与构建已完成，受实验设备限制尚未完成双真机效果演示”。
