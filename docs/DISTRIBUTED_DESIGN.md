# HarmonyOS 原生分布式学习接续

> 本文说明代码设计与数据边界；环境准备、签名安装、双设备操作和故障排查见[分布式部署与验收说明](DISTRIBUTED_DEPLOYMENT.md)。

## 目标

项目使用 HarmonyOS 原生分布式数据对象和应用接续能力，让同一智学账号在可信鸿蒙设备之间同步学习计划上下文，并在另一台设备继续查看学习任务。

这不是普通的 HTTP 云端同步，也不依赖 Redis、Kafka 或额外的后端微服务。

## 代码证据

- `entry/src/main/module.json5`
  - 声明 `ohos.permission.DISTRIBUTED_DATASYNC`。
  - `EntryAbility` 配置 `continuable: true`。
- `entry/src/main/ets/service/DistributedStudyService.ets`
  - 使用 `@kit.ArkData` 的 `distributedDataObject.create`。
  - 加入账号级分布式会话，监听 `change` 和 `status`。
  - 处理权限拒绝、能力不支持、设备离线和主动关闭。
- `entry/src/main/ets/entryability/EntryAbility.ets`
  - 通过 `onContinue` 输出学习计划接续状态。
  - 通过 `onCreate` 和 `onNewWant` 接收目标设备状态。
- `SettingsPage.ets` 与 `StudyPlanPage.ets`
  - 提供可见的实验功能开关。
  - 在任务状态由后端保存成功后发布跨设备更新。
  - 接收端只刷新后端数据，不直接改写数据库。

## 数据流

```text
用户开启实验功能
→ 请求 DISTRIBUTED_DATASYNC 权限
→ 加入 smartstudy_user_<userId> 分布式会话
→ 学习任务先通过 FastAPI 保存到 MySQL
→ 发布任务 ID、状态、日期和筛选条件
→ 可信设备收到 change 事件
→ 重新调用学习计划接口获取真实数据
```

应用接续流程：

```text
源设备 EntryAbility.onContinue
→ Want 参数携带账号会话和学习计划快照
→ 目标设备 onCreate/onNewWant 接收
→ 恢复或要求用户登录
→ 校验为同一智学账号
→ 打开学习计划页并恢复日期与筛选条件
```

## 安全边界

分布式载荷只包含版本、页面名、任务 ID、任务状态、选中日期、筛选条件和更新时间，不包含 JWT、用户名、成绩、答案、AI 对话或数据库凭据。

MySQL 始终是业务事实来源。分布式对象只承担通知和接续上下文，不绕过 FastAPI 的 JWT、权限校验和参数验证。

## 实验条件与降级

- 功能默认关闭，只在用户主动开启时申请权限。
- 当前模拟器或设备不支持时，设置页显示“不支持”并恢复关闭状态。
- 没有第二台可信设备时，状态显示“已开启，等待可信设备”。
- 分布式能力异常不会影响登录、课程、试卷、学习计划和 AI 助手等原有功能。

## 真机验收建议

1. 两台可信鸿蒙设备安装同一签名的 HAP，并登录同一智学账号。
2. 两端在设置中开启“跨设备学习接续（实验）”。
3. A 端进入学习计划并完成一项任务。
4. B 端应收到分布式变化并刷新后端任务状态。
5. 从系统接续入口迁移应用，目标设备应恢复学习计划页、日期和筛选条件。
