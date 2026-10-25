支持 macOS 13.0+，通用安装包同时包含 Apple Silicon 与 Intel 版本。

- 新增常用时区删除功能：点击卡片右侧 `>`，在面板底部选择“删除此常用时区”；也可右键卡片删除。
- 仅有 2～3 个常用城市时显示删除入口，至少保留 1 个；底层同时禁止删除最后一个。
- 删除后自动重新编号并释放添加名额；不会请求管理员授权、改变系统时区或备用时钟。
- 删除结果保存在本机，重新打开后不会恢复已删除的城市。

下载 `TZswitch-2.2.1-macOS-universal.zip`，解压后将 App 拖入“应用程序”。`SHA256SUMS.txt` 可用于校验下载内容。

当前为 ad hoc 签名，尚未经过 Developer ID 签名与 Apple 公证。首次打开受阻时，请参考 [使用说明](https://github.com/jockerxb/TZswitch/blob/main/docs/USER_GUIDE.zh-CN.md)。

---

Remove a favorite from its edit picker or card context menu. Deletion is available only with two or three favorites, keeps at least one, compacts numbering, and persists without changing the system timezone or backup clock. macOS 13+, Apple Silicon + Intel; ad hoc signed, not notarized.
