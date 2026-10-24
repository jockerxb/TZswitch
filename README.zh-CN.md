<p align="center"><img src="Assets/logo.png" width="120" alt="TZswitch 图标"></p>

# TZswitch

一个轻量的 macOS **系统时区切换工具**。支持 Mac 上的全球时区，并可自定义两个常用时区。

[English](README.md) · [下载最新版](https://github.com/jockerxb/TZswitch/releases/latest) · [MIT 许可证](LICENSE)

## 使用

1. 下载 Release 中的 universal ZIP，解压后将 **TZswitch.app** 拖进“应用程序”，即可从启动台启动。
2. 首次打开时，点击编号 1 和 2 的卡片，选择常用城市。全球列表按当前 UTC 偏移从小到大分组，滚动时固定当前分组标题，右侧 UTC 索引可快速跳转；数量按当前 UTC 偏移分组数和去重后的城市条目数分别显示。支持搜索城市或输入 `utc9`、`utc-8`、`utc5:30` 等偏移。选中城市后立即请求 macOS 管理员授权，验证切换成功后才保存新城市；取消授权或切换失败会保留原城市与系统时区。未选择时可点击“关闭”或按 Esc 返回。
3. 点击卡片主体切换系统时区，点击右侧 `>` 区域更换常用城市；绿色边框表示当前使用的时区。
4. 在 macOS 弹窗中进行管理员授权。App 回读系统状态，验证成功后才显示切换完成。关闭窗口即可退出，左上角使用标准 macOS 关闭、最小化和全屏按钮。

需要 macOS 13 或更新版本；通用安装包包含 Apple Silicon 与 Intel 两种架构。支持中文城市名、英文城市名、IANA 标识（如 `Asia/Shanghai`）及 UTC 偏移（如 `UTC+05:45`）搜索。北京、Beijing、北京时间均可找到“北京 / 上海”（`Asia/Shanghai`）。同城且完整时区规则一致的兼容名称合并展示，旧名称仍可搜索。

当前 Release 使用 **ad hoc 签名**，尚未经过 Developer ID 签名与 Apple 公证。首次运行可能需要在“系统设置 → 隐私与安全性”中允许打开。请确认下载来源，也可以按下方说明自行构建。

## 时区如何保留

- 新用户没有默认城市，首次打开时引导选择两个不同的常用时区；设置到一半退出也能继续。旧版已保存的选择会保留，偏好只保存在本机。
- 全球时区及夏令时规则来自 macOS 系统数据库，随系统更新。
- 手动切换时会关闭“自动设置时区”，避免系统根据位置改回；不影响自动校准网络时间。
- 启动、关闭选择面板和退出不会修改系统时区；选择新城市或点击卡片会请求授权后切换。退出后保留已设置的时区，再次打开时读取系统实际状态。
- 无顶部菜单栏常驻图标，无后台服务。关闭窗口即退出；授权过程中需先完成或取消授权。
- 无账号、遥测或网络请求，无第三方运行依赖。

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
