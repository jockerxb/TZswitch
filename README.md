<p align="center"><img src="Assets/logo.png" width="120" alt="TZswitch icon"></p>

# TZswitch

[English](#english) · [中文说明](#chinese) · [App 使用说明](docs/USER_GUIDE.zh-CN.md) · [Download / 下载](https://github.com/jockerxb/TZswitch/releases/latest) · [MIT License](LICENSE)

## English

A small macOS app for **switching the system timezone** and **keeping a separate local-time clock** in the menu bar. Save up to three favorite cities; one is enough to start.

### When to use TZswitch

**Use one timezone for the system, while keeping local time easy to see.** When a work setup or an app requires a timezone matching a VPN region, switching macOS can make the usual local clock inconvenient to read. TZswitch combines system-timezone switching with an independent menu-bar clock so you do not need to keep switching back just to check the time.

| Scenario | How TZswitch helps |
| --- | --- |
| An app or work setup needs the system timezone to match a VPN region | Save the region's city as a favorite and switch manually after connecting the VPN |
| You still need local time after switching | Choose your local city for the backup clock; the menu bar keeps its weekday and HH:mm visible |
| Travel or work across regions | Switch among saved cities and keep a home or colleague's timezone visible separately |

**Example:** You normally use Beijing / Shanghai time, but a VPN-related workflow needs Los Angeles time. Select Los Angeles as a favorite and approve the system switch. Then enable the backup clock and manually choose Beijing / Shanghai. macOS uses Los Angeles time, while the menu bar shows your local weekday and time. Leaving the main interface keeps both; choosing **“退出北京 / 上海时间”** stops only the backup clock.

TZswitch does not detect or control a VPN. It changes the system timezone, not the IP address or physical location; changing the timezone alone does not guarantee any other app's behavior.

### Features

| Feature | What it does |
| --- | --- |
| Favorite timezone switching | Save up to 3 cities, starting with just one; click a card to request administrator authorization and switch the system timezone |
| Global city and timezone search | Search Chinese or English city names, IANA IDs, or UTC offsets such as `utc9`; jump through UTC groups with the side index |
| Independent backup clock | Off by default; manually choose a city when enabling it, then see only weekday and HH:mm in the menu bar, without changing the system timezone or requesting administrator authorization |
| Favorite management | Add cities as needed, use `>` to change a city, or delete from the edit panel / card context menu; at least one favorite is kept |
| Settings that stay in effect | Applied system timezones remain after leaving the app; an enabled backup clock stays visible after closing or quitting the main interface and can be stopped independently |
| Menu-bar positioning | Hold Command (⌘) and drag the backup time to the desired position |

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
2. Click **“点击设置常用城市”** to choose the first city. Choosing a favorite requests macOS administrator authorization immediately; it is saved only after verified success. Cancellation preserves the previous favorite and system timezone.
3. Click **“添加常用时区”** to add the second or third city when needed. Click a card body to switch, or its right-hand `>` to change that city. The green border marks the active system timezone.
4. Optionally turn on **“备用时区显示”**, then manually choose a city. Only after selection does the menu bar show a clock such as **“周日 18:22”**. Canceling the picker leaves the switch off. Backup-city selection does not change the system timezone or request administrator authorization.
5. Hold **Command (⌘)** and drag the menu-bar time to move it, for example to the left of Control Center. Its position is managed by macOS; toggling the display reuses the same status item.
6. With the backup clock on, closing the window or using Quit / Command-Q hides the main interface while the clock continues. Click the menu-bar time for **“打开 TZswitch”**, **“更换备用时区…”**, or **“退出[city]时间”**. Stopping the clock never changes the system timezone. With the backup clock off, closing the window or quitting exits the app normally.

To remove a mistaken favorite, click its right-hand `>` and choose **“删除此常用时区”**, or right-click the card and choose Delete. Removal is available only with two or three favorites; at least one is kept. Remaining cities are renumbered, and the system timezone and backup clock stay unchanged.

The current interface is in Chinese. Search accepts localized Chinese city names, English city names, IANA IDs such as `America/Los_Angeles`, and offsets such as `UTC+05:45`. Beijing and 北京时间 resolve to Beijing / Shanghai (`Asia/Shanghai`). Compatibility IDs for the same city with identical full timezone rules appear once, while their old names remain searchable.

The release uses an **ad hoc signature**. It is not Developer ID signed or notarized, so macOS may require approval in **System Settings → Privacy & Security** on first launch. Only approve a download you trust. You can also build from source below.

#### If macOS says Apple cannot verify TZswitch

After confirming that the package came from [this repository's Releases](https://github.com/jockerxb/TZswitch/releases/latest):

1. Click **Done** in the blocked-app dialog.
2. Open **System Settings → Privacy & Security**, then scroll down to the notice about TZswitch.
3. Click **Open Anyway**, authenticate as prompted, then click **Open**.

macOS remembers this exception for the app. See [Apple's official instructions](https://support.apple.com/102445).

### Behavior

- Up to three distinct favorite cities. New installs have no preset cities and show one setup entry. The second and third are added manually; existing choices are preserved on upgrade.
- The timezone catalog and daylight saving rules come from macOS [Foundation TimeZone](https://developer.apple.com/documentation/foundation/timezone). The list follows the system timezone database rather than a bundled city list.
- A manual switch disables automatic timezone selection to keep macOS from switching back based on location. Network time synchronization is left alone.
- Launching, dismissing the picker without choosing, and quitting do **not** change the system timezone. Choosing a city or clicking a card requests authorization to switch. Quitting keeps the last applied system setting; reopening reads the actual current setting.
- The backup clock is off by default and has no preset city. Each time it is turned on, manually select a city; changing system timezones does not change this clock. While enabled, closing or quitting the main interface keeps the clock running in the menu bar. Stopping the clock also exits the process if the main window is hidden. No helper service or automatic login launch is installed; after a restart, open the app again. Complete or cancel an active system authorization before leaving the main interface.
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

一个轻量的 macOS 工具，提供 **常用时区切换** 和 **备用时区显示**。最多保存 3 个常用城市，设置一个即可使用；切换系统时区后，仍可在菜单栏查看另一个城市的本地时间。

[English](#english) · [App 使用说明](docs/USER_GUIDE.zh-CN.md) · [下载最新版](https://github.com/jockerxb/TZswitch/releases/latest)

### 应用场景

**系统按需要切换时区，本地时间仍然随时可见。** 一些软件或工作环境在配合 VPN 使用时，需要把系统时区手动切换到 VPN 对应的地区。切换后，Mac 的系统时钟也随之变化，查看原来的本地时间就不方便了。TZswitch 将“常用时区切换”和“备用时区显示”放在一起，让你不必为了看本地时间而反复切回系统时区。

| 场景 | 使用方式 |
| --- | --- |
| 软件或工作环境需要时区与 VPN 地区对应 | 把对应地区的城市加入常用时区，连接 VPN 后手动切换系统时区 |
| 切换系统时区后，仍需要查看当地／本地时间 | 开启备用时区显示并选择本地城市，在菜单栏查看星期和时分 |
| 出差、旅行或跨地区协作 | 在常用城市间切换，同时保留家乡或同事所在城市的时间 |

**例如：** 你平时使用北京／上海时间，某个配合 VPN 的工作流程需要洛杉矶时区。把洛杉矶加入常用时区，点击并完成系统授权；再打开备用显示，手动选择北京／上海。此时系统使用洛杉矶时间，顶部菜单栏仍可查看北京／上海的星期和时间。退出主界面后两者都保留；选择 **“退出北京 / 上海时间”** 只停止备用时钟。

TZswitch 不检测或控制 VPN，也不改变 IP 地址或实际位置；仅切换时区不能保证其他软件的行为。

### 基础功能

| 功能 | 说明 |
| --- | --- |
| 常用时区切换 | 最多保存 3 个常用城市，一个即可开始；点击卡片并完成管理员授权后切换系统时区 |
| 全球城市与时区搜索 | 支持中文／英文城市名、IANA 标识、`utc9` 等偏移搜索，以及右侧 UTC 快速导航 |
| 独立备用时钟 | 默认关闭，开启时必须手动选城；菜单栏只显示星期和时分，不修改系统时区、不需要管理员授权 |
| 常用城市管理 | 按需添加，点击 `>` 更换；支持面板删除及右键删除，至少保留一个常用城市 |
| 退出后继续保留 | 已生效的系统时区始终保留；备用开启时退出主界面仍显示，备用时间可单独退出 |
| 菜单栏位置调整 | 按住 Command（⌘）拖动备用时间，放到便于查看的位置 |

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

1. 下载 Release 中的 universal ZIP，解压后将 **TZswitch.app** 拖进“应用程序”。
2. 首次打开时，点击绿色的 **“点击设置常用城市”**，搜索并选择城市。系统授权、验证成功后立即生效并保存；取消授权或失败时保留原城市。
3. 需要更多常用城市时，点击 **“添加常用时区”**，手动添加第 2、第 3 个。日常点击卡片主体切换，右侧 `>` 更换城市；绿色边框表示系统当前时区。
4. 如需查看本地或另一城市时间，打开 **“备用时区显示”**，手动选择城市后，菜单栏显示 **“周日 18:22”** 这样的星期和时分。取消选择则保持关闭；此操作不切换系统时区，也不需要管理员授权。
5. 按住 **Command（⌘）**，再拖动顶部备用时间，可移到“控制中心”图标左侧等位置。位置由 macOS 管理；开关切换时复用同一菜单栏项目。
6. **备用关闭**：关闭窗口或退出 App 后，仅保留已经生效的系统时区。**备用开启**：关闭窗口或退出主界面（含 Command-Q）后，系统时区与菜单栏备用时钟都保留。点击备用时间可打开主界面、更换备用城市或选择 **“退出××时间”**；停止备用时钟不改变系统时区。

误添加的常用城市可点右侧 `>`，在面板底部选择 **“删除此常用时区”**，也可右键卡片删除。仅在有 2～3 个城市时显示删除入口，至少保留 1 个。删除后自动重新编号，不改变系统时区或备用时钟。

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

- 新用户没有默认城市，首次只显示一个设置入口；设置一个即可使用，第 2、第 3 个城市需要用户主动添加。常用城市不能重复，升级保留原有选择，偏好只保存在本机。
- 全球时区及夏令时规则来自 macOS 系统数据库，随系统更新。
- 手动切换时会关闭“自动设置时区”，避免系统根据位置改回；不影响自动校准网络时间。
- 启动、关闭选择面板和退出不会修改系统时区；选择新城市或点击卡片会请求授权后切换。退出后保留已设置的时区，再次打开时读取系统实际状态。
- 备用时钟默认关闭、不预设城市。每次开启都要手动选择城市，关闭时不需要选择。开启后退出主界面仍继续显示；从菜单选择“退出××时间”后停止显示，若主窗口已隐藏则同时结束进程。没有独立后台服务，也不会自动开机启动；重启电脑后需要重新打开 App。系统授权期间需先完成或取消授权，再退出主界面。
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
