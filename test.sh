#!/bin/zsh
set -eu
cd "${0:A:h}"
/usr/bin/python3 Tests/localization-audit.py
BUILD="$PWD/.build"
mkdir -p "$BUILD"
# This integration check needs a logged-in graphical macOS session.
if [[ "${1:-}" == --native-status-item ]]; then
    /usr/bin/xcrun swiftc -parse-as-library -module-cache-path "$BUILD/test-module-cache" \
        Sources/StatusItemPosition.swift Tests/status-position-native.swift \
        -o "$BUILD/status-position-native-tests" -framework AppKit
    "$BUILD/status-position-native-tests"
    exit
fi
/usr/bin/xcrun swiftc -module-cache-path "$BUILD/test-module-cache" Sources/AppLanguage.swift Sources/TimezoneCore.swift Tests/main.swift -o "$BUILD/core-tests"
"$BUILD/core-tests" "$BUILD"
/usr/bin/xcrun swiftc -parse-as-library -module-cache-path "$BUILD/test-module-cache" \
    Sources/AppLanguage.swift Sources/TimezoneCore.swift Sources/AppModel.swift Tests/selection.swift -o "$BUILD/selection-tests" -framework AppKit
"$BUILD/selection-tests"
/usr/bin/xcrun swiftc -parse-as-library -module-cache-path "$BUILD/test-module-cache" \
    Sources/AppLanguage.swift Sources/TimezoneCore.swift Sources/AppModel.swift Tests/language.swift \
    -o "$BUILD/language-tests" -framework AppKit
"$BUILD/language-tests"
/usr/bin/xcrun swiftc -parse-as-library -module-cache-path "$BUILD/test-module-cache" \
    Sources/StatusItemPosition.swift Tests/status-position.swift -o "$BUILD/status-position-tests"
"$BUILD/status-position-tests"
/usr/bin/python3 Tests/transaction.py "$BUILD"
if /usr/bin/osacompile -o "$BUILD/standard-additions-probe.scpt" -e 'do shell script "true"' 2>"$BUILD/osa-probe.log"; then
    for city in LUN LAX KTM CHT UTC; do
        /usr/bin/osacompile -o "$BUILD/$city.scpt" "$BUILD/$city.applescript"
    done
    print 'PASS Administrator AppleScripts compile'
else
    print 'SKIP Standard Additions unavailable in this sandbox. The App also checks compilation before authorization.'
fi
/usr/bin/python3 build-icon.py
/usr/bin/python3 Tests/icon-dimensions.py
