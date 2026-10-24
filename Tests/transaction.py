"""Execute the real transaction shell against fake OS commands; never changes macOS."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile

build = Path(sys.argv[1]).resolve()
shim = '''#!/bin/sh
set -eu
state="$TZ_TEST_STATE"
case "${0##*/}" in
  defaults)
    case "$1" in
      read) test -f "$state/auto" || exit 1; cat "$state/auto" ;;
      write) case "$5" in true) printf 1 > "$state/auto" ;; false) printf 0 > "$state/auto" ;; esac ;;
      delete) rm -f "$state/auto" ;;
    esac ;;
  systemsetup)
    if test -f "$state/fail" && test "$2" != Asia/Kolkata; then exit 1; fi
    printf '%s' "$2" > "$state/zone" ;;
  readlink) printf '/var/db/timezone/zoneinfo/%s' "$(cat "$state/zone")" ;;
esac
'''
with tempfile.TemporaryDirectory(prefix="timezone-transaction-") as temp:
    state = Path(temp)
    for name in ("defaults", "systemsetup", "readlink"):
        exe = state / name
        exe.write_text(shim)
        exe.chmod(0o755)
    env = dict(os.environ, TZ_TEST_STATE=temp)
    for city, zone in (("LUN", "Africa/Lusaka"), ("LAX", "America/Los_Angeles"), ("KTM", "Asia/Kathmandu"), ("CHT", "Pacific/Chatham"), ("UTC", "Etc/UTC")):
        source = (build / f"{city}.sh").read_text()
        for original, fake in (("/usr/bin/defaults", "defaults"), ("/usr/sbin/systemsetup", "systemsetup"), ("/usr/bin/readlink", "readlink")):
            source = source.replace(original, f"'{state / fake}'")
        script = state / "transaction.sh"
        script.write_text(source)
        subprocess.run(["/bin/sh", "-n", str(script)], check=True)
        for old_auto in ("1", "0", None):
            for fail in (False, True):
                (state / "zone").write_text("Asia/Kolkata")
                (state / "auto").unlink(missing_ok=True)
                if old_auto is not None:
                    (state / "auto").write_text(old_auto)
                (state / "fail").unlink(missing_ok=True)
                if fail:
                    (state / "fail").touch()
                result = subprocess.run(["/bin/sh", str(script)], env=env, text=True, capture_output=True)
                actual_zone = (state / "zone").read_text()
                actual_auto = (state / "auto").read_text() if (state / "auto").exists() else None
                if fail:
                    assert result.returncode != 0, result
                    assert actual_zone == "Asia/Kolkata", actual_zone
                    assert actual_auto == old_auto, (old_auto, actual_auto)
                else:
                    assert result.returncode == 0, result.stderr
                    assert actual_zone == zone, actual_zone
                    assert actual_auto == "0", actual_auto
                    assert result.stdout == f"VERIFIED:{zone}", result.stdout
                print(f"PASS {city} automatic={old_auto} {'失败恢复原设置' if fail else '切换并回读'}")
print("PASS 30 项切换事务测试，无系统设置被修改")
