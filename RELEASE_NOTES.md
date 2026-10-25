支持 macOS 13.0+，通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 修复备用时间关闭再开启后位置变化的问题：保留用户拖动后的菜单栏位置，并在重新开启和重开 App 时恢复。
- 重新拖动备用时间后，记住新位置；不影响其他菜单栏图标。

下载 `TZswitch-2.2.5-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

当前为 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。首次打开受阻时，请参考 [使用说明](https://github.com/jockerxb/TZswitch/blob/main/docs/USER_GUIDE.zh-CN.md)。

---

Preserve the backup clock's user-chosen menu-bar position when toggling it off and on or reopening the app. A new drag replaces the saved position without changing other menu-bar items. macOS 13+, Apple Silicon + Intel; ad hoc signed, not notarized.
