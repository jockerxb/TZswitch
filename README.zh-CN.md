<p align="center"><img src="Assets/logo.png" width="120" alt="TZswitch 图标"></p>

# TZswitch

一个轻量的 macOS **系统时区切换工具**。支持 Mac 上的全球时区，可保存一到两个常用时区，设置一个即可使用。

[English](README.md) · [App 使用说明](docs/USER_GUIDE.zh-CN.md) · [下载最新版](https://github.com/jockerxb/TZswitch/releases/latest) · [MIT 许可证](LICENSE)

## 使用

1. 下载 Release 中的 universal ZIP，解压后将 **TZswitch.app** 拖进“应用程序”，即可从启动台启动。
2. 首次打开时，点击任意一个“点击设置常用城市”入口，搜索城市或输入 `utc9`、`utc-8` 等偏移，然后选择城市。设置一个即可使用，第二个可选。
3. 选中城市后会自动请求 macOS 管理员授权，确认并验证成功后即生效，无需再点卡片。取消授权或失败时保留原城市。
4. 日常点击卡片主体切换，右侧 `>` 用于更换城市；绿色边框表示当前使用的时区。关闭主窗口即可退出，系统时区继续保留。

安装、首次设置、搜索示例、UTC 导航、取消授权及常见问题，请查看 **[App 使用说明](docs/USER_GUIDE.zh-CN.md)**。

需要 macOS 13 或更新版本；通用安装包包含 Apple Silicon 与 Intel 两种架构。支持中文城市名、英文城市名、IANA 标识（如 `Asia/Shanghai`）及 UTC 偏移（如 `UTC+05:45`）搜索。北京、Beijing、北京时间均可找到“北京 / 上海”（`Asia/Shanghai`）。同城且完整时区规则一致的兼容名称合并展示，旧名称仍可搜索。

当前 Release 使用 **ad hoc 签名**，尚未经过 Developer ID 签名与 Apple 公证。首次运行可能需要在“系统设置 → 隐私与安全性”中允许打开。请确认下载来源，也可以按下方说明自行构建。

### 首次打开提示“Apple 无法验证 TZswitch”

确认安装包来自[本仓库 Releases](https://github.com/jockerxb/TZswitch/releases/latest) 后：

1. 在拦截弹窗中点击 **“完成”**。
2. 打开 **系统设置 → 隐私与安全性**，向下找到 TZswitch 被阻止的提示。
3. 点击 **“仍要打开”**，按系统提示授权，再点击 **“打开”**。

系统会记住对该 App 的允许，之后可以正常启动。操作依据见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

## 时区如何保留

- 新用户没有默认城市，首次打开时设置一个常用城市即可结束引导；可按需再添加第二个不同的城市。只保存一个城市时，重启后也可继续使用。旧版已保存的选择会保留，偏好只保存在本机。
- 全球时区及夏令时规则来自 macOS 系统数据库，随系统更新。
- 手动切换时会关闭“自动设置时区”，避免系统根据位置改回；不影响自动校准网络时间。
- 启动、关闭选择面板和退出不会修改系统时区；选择新城市或点击卡片会请求授权后切换。退出后保留已设置的时区，再次打开时读取系统实际状态。
- 无顶部菜单栏常驻图标，无后台服务。关闭窗口即退出；授权过程中需先完成或取消授权。
- 无账号、遥测或第三方运行依赖；时区功能不发起网络请求。标题右侧的 GitHub 入口仅在点击后通过默认浏览器打开项目首页，可查看源码、下载更新或反馈问题。

## 从源码构建

先安装 Apple Xcode Command Line Tools（`xcode-select --install`），然后运行：

```sh
git clone https://github.com/jockerxb/TZswitch.git
cd TZswitch
./build.sh                 # 通用 App：dist/TZswitch.app
./test.sh                  # 自动测试，不修改系统时区
./package.sh               # 构建、测试、生成 ZIP 和 SHA256 校验文件
```

本机构建可用 `./build.sh arm64` 或 `./build.sh x86_64` 缩短时间。源码使用 Swift、SwiftUI 与 AppKit；图标工具仅使用 Python 3 标准库及原生 CoreGraphics。

测试覆盖夏令时边界、半小时／45 分钟偏移、全球时区搜索、常用时区保存、首次设置引导、旧版偏好迁移与 UTC 分组、非法输入、切换结果验证、失败恢复和 11 种 ICNS 表示。切换流程回归测试覆盖授权取消、失败、验证不通过、成功、首次设置和重新启动读取。系统命令事务与切换流程使用模拟环境，不请求管理员权限。若执行环境无法加载 Standard Additions，会跳过 AppleScript 语法编译；App 在实际授权前也会编译检查。真实授权切换和界面检查需要在 Mac 上手动完成。

## 开发与发布

`Sources/TimezoneCore.swift` 负责目录、偏好、系统读取和切换事务；`Sources/AppModel.swift` 负责授权流程及成功后的偏好提交；`Sources/main.swift` 负责界面与生命周期。时区标识只允许系统数据库内的值，执行前再次进行 shell 转义。切换失败时尝试恢复原时区与自动时区设置。

GitHub Actions 在 push 和 pull request 时自动构建、测试并打包；推送 `v*` 标签会在检查通过后发布 Release，标签必须与 `Info.plist` 中的版本一致。

欢迎提交 issue 或 pull request。发布前运行 `./package.sh`，请勿提交管理员密码、私人偏好、签名凭证和本机构建产物。

如果 TZswitch 对你有帮助，欢迎给项目一个 [Star](https://github.com/jockerxb/TZswitch)，方便收藏，也支持项目继续改进。
