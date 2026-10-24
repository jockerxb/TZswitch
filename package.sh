#!/bin/zsh
set -eu
cd "${0:A:h}"
./build.sh universal
./test.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
ARCHIVE="TZswitch-$VERSION-macOS-universal.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/TZswitch.app "dist/$ARCHIVE"
cd dist
/usr/bin/shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt
print "Packaged: $PWD/$ARCHIVE"
