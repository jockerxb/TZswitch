支持 macOS 13.0+，通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 切换系统时区时，TZswitch 直接发起 macOS 管理员授权。弹窗会说明应用名称和目标城市，密码仍由 macOS 处理。

下载 `TZswitch-2.3.7-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

当前为 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。首次打开受阻时，请参考 [使用说明](https://github.com/jockerxb/TZswitch/blob/main/docs/USER_GUIDE.zh-CN.md)。

---

TZswitch now requests administrator authorization directly. The macOS prompt identifies TZswitch and the destination city. macOS still handles the password.
