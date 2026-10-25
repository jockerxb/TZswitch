# TZswitch 维护规则

- 新增或修改功能时，默认同步完成中文和英文，不需要用户另行提醒；修改中文含义时也要重新审校对应英文。
- 所有界面文案通过 `AppText` 提供中英文，由持久化的 `AppModel.language` 驱动。覆盖主窗口、选择器、菜单栏、原生菜单、提示、错误和辅助功能标签。
- 英文根据操作场景撰写，不逐字翻译。使用 `time zone`；保留产品术语 `Backup time zone`；从常用项移除用 `Remove`，隐藏菜单栏时间用 `Hide`。按钮和菜单命令使用 title case，说明文字使用 sentence case。
- 城市名使用 macOS 提供的本地化名称。不要为了翻译改动 IANA 标识、时区计算、用户设置或切换行为。
- 不在应用里加入运行时机器翻译。两种语言一起审校、构建和发布；运行既有翻译完整性检查，并在界面验证英文排版与语言切换。
- 界面保持简洁，不为解释实现细节增加提示文字。

英文写作参考：[Apple Writing HIG](https://developer.apple.com/design/human-interface-guidelines/writing)。
