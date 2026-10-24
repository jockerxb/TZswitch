支持 macOS 13+，一个通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 全球时区按当前 UTC 偏移从小到大分组，保留城市、IANA 标识与偏移搜索。
- 新用户通过引导选择两个常用时区，不预设城市；设置进度在本地保存，升级保留原有选择。
- 主界面专注常用时区切换，移除独立全球浏览入口与界面版本号。
- 绿色边框表示当前时区，向右箭头表示切换，移除重复的勾选图标。
- 使用标准 macOS 窗口控制，支持缩放和全屏；去掉底部退出按钮，关闭窗口即退出。
- 设置偏好与启动／退出均不改变系统时区，只有手动切换才请求管理员授权。

下载 `TZswitch-2.1.0-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

此版本使用 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证，首次启动可能需要在系统“隐私与安全性”中允许打开。

---

UTC-sorted timezone groups, first-run setup without preset cities, preserved existing favorites, a simpler two-favorite interface, and standard macOS window controls. macOS 13+, Apple Silicon + Intel universal binary. MIT licensed; ad hoc signed, not Developer ID signed or notarized.
