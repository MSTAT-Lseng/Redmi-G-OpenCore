#!/usr/bin/env python3
"""
生成 macOS display override，为 2560x1600 面板添加更大的 HiDPI 逻辑分辨率。

依据 nullmoth/nvidia-macos-driver issue #455 / #360：
  - scale-resolutions 每项必须 12 字节，大端序
  - 内容是「栅格(backing)尺寸」，不是逻辑尺寸：BE32(2w) BE32(2h) BE32(1)
  - 写成逻辑尺寸 BE32(w)+BE32(h)+1 只会得到 density-1 的普通模式
  - 目录/文件名必须用十六进制 ID

配套前提：
  - boot-arg nvfbhidpi=1（已配置），把栅格上限提到 4x（5120x3200）
  - 驱动需给缩放模式带上 kDisplayModeValidForHiResFlag（3.0 版应已包含）

用法:
    python3 make_display_override.py <输出目录>
"""

import sys
import os
import plistlib

# 面板原生
NATIVE_W, NATIVE_H = 2560, 1600

# 目标 HiDPI 档位：(逻辑宽, 逻辑高)
# 栅格 = 逻辑 * 2（整数倍缩放，文字清晰）
TARGETS = [
    (1600, 1000),   # 栅格 3200x2000  ~1.06 Gpx/s @165Hz  通过
    (1680, 1050),   # 栅格 3360x2100  ~1.16 Gpx/s @165Hz  通过（issue 实测边界）
    (1440, 900),    # 栅格 2880x1800  ~0.86 Gpx/s @165Hz  通过
    (1920, 1200),   # 栅格 3840x2400  ~1.52 Gpx/s @165Hz  被拒，需 60Hz
]

# 像素率上限经验值（issue #360 watchthelight 汇总）
PIXELRATE_OK = 1.16e9
PIXELRATE_BAD = 1.37e9


def entry_for(logical_w, logical_h):
    """生成 12 字节 scale-resolutions 条目：BE32(2w) BE32(2h) BE32(1)"""
    bw = logical_w * 2
    bh = logical_h * 2
    return (
        bw.to_bytes(4, "big")
        + bh.to_bytes(4, "big")
        + (1).to_bytes(4, "big")
    )


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."

    entries = []
    print(f"面板原生: {NATIVE_W}x{NATIVE_H}")
    print(f"栅格上限 (nvfbhidpi=1): {NATIVE_W*2}x{NATIVE_H*2}")
    print()
    print(f"{'逻辑':>12} {'栅格':>12} {'165Hz 像素率':>16} {'判定':>10}  12 字节条目")
    print("-" * 92)

    for lw, lh in TARGETS:
        raw = entry_for(lw, lh)
        entries.append(raw)
        bw, bh = lw * 2, lh * 2
        rate = bw * bh * 165
        if rate <= PIXELRATE_OK:
            verdict = "通过"
        elif rate >= PIXELRATE_BAD:
            verdict = "需降频"
        else:
            verdict = "边界"
        print(f"{lw}x{lh:<6} {bw}x{bh:<6} {rate/1e9:>13.3f} G {verdict:>10}  {raw.hex(' ')}")

    print()
    # 校验字节序
    print("字节序自检（应为大端，宽高数值与栅格一致）:")
    for raw, (lw, lh) in zip(entries, TARGETS):
        w = int.from_bytes(raw[0:4], "big")
        h = int.from_bytes(raw[4:8], "big")
        f = int.from_bytes(raw[8:12], "big")
        ok = (w == lw * 2 and h == lh * 2 and f == 1)
        print(f"  {raw.hex(' ')} -> 栅格 {w}x{h} flags={f} {'OK' if ok else '错误'}")

    # 生成 plist
    override = {
        "DisplayProductName": "CSOT T3",
        "scale-resolutions": entries,
    }

    path = os.path.join(outdir, "DisplayProductID-1616")
    with open(path, "wb") as f:
        plistlib.dump(override, f, fmt=plistlib.FMT_XML)

    print()
    print(f"已生成: {path}")
    print()
    print("内容:")
    import subprocess
    print(subprocess.run(["plutil", "-p", path], capture_output=True, text=True).stdout)


if __name__ == "__main__":
    main()
