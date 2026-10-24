支持 macOS 13+，一个通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 授权前暂存城市选择，系统回读验证成功后才提交常用城市。取消授权或失败时保留原城市；首次设置取消后仍保留空位。
- 修复无搜索结果时列表宽度塌缩导致提示竖排的问题；空状态占满列表区域，提示横向单行显示，并隐藏无内容的 UTC 导航。
- 增加切换流程回归测试，覆盖取消、失败、回读不一致、成功、首次设置、重复回调和重新启动读取。

下载 `TZswitch-2.1.11-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

此版本使用 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证，首次启动可能需要在系统“隐私与安全性”中允许打开。

---

Stage favorite changes until the system switch is verified. Cancellation and failure preserve previous favorites; first-run cancellation leaves the slot empty. Fix collapsed empty-search layout with a full-width single-line message and hide the empty UTC index. Add selection-flow regression tests for success, cancellation, failures, verification, onboarding and persistence. macOS 13+, Apple Silicon + Intel universal binary. MIT licensed; ad hoc signed, not Developer ID signed or notarized.
