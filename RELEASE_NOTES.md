支持 macOS 13+，一个通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 标题右侧新增 GitHub 入口，在默认浏览器打开项目首页，方便查看源码、下载更新或反馈问题。
- 安装说明补充“Apple 无法验证 TZswitch”时的具体处理步骤，中英文 README 与 App 使用说明同步更新。
- README 末尾增加自愿 Star 收藏提示。

下载 `TZswitch-2.1.15-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

此版本使用 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。首次打开若被阻止，确认来源后点击“完成”，进入“系统设置 → 隐私与安全性”，找到 TZswitch 并点击“仍要打开”，按提示授权后点击“打开”。详见 [App 使用说明](https://github.com/jockerxb/TZswitch/blob/main/docs/USER_GUIDE.zh-CN.md)。

---

Add a compact GitHub link in the app header, opening the project in the default browser. Document the first-launch Gatekeeper approval steps in both READMEs and the user guide, with an optional Star invitation. macOS 13+, Apple Silicon + Intel universal binary. MIT licensed; ad hoc signed, not Developer ID signed or notarized.
