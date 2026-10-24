"""Check the actual PNG payload and optical bounds of every ICNS representation."""
from pathlib import Path
import json
import plistlib
import struct
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
build = (root / ".build").resolve()
normalizer = build / "normalize-icon"
info = plistlib.loads((root / "Info.plist").read_bytes())
data = (build / info["CFBundleIconFile"]).read_bytes()
assert data[:4] == b"icns"
assert struct.unpack(">I", data[4:8])[0] == len(data)
expected = {"icp4": 16, "icp5": 32, "icp6": 64, "ic07": 128, "ic08": 256,
            "ic09": 512, "ic10": 1024, "ic11": 32, "ic12": 64, "ic13": 256, "ic14": 512}
records = {}
cursor = 8
while cursor < len(data):
    code = data[cursor:cursor + 4].decode("ascii")
    length = struct.unpack(">I", data[cursor + 4:cursor + 8])[0]
    png = data[cursor + 8:cursor + length]
    assert png[:8] == b"\x89PNG\r\n\x1a\n", code
    width, height = struct.unpack(">II", png[16:24])
    assert width == height == expected[code], (code, width, height)
    path = build / f"verify-{code}.png"
    path.write_bytes(png)
    record = json.loads(subprocess.check_output([str(normalizer), "inspect", str(path)], text=True))
    ideal = width * 824 / 1024
    # At 16 px, antialiased edge pixels are visible before becoming fully opaque.
    # Use half-coverage edges to measure the rendered silhouette at every size.
    assert abs(record["visibleBodyWidth"] - ideal) <= 1.1, (code, record)
    assert abs(record["visibleBodyHeight"] - ideal) <= 1.1, (code, record)
    assert abs(record["visibleBodyX"] - (width - record["visibleBodyWidth"]) / 2) <= 1.1, (code, record)
    assert abs(record["visibleBodyY"] - (height - record["visibleBodyHeight"]) / 2) <= 1.1, (code, record)
    assert record["cornerAlpha"] == 0 and record["centerAlpha"] >= 250, (code, record)
    records[code] = record
    print(f"PASS {code}: {width}×{height}, 图形 {record['visibleBodyWidth']}×{record['visibleBodyHeight']}，透明边距正确")
    cursor += length
assert set(records) == set(expected)
(build / "icon-size-report.json").write_text(json.dumps(records, indent=2, ensure_ascii=False))
print("PASS 全部 11 个 ICNS 图像表示的像素尺寸、主体比例、居中及透明通道")
