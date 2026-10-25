<p align="center"><img src="Assets/logo.png" width="120" alt="TZswitch icon"></p>

# TZswitch

[English](#english) · [中文说明](#chinese) · [App 使用说明](docs/USER_GUIDE.zh-CN.md) · [Download / 下载](https://github.com/jockerxb/TZswitch/releases/latest) · [MIT License](LICENSE)

## English

A small macOS app for switching the **system timezone**. Choose any timezone available on your Mac, and keep one or two favorites. One city is enough to start.

### Requirements and permissions

| Item | Requirement |
| --- | --- |
| macOS | 13.0 or newer |
| Mac | Apple Silicon (M series) or Intel; one universal download |
| Additional software | No Xcode, Python, or other runtime installation needed to use the release app |
| First launch | The current release is not notarized; follow the Open Anyway steps below if macOS blocks it |
| Switching timezones | macOS administrator authorization; the system prompt may identify `osascript` |

Actual app launch and privileged timezone switching have been verified on **macOS 15.5**. Other macOS versions in the supported range have not each been tested on a physical Mac.

Enter administrator credentials only in the macOS system prompt; the app does not save passwords. A standard account needs available administrator credentials to approve a switch. TZswitch does not require Accessibility, Screen Recording, Full Disk Access, Location Services, camera, or microphone permissions. Favorites are stored locally.

### Use

See the **[App user guide (中文)](docs/USER_GUIDE.zh-CN.md)** for installation, first-run setup, UTC search examples, navigation, authorization, and troubleshooting.

1. Download the universal ZIP from Releases, extract it, and drag **TZswitch.app** into Applications.
2. On first launch, choose a favorite city in either empty slot to get started. The second city is optional. Search the global catalog, grouped by current UTC offset from lowest to highest; the current group header stays pinned while scrolling. Use the right-hand UTC index to jump between groups. Counts distinguish current UTC-offset groups from deduplicated city entries. Offset searches accept `utc9`, `utc-8`, and `utc5:30`. Choosing a city immediately requests macOS administrator authorization to switch. The new favorite is saved only after verified success; cancellation or failure preserves the previous favorite and system timezone. Click Close or press Esc to return without choosing.
3. Approve the macOS administrator prompt triggered by choosing the city. The app verifies and applies it immediately; no second card click is needed.
4. For later changes, click the card body to apply a favorite or its right-hand `>` area to change the city. The green border marks the active timezone. Close the window to quit; the applied system timezone stays in effect.

The current interface is in Chinese. Search accepts localized Chinese city names, English city names, IANA IDs such as `America/Los_Angeles`, and offsets such as `UTC+05:45`. Beijing and 北京时间 resolve to Beijing / Shanghai (`Asia/Shanghai`). Compatibility IDs for the same city with identical full timezone rules appear once, while their old names remain searchable.

The release uses an **ad hoc signature**. It is not Developer ID signed or notarized, so macOS may require approval in **System Settings → Privacy & Security** on first launch. Only approve a download you trust. You can also build from source below.

#### If macOS says Apple cannot verify TZswitch

After confirming that the package came from [this repository's Releases](https://github.com/jockerxb/TZswitch/releases/latest):

1. Click **Done** in the blocked-app dialog.
2. Open **System Settings → Privacy & Security**, then scroll down to the notice about TZswitch.
3. Click **Open Anyway**, authenticate as prompted, then click **Open**.

macOS remembers this exception for the app. See [Apple's official instructions](https://support.apple.com/102445).

### Behavior

- One or two customizable, distinct favorite timezones. New installs start with empty slots; choosing one city completes setup. A single favorite stays usable after reopening, and existing choices are preserved.
- The timezone catalog and daylight saving rules come from macOS [Foundation TimeZone](https://developer.apple.com/documentation/foundation/timezone). The list follows the system timezone database rather than a bundled city list.
- A manual switch disables automatic timezone selection to keep macOS from switching back based on location. Network time synchronization is left alone.
- Launching, dismissing the picker without choosing, and quitting do **not** change the system timezone. Choosing a city or clicking a card requests authorization to switch. Quitting keeps the last applied system setting; reopening reads the actual current setting.
- No menu bar status item and no background service. Closing the window quits the app. Complete or cancel an active authorization before quitting.
- No telemetry, account, or external runtime dependencies. Timezone operations make no network requests. The GitHub link at the top right opens the project in your default browser only when clicked, for source code, updates, or issue reporting.

### Build and test

Install Apple's Xcode Command Line Tools (`xcode-select --install`), then:

```sh
git clone https://github.com/jockerxb/TZswitch.git
cd TZswitch
./build.sh                 # universal app → dist/TZswitch.app
./test.sh                  # no system timezone modifications
./package.sh               # build + test + release ZIP and SHA256SUMS.txt
```

For a faster local build, use `./build.sh arm64` or `./build.sh x86_64`. Sources use Swift, SwiftUI, and AppKit. The icon tool uses Python 3's standard library and native CoreGraphics. An Intel build can be cross-compiled on Apple Silicon; running it requires a compatible Mac or Rosetta.

Tests cover DST boundaries, fractional offsets, global search and UTC grouping, first-run setup, legacy preference migration, saved preferences, invalid input, verified switching results, rollback transactions, and all 11 ICNS representations. Selection-flow tests cover cancellation, execution and verification failures, success, first-run setup, and reload persistence. Transaction and selection-flow tests use fake OS commands and never request administrator privileges. AppleScript syntax checks are skipped if the environment cannot load Standard Additions; the app also compiles its authorization script before use. Real privileged switching and visual checks require a Mac and manual authorization.

### Implementation

`Sources/TimezoneCore.swift` owns the validated timezone catalog, preferences, system snapshot, and switching transaction. `Sources/AppModel.swift` owns authorization flow and preference commits after success; `Sources/main.swift` contains the UI and app lifecycle. Only explicit switch actions run the administrator script. IDs must be in the system allowlist and are shell-quoted at the command boundary. Failed transactions attempt to restore the previous timezone and automatic-selection setting.

GitHub Actions builds, tests, and packages pushes and pull requests. A `v*` tag publishes a release after those checks pass; the tag must match the version in `Info.plist`.

### Contribute

Open an issue with your macOS version and a reproducible example, or submit a pull request. Run `./package.sh` before proposing a release. Please avoid adding passwords, personal preferences, signing credentials, or local build outputs to the repository.

If TZswitch helps you, a [Star](https://github.com/jockerxb/TZswitch) is welcome—it bookmarks the project and supports its continued improvement.

---

<a id="chinese"></a>

## 中文说明

一个轻量的 macOS **系统时区切换工具**。支持 Mac 上的全球时区，可保存一到两个常用时区，设置一个即可使用。

[English](#english) · [App 使用说明](docs/USER_GUIDE.zh-CN.md) · [下载最新版](https://github.com/jockerxb/TZswitch/releases/latest)

### 安装要求与权限

| 项目 | 要求 |
| --- | --- |
| macOS | **13.0 及以上** |
| Mac 芯片 | Apple Silicon（M 系列）和 Intel，同一个通用安装包 |
| 额外软件 | 使用 Release 安装包不需要安装 Xcode、Python 或其他运行依赖 |
| 首次打开 | 当前版本尚未公证；若被系统拦截，按下方“仍要打开”步骤处理 |
| 切换时区 | 需要 macOS 管理员授权，系统弹窗可能显示 `osascript` |

目前已在 **macOS 15.5** 上完成实际启动和管理员授权切换验证；支持范围内的其他系统版本尚未逐一实机测试。

管理员密码仅在 macOS 系统弹窗中输入，App 不保存密码。普通账号需要可用的管理员凭据才能批准切换。**不需要辅助功能、屏幕录制、完全磁盘访问、定位、相机或麦克风权限。** 常用城市只保存在本机。

### 使用

1. 下载 Release 中的 universal ZIP，解压后将 **TZswitch.app** 拖进“应用程序”，即可从启动台启动。
2. 首次打开时，点击任意一个“点击设置常用城市”入口，搜索城市或输入 `utc9`、`utc-8` 等偏移，然后选择城市。设置一个即可使用，第二个可选。
3. 选中城市后会自动请求 macOS 管理员授权，确认并验证成功后即生效，无需再点卡片。取消授权或失败时保留原城市。
4. 日常点击卡片主体切换，右侧 `>` 用于更换城市；绿色边框表示当前使用的时区。关闭主窗口即可退出，系统时区继续保留。

安装、首次设置、搜索示例、UTC 导航、取消授权及常见问题，请查看 **[App 使用说明](docs/USER_GUIDE.zh-CN.md)**。

支持中文城市名、英文城市名、IANA 标识（如 `Asia/Shanghai`）及 UTC 偏移（如 `UTC+05:45`）搜索。北京、Beijing、北京时间均可找到“北京 / 上海”（`Asia/Shanghai`）。同城且完整时区规则一致的兼容名称合并展示，旧名称仍可搜索。

当前 Release 使用 **ad hoc 签名**，尚未经过 Developer ID 签名与 Apple 公证。首次运行可能需要在“系统设置 → 隐私与安全性”中允许打开。请确认下载来源，也可以按下方说明自行构建。

#### 首次打开提示“Apple 无法验证 TZswitch”

<img src="docs/images/macos-unverified-app.png" width="420" alt="macOS 提示未打开 TZswitch，Apple 无法验证 App">

确认安装包来自[本仓库 Releases](https://github.com/jockerxb/TZswitch/releases/latest) 后：

1. 在拦截弹窗中点击 **“完成”**。
2. 打开 **系统设置 → 隐私与安全性**，向下找到 TZswitch 被阻止的提示。
3. 点击 **“仍要打开”**，按系统提示授权，再点击 **“打开”**。

系统会记住对该 App 的允许，之后可以正常启动。操作依据见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

### 时区如何保留

- 新用户没有默认城市，首次打开时设置一个常用城市即可结束引导；可按需再添加第二个不同的城市。只保存一个城市时，重启后也可继续使用。旧版已保存的选择会保留，偏好只保存在本机。
- 全球时区及夏令时规则来自 macOS 系统数据库，随系统更新。
- 手动切换时会关闭“自动设置时区”，避免系统根据位置改回；不影响自动校准网络时间。
- 启动、关闭选择面板和退出不会修改系统时区；选择新城市或点击卡片会请求授权后切换。退出后保留已设置的时区，再次打开时读取系统实际状态。
- 无顶部菜单栏常驻图标，无后台服务。关闭窗口即退出；授权过程中需先完成或取消授权。
- 无账号、遥测或第三方运行依赖；时区功能不发起网络请求。标题右侧的 GitHub 入口仅在点击后通过默认浏览器打开项目首页，可查看源码、下载更新或反馈问题。

### 从源码构建

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

### 开发与发布

`Sources/TimezoneCore.swift` 负责目录、偏好、系统读取和切换事务；`Sources/AppModel.swift` 负责授权流程及成功后的偏好提交；`Sources/main.swift` 负责界面与生命周期。时区标识只允许系统数据库内的值，执行前再次进行 shell 转义。切换失败时尝试恢复原时区与自动时区设置。

GitHub Actions 在 push 和 pull request 时自动构建、测试并打包；推送 `v*` 标签会在检查通过后发布 Release，标签必须与 `Info.plist` 中的版本一致。

欢迎提交 issue 或 pull request。发布前运行 `./package.sh`，请勿提交管理员密码、私人偏好、签名凭证和本机构建产物。

如果 TZswitch 对你有帮助，欢迎给项目一个 [Star](https://github.com/jockerxb/TZswitch)，方便收藏，也支持项目继续改进。
