支持 macOS 13+，一个通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 时区选择面板提供明确的“× 关闭”按钮，并支持 Esc 返回。
- 右侧新增可滚动 UTC 快速导航，点击跳转到对应分组，包括半小时、45 分钟偏移。
- 搜索提示改为“搜索时区/城市，例如：utc9、北京”。
- 支持 utc9、utc 9、UTC+9、utc-8、utc5:30、utc5.75 等写法，按真实 UTC 偏移匹配，也可组合城市名称搜索。

下载 `TZswitch-2.1.8-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

此版本使用 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证，首次启动可能需要在系统“隐私与安全性”中允许打开。

---

Explicit Close button and Esc dismissal in the timezone picker. Scrollable right-hand UTC index jumps to exact groups, including fractional offsets. Search accepts compact UTC offsets such as utc9, utc-8, utc5:30 and utc5.75, optionally combined with city names. macOS 13+, Apple Silicon + Intel universal binary. MIT licensed; ad hoc signed, not Developer ID signed or notarized.
