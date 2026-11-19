#!/bin/bash
# 安装 display override（HiDPI scale-resolutions）
#
# 依据 nullmoth/nvidia-macos-driver issue #455 / #360 / #354
# 目录和文件名必须用十六进制 ID
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-e6f"
SRC="$HERE/DisplayProductID-1616"
DST="$DIR/DisplayProductID-1616"

if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root: sudo $0"
    exit 1
fi

echo "== 安装前 =="
ls -la "$DIR" 2>/dev/null || echo "  (目录不存在，将创建)"

# 备份已有文件（如果有）
if [ -f "$DST" ]; then
    BK="$DST.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$DST" "$BK"
    echo "已备份原文件: $BK"
fi

mkdir -p "$DIR"
cp "$SRC" "$DST"
chown -R root:wheel "$DIR"
chmod 755 "$DIR"
chmod 644 "$DST"

echo
echo "== 安装后 =="
ls -la "$DIR"
echo
echo "-- 文件内容 --"
plutil -p "$DST"
echo
echo "-- 字节校验（应为 12 字节大端，栅格尺寸）--"
python3 - "$DST" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], 'rb'))
for i, e in enumerate(d.get('scale-resolutions', [])):
    w = int.from_bytes(e[0:4], 'big')
    h = int.from_bytes(e[4:8], 'big')
    f = int.from_bytes(e[8:12], 'big')
    print(f'  [{i}] {e.hex()} len={len(e)} -> 栅格 {w}x{h} 逻辑 {w//2}x{h//2} flags={f}')
PY

echo
echo "完成。重启后生效。"
echo "回滚: sudo rm $DST && 重启"
