# 踩坑复盘

- API 24 Navigation类型定义允许 `unknown`，但工程严格规则禁止显式 `unknown`；PageMap改用SDK兼容的 `Object`，只在详情路由做明确转换。
- ArkTS不允许无类型对象字面量；HTTP Header改为显式类。
- 模拟器中的 `127.0.0.1` 指向模拟器自身，联调时要填写电脑局域网IP。
- `promptAction.showToast` 在API 24显示弃用警告但仍可编译，后续可迁移到UIContext提示接口。
- CoreSpeechKit/CoreVisionKit存在SDK类型不代表模拟器具备系统能力，必须使用 `canIUse` 和真机测试。
- 云端任务同步不是鸿蒙原生分布式流转，答辩时要明确区分。
- 当前环境的SQLAlchemy 2.0.34与asyncmy 0.2.11在 `pool_pre_ping` 上存在方法签名兼容问题；MySQL连接池改用 `pool_recycle=1800`，避免启动失败和长期复用空闲连接。
- 后端测试会执行 `drop_all()`，必须在导入后端模块前将数据库地址覆盖为测试SQLite，禁止直接对开发MySQL运行该测试夹具。
