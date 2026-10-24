<p align="center"><img src="Assets/logo.png" width="120" alt="TZswitch icon"></p>

# TZswitch

A small macOS app for switching the **system timezone**. Choose any timezone available on your Mac, and keep two favorites for quick switching.

[中文说明](README.zh-CN.md) · [Download](https://github.com/jockerxb/TZswitch/releases/latest) · [MIT License](LICENSE)

## Use

1. Download the universal ZIP from Releases, extract it, and drag **TZswitch.app** into Applications.
2. On first launch, click the cards numbered 1 and 2 to choose your favorite cities. Search the global catalog, grouped by current UTC offset from lowest to highest; the current group header stays pinned while scrolling. Use the right-hand UTC index to jump between groups. Counts distinguish current UTC-offset groups from deduplicated city entries. Offset searches accept `utc9`, `utc-8`, and `utc5:30`. Choosing a city saves the favorite and immediately requests macOS administrator authorization to switch. Cancelling authorization preserves the favorite and leaves the system timezone unchanged. Click Close or press Esc to return without choosing.
3. Click the card body to apply a favorite; click its right-hand `>` area to change the city. The green border marks the active timezone.
4. Approve the macOS administrator prompt. The app reads back the system settings before reporting success. Close the window to quit; standard macOS minimize and fullscreen controls are available.

Requires macOS 13 or newer; the universal app includes Apple Silicon and Intel binaries. The current interface is in Chinese. Search accepts localized Chinese city names, English city names, IANA IDs such as `America/Los_Angeles`, and offsets such as `UTC+05:45`. Beijing and 北京时间 resolve to Beijing / Shanghai (`Asia/Shanghai`). Compatibility IDs for the same city with identical full timezone rules appear once, while their old names remain searchable.

The release uses an **ad hoc signature**. It is not Developer ID signed or notarized, so macOS may require approval in **System Settings → Privacy & Security** on first launch. Only approve a download you trust. You can also build from source below.

## Behavior

- Two customizable, distinct favorite timezones. New installs start with empty slots and a setup guide; existing users keep their saved choices. Partially completed setup is saved, so you can continue after reopening.
- The timezone catalog and daylight saving rules come from macOS [Foundation TimeZone](https://developer.apple.com/documentation/foundation/timezone). The list follows the system timezone database rather than a bundled city list.
- A manual switch disables automatic timezone selection to keep macOS from switching back based on location. Network time synchronization is left alone.
- Launching, dismissing the picker without choosing, and quitting do **not** change the system timezone. Choosing a city or clicking a card requests authorization to switch. Quitting keeps the last applied system setting; reopening reads the actual current setting.
- No menu bar status item and no background service. Closing the window quits the app. Complete or cancel an active authorization before quitting.
- No telemetry, account, network requests, or external runtime dependencies.

## Build and test

Install Apple's Xcode Command Line Tools (`xcode-select --install`), then:

```sh
git clone https://github.com/jockerxb/TZswitch.git
cd TZswitch
./build.sh                 # universal app → dist/TZswitch.app
./test.sh                  # no system timezone modifications
./package.sh               # build + test + release ZIP and SHA256SUMS.txt
```

For a faster local build, use `./build.sh arm64` or `./build.sh x86_64`. Sources use Swift, SwiftUI, and AppKit. The icon tool uses Python 3's standard library and native CoreGraphics. An Intel build can be cross-compiled on Apple Silicon; running it requires a compatible Mac or Rosetta.

Tests cover DST boundaries, fractional offsets, global search and UTC grouping, first-run setup, legacy preference migration, saved preferences, invalid input, verified switching results, rollback transactions, and all 11 ICNS representations. Transaction tests use fake OS commands and never request administrator privileges. AppleScript syntax checks are skipped if the environment cannot load Standard Additions; the app also compiles its authorization script before use. Real privileged switching and visual checks require a Mac and manual authorization.

## Implementation

`Sources/TimezoneCore.swift` owns the validated timezone catalog, preferences, system snapshot, and switching transaction. `Sources/main.swift` contains the UI and app lifecycle. Only explicit switch actions run the administrator script. IDs must be in the system allowlist and are shell-quoted at the command boundary. Failed transactions attempt to restore the previous timezone and automatic-selection setting.

GitHub Actions builds, tests, and packages pushes and pull requests. A `v*` tag publishes a release after those checks pass; the tag must match the version in `Info.plist`.

## Contribute

Open an issue with your macOS version and a reproducible example, or submit a pull request. Run `./package.sh` before proposing a release. Please avoid adding passwords, personal preferences, signing credentials, or local build outputs to the repository.
