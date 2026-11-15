支持 macOS 13.0+，通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 切换失败时区分授权被拒、系统时区未生效、自动时区关闭失败和恢复失败，避免把系统写入失败误报为权限问题。
- 给 macOS 留出短暂时间更新系统状态，再验证切换结果；不会重复执行切换命令。

下载 `TZswitch-2.3.6-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

当前为 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。首次打开受阻时，请参考 [使用说明](https://github.com/jockerxb/TZswitch/blob/main/docs/USER_GUIDE.zh-CN.md)。

---

Switching errors now distinguish denied authorization, system settings that didn’t take effect, and an unsuccessful rollback. TZswitch also briefly waits for macOS to update its settings before verifying the change.
