支持 macOS 13.0+，通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 常用时区扩展到最多 3 个城市。首次只设置一个，第 2、第 3 个由用户主动添加；升级保留原有城市。
- 新增备用时区显示：打开开关后必须手动选择城市，菜单栏仅显示星期与时分；取消选择保持关闭，不请求系统授权。
- 备用时区独立保存，不随系统时区切换改变。关闭或退出主界面时继续显示；点击菜单栏时间可“退出××时间”，不会改变系统时区。
- 支持按住 Command（⌘）拖动备用时间调整菜单栏位置；显示开关切换时复用原生菜单栏项目。
- 默认窗口高度按实际内容自动适配，增加城市或展开备用设置时减少多余留白，同时保留用户手动调整的尺寸。
- 更新中英文产品说明，补充配合 VPN、出差旅行、跨地区工作的场景和完整操作说明。

下载 `TZswitch-2.2.0-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

当前为 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。首次打开若被阻止，确认来源后点击“完成”，进入“系统设置 → 隐私与安全性”，找到 TZswitch 并点击“仍要打开”，按提示授权后点击“打开”。详见 [使用说明](https://github.com/jockerxb/TZswitch/blob/main/docs/USER_GUIDE.zh-CN.md)。

---

Add up to three favorites and an independent, opt-in menu-bar clock showing weekday and HH:mm. Every enable action requires a manual city choice. Closing or quitting the main interface keeps an enabled clock alive; stopping the clock leaves the system timezone untouched. Fit default window height to actual content, preserve existing preferences, and document VPN-region and travel use cases. macOS 13+, Apple Silicon + Intel; ad hoc signed, not notarized.
