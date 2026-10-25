#!/bin/zsh
set -eu
cd "${0:A:h}"
/usr/bin/python3 Tests/localization-audit.py
ARCH="${1:-universal}"
case "$ARCH" in
    universal) ARCHS=(arm64 x86_64) ;;
    arm64|x86_64) ARCHS=("$ARCH") ;;
    *) print -u2 'Usage: ./build.sh [universal|arm64|x86_64]'; exit 2 ;;
esac
BUILD="$PWD/.build"
APP="$PWD/dist/TZswitch.app"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"
for CPU in "${ARCHS[@]}"; do
    /usr/bin/xcrun swiftc -O -parse-as-library -module-cache-path "$BUILD/module-cache-$CPU" \
        -target "$CPU-apple-macosx13.0" Sources/AppLanguage.swift Sources/TimezoneCore.swift Sources/AppModel.swift Sources/StatusItemPosition.swift Sources/main.swift \
        -o "$BUILD/TZswitch-$CPU" -framework SwiftUI -framework AppKit
done
if [[ "$ARCH" == universal ]]; then
    /usr/bin/lipo -create "$BUILD/TZswitch-arm64" "$BUILD/TZswitch-x86_64" -output "$APP/Contents/MacOS/TZswitch"
else
    /bin/cp "$BUILD/TZswitch-$ARCH" "$APP/Contents/MacOS/TZswitch"
fi
/bin/cp Info.plist "$APP/Contents/Info.plist"
ICON_FILE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' Info.plist)
/usr/bin/python3 build-icon.py
/bin/cp "$BUILD/$ICON_FILE" "$APP/Contents/Resources/$ICON_FILE"
/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/touch "$APP"
print "Built $ARCH: $APP"
