支持 macOS 13+，一个通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 隐藏窗口标题栏中央的 TZswitch，保留标准关闭、最小化和全屏按钮。
- 缩短默认窗口高度与底部间距，减少多余留白；首次设置界面使用对应尺寸，完成设置后自动收紧默认窗口。
- 升级时一次性更新旧窗口尺寸，之后继续记住用户手动调整的大小；保留常用城市和系统时区。

下载 `TZswitch-2.1.14-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

此版本使用 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证，首次启动可能需要在系统“隐私与安全性”中允许打开。

---

Hide the centered window title while retaining standard macOS controls. Compact window height and bottom padding for both normal and first-run layouts, automatically compacting the default window after setup, with a one-time migration of saved window geometry. macOS 13+, Apple Silicon + Intel universal binary. MIT licensed; ad hoc signed, not Developer ID signed or notarized.
