#!/bin/zsh
set -eu
cd "${0:A:h}"
BUILD="$PWD/.build"
mkdir -p "$BUILD"
/usr/bin/xcrun swiftc -module-cache-path "$BUILD/test-module-cache" Sources/TimezoneCore.swift Tests/main.swift -o "$BUILD/core-tests"
"$BUILD/core-tests" "$BUILD"
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
