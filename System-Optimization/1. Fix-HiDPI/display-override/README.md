# Display Override 方案：解锁更大 HiDPI

> 结论前置：我最初说的「N 卡驱动下屏幕配置文件行不通」是**错的**。
> nullmoth/nvidia-macos-driver 的 issue #354 / #360 / #455 证明 display override
> 正是正确路线。之前行不通是两个具体原因，都已在下面写明。

## 之前为什么失败

### 原因 1：`EDID override` 和 `display override` 是两回事

我在 NVRMFB 反汇编里找到的 `/Library/NullMoth/edid-override/B522-7816.bin`
是驱动私有的 **EDID** 替换机制，它要求文件由 EDID 字段拼名，且读取路径
（`0x8a8c`）有多重前置条件，实际不可达。

而 macOS 标准的 **display override** 是另一套东西：

```
/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<hex>/DisplayProductID-<hex>
```

两者互不相干。我把它们混为一谈了。

### 原因 2：字节序和单位写错（issue #455 的核心）

`scale-resolutions` 的每个条目必须满足：

| 要求 | 说明 |
|---|---|
| 长度 **12 字节** | 16 字节的项会隐藏模式（issue #341） |
| **大端序** | 小端会导致 macOS 读到约 5.37 亿的宽度并丢弃 |
| 内容是**栅格(backing)尺寸** | `BE32(2w) + BE32(2h) + BE32(1)` |
| flags = **1** | flags=2 或 0x02000000 会失败 |
| 路径用**十六进制** | 十进制命名永远匹配不上（issue #360 yes-man-Guo） |

issue #455 里 zhuansunyu123 的错误写法与修正：

```
错误: 200d0000 34080000 02000000   (3360x2100 小端 + flags 2)
正确: 00000d20 00000834 00000001   (3360x2100 大端, flags 1)
```

修正后他在 macOS 15.8.1 上成功看到 1920x1200 / 1680x1050 / 1440x900 / 1280x800。

## 本机参数

| 项目 | 值 |
|---|---|
| 面板原生 | 2560x1600 @165Hz |
| DisplayVendorID | 3695 → `e6f` |
| DisplayProductID | 5654 → `1616` |
| override 路径 | `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-e6f/DisplayProductID-1616` |
| 栅格上限 | 5120x3200（`nvfbhidpi=1` 已生效，日志确认） |

## 已生成的条目

`scale-resolutions` 每项 12 字节，大端，内容为栅格尺寸：

| 逻辑 | 栅格 | 字节 | 165Hz 像素率 | 依据 |
|---|---|---|---|---|
| **1600x1000** | 3200x2000 | `00000c80 000007d0 00000001` | 1.056 G | 目标档 |
| 1680x1050 | 3360x2100 | `00000d20 00000834 00000001` | 1.164 G | issue #360 实测通过 |
| 1440x900 | 2880x1800 | `00000b40 00000708 00000001` | 0.855 G | issue #360 实测通过 |
| 1920x1200 | 3840x2400 | `00000f00 00000960 00000001` | 1.521 G | 165Hz 被拒，60Hz 可用 |

### 像素率限制（issue #360 watchthelight 汇总）

降采样比越大，head scaler 越吃力。同款面板实测：

```
1280x800  1:1      0.676 G  通过
1440x900  1.125x   0.855 G  通过
1680x1050 1.313x   1.164 G  通过
1920x1200 1.500x   1.521 G  165Hz 被拒 / 60Hz 通过
```

目标档 3200x2000 是 1.25x 降采样、1.056 G，落在两个已验证通过的档位之间，
预期能以 165Hz 运行。

## 前提条件（都已满足）

1. **`nvfbhidpi=1`**（已配）——把栅格上限从 2x 提到 4x，日志确认：
   ```
   NVRM-fb: nvfbhidpi: scaled desktops up to 5120x3200 on a 2560x1600 raster
   NVRM-fb: fbmodes: scanout allocation sized for 5120x3200 (64000 KB)
   ```

2. **驱动给缩放模式打 `kDisplayModeValidForHiResFlag`**——PR #421 修复，
   你的驱动是 3.0 版，晚于 PR 涉及的 2.6.x，应已包含。若模式出现但没被当作
   HiDPI（无 `@2x`），就是这一项缺失。

## 执行

```bash
cd ~/Documents/OpenCoreProject/display-override
sudo ./install-override.sh
```

然后重启。

## 验证

```bash
# 1. 驱动是否读到 override 并校验通过
log show --last boot --predicate 'process == "kernel"' | grep -iE "validateDetailedTiming" | head -20

# 2. system_profiler 是否出现 @2x
system_profiler SPDisplaysDataType | grep -E "Resolution|Looks like"

# 3. 模式列表
cd ~/Documents/OpenCoreProject/edid-work && python3 show_modes.py --all
```

期望在「系统设置 → 显示器」里看到 1600x1000 / 1680x1050 / 1440x900 等选项。

## 回滚

```bash
sudo rm /Library/Displays/Contents/Resources/Overrides/DisplayVendorID-e6f/DisplayProductID-1616
```

重启即恢复。这不会影响驱动，也没有黑屏风险——最坏情况是模式不出现。

## 若模式出现但没被当作 HiDPI

说明缺 PR #421 的 `kDisplayModeValidForHiResFlag`。那是驱动侧改动，
需要给 `getInformationForDisplayMode()` 返回的 flags 加上 `kDisplayModeValidForHiResFlag`。
届时再评估补丁。

## 参考

- [issue #455](https://github.com/nullmoth/nvidia-macos-driver/issues/455) — 字节序与 flags 的正确写法
- [issue #360](https://github.com/nullmoth/nvidia-macos-driver/issues/360) — 像素率上限实测
- [issue #354](https://github.com/nullmoth/nvidia-macos-driver/issues/354) — 模式不出现的根因分析
- [PR #421](https://github.com/nullmoth/nvidia-macos-driver/pull/421) — `kDisplayModeValidForHiResFlag`
