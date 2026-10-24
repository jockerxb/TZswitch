"""Package PNG artwork into native macOS ICNS, retaining the original artwork."""
from pathlib import Path
import struct
import subprocess
import plistlib

root = Path(__file__).resolve().parent
iconset = (root / ".build/AppIcon.iconset").resolve()
iconset.mkdir(parents=True, exist_ok=True)
build = iconset.parent
normalizer_source = root / "Scripts/normalize-icon.swift"
normalizer = build / "normalize-icon"
if not normalizer.exists() or normalizer.stat().st_mtime < normalizer_source.stat().st_mtime:
    subprocess.run(["/usr/bin/xcrun", "swiftc", "-O", "-module-cache-path", str(build / "module-cache"), str(normalizer_source), "-o", str(normalizer)], check=True)
normalized = build / "logo-macos-standard.png"
subprocess.run([str(normalizer), "normalize", str(root / "Assets/logo.png"), str(normalized)], check=True)
chunks = []
for code, size in (("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)):
    target = iconset / f"{code}.png"
    subprocess.run([str(normalizer), "resize", str(root / "Assets/logo.png"), str(target), str(size)], check=True, capture_output=True)
    png = target.read_bytes()
    chunks.append(code.encode("ascii") + struct.pack(">I", len(png) + 8) + png)
body = b"".join(chunks)
icon_name = plistlib.loads((root / "Info.plist").read_bytes())["CFBundleIconFile"]
if not icon_name.endswith(".icns"):
    icon_name += ".icns"
(build / icon_name).write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
print(f"已生成原生 {icon_name}")
