# Fix Audio：扬声器、耳机与 Intel SST 内置麦克风

> **2026-11-27 更新：本机内置麦克风录音已恢复。** 使用 AppleALC + SimpleHDA 保留 HDA 音频通路，再使用本目录的 IntelSSTDMIC 修补版接入 Intel SST 数字麦克风。
>
> 旧说明“内建麦克风无法录音，只能插耳机”描述的是此前配置，已不适用于本次验证组合。不是所有 SST 笔记本都已验证，也不保证更换系统/驱动版本后仍然可用。

## 1. 验证范围与硬件

| 项目 | 本次环境 |
| --- | --- |
| 机器 | Redmi G 2022，i5-12450H（Alder Lake） |
| 系统 | macOS 26.7.3；驱动日志报告 Darwin 25.6 |
| Intel 音频控制器 | `8086:51C8`，子系统 `1D72:2135` |
| HDA codec | Senary SN6140，`14F1:1F86`，codec 子系统 `1D72:2104` |
| 内麦 | Intel SST DSP 直连 PDM 数字麦克风；NHLT 识别 2 个物理麦克风 |
| Lilu | 本机加载 1.7.3 |
| AppleALC | 1.9.8，**layout 21** |
| SimpleHDA | 1.0.1 |
| IntelSSTDMIC | 基于 1.0.3，本地修补标记 **`simplehda-diagnostic-1`** |

**已验证：**重启后用户确认录音正常；运行态确认 AppleHDA 六个目标符号可见、全部 hook 安装成功、DSP 返回 `FW_READY`、音频样本进入内麦通路。

**尚未完成全面验证：**睡眠唤醒、长期运行、多次冷启动、不同应用组合以及修补后的耳机/扬声器完整回归测试。此前扬声器和耳机麦克风已可用，不应把它们与本轮新增内麦验证混为一谈。

## 2. 文件说明

| 文件 | 用途 |
| --- | --- |
| [AppleALC.kext](<AppleALC.kext>) | 原有 HDA codec 适配，保留 1.9.8 |
| [SimpleHDA.kext](<SimpleHDA.kext>) | 原有 macOS 26 AppleHDA 恢复驱动，保留 1.0.1 |
| [IntelSSTDMIC.kext](<IntelSSTDMIC.kext>) | **本次已验证的修补版**，不是上游未修改的 1.0.3 |
| [config.plist](<config.plist>) | 仓库历史配置上增量加入 SST 加载项和启动参数；不是当前机器完整配置的导出 |
| [SimpleHDA-HAL-1.0.1.pkg](<SimpleHDA-HAL-1.0.1.pkg>) | 可选 HAL 包；不是 SST 修复的必需条件 |
| [源码补丁](<Patches/IntelSSTDMIC-1.0.3-simplehda.patch>) | 相对于上游 1.0.3 的统一差异补丁 |
| [修改后的源文件](<Source/IntelSSTDMIC>) | 五个修改文件的完整副本，不是整个上游仓库 |
| [构建说明](<BUILD.md>) | 固定源码版本、依赖、编译与回归测试方法 |
| [成功诊断记录](<Diagnostics/recording-success-2026-11-27.json>) | 录音停止后的脱敏状态快照，不含录音或内核地址 |
| [SHA256SUMS](<SHA256SUMS>) | 驱动、补丁、源文件和配置等文件的校验清单 |
| [第三方许可说明](<Licenses/README.md>) | 驱动与内嵌 SOF 固件的版权/许可证 |
| [历史会话记录](<dsh-session-1_macOS-archive.md>) | 旧排障历史，不作为本次方案的安装依据 |

## 3. 为什么原来只有耳机麦克风正常

本机不是一条音频通路：

```text
扬声器 / 耳机 / 耳机麦克风 → Senary HDA codec → AppleHDA + AppleALC
机身内置麦克风           → Intel SST DSP → IntelSSTDMIC → AppleHDA 内麦引擎
```

Windows 的实际设备绑定中，内麦使用独立的 `IntcDMic` 服务（`INTELAUDIO ... LINKTYPE_02 ... DEV_AE20`），与 Senary codec 分开。切换 AppleALC layout 15/21 不能替代 SST DSP 采集驱动。

AppleALC 官方把本机 `14F1:1F86` 放在 **CX8070** 资源目录下，支持 15/21；不要因为没有 SN6140 目录就误认为不支持，也不要套用另一个设备 ID `14F1:1F87` 的方案。

IntelSSTDMIC 启动内嵌的 SOF 固件，采集 DSP 上的数字麦克风，并通过 AppleHDA 输入转换函数送进原生 Core Audio 通路；不是创建虚拟麦克风。

## 4. 安装 / 合并配置

### 4.1 先备份

完整备份正在使用的 EFI，并准备已知可启动的备用引导介质。内核驱动存在开机失败风险，**桌面备份本身不等于可启动救援盘**。APFS 上的备份在 Windows 中通常不可直接读取。

**优先增量合并下列内容，不要无条件覆盖整份配置。** 本目录的 [config.plist](<config.plist>) 包含仓库历史机型配置；显卡、无线网卡、ACPI、SMBIOS、SIP 等无关设置可能与你的当前环境不同。本次仅在其原有内容上新增 SST 项，没有同步本机其他配置。

### 4.2 驱动与加载顺序

把本目录三个驱动放入 `EFI/OC/Kexts/`，在 `Kernel → Add` 保留有效路径并启用：

```text
Lilu.kext
AppleALC.kext
SimpleHDA.kext
IntelSSTDMIC.kext
```

这是本机成功组合的相对顺序，不代表可单靠调顺序修复其他组合。Lilu 在本仓库其他 EFI 文件中提供，本目录不另附。

新增条目如下（已有时更新，不要重复添加）：

```xml
<dict>
    <key>Arch</key><string>x86_64</string>
    <key>BundlePath</key><string>IntelSSTDMIC.kext</string>
    <key>Comment</key><string>IntelSSTDMIC 1.0.3 simplehda-diagnostic-1</string>
    <key>Enabled</key><true/>
    <key>ExecutablePath</key><string>Contents/MacOS/IntelSSTDMIC</string>
    <key>MaxKernel</key><string>25.99.99</string>
    <key>MinKernel</key><string>25.0.0</string>
    <key>PlistPath</key><string>Contents/Info.plist</string>
</dict>
```

范围限定 Darwin 25 / macOS 26。不要同时安装多套会争用同一个 DSP 的实验驱动。

### 4.3 参数与属性

- 保留 `Kernel → Quirks → DisableLinkeditJettison = true`，这是 SimpleHDA 1.0.1 的要求。
- 保留 `PciRoot(0x0)/Pci(0x1f,0x3)` 下 AppleALC `layout-id` 为 **Data `15000000`**，即十进制 21。
- 在 `NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → boot-args` **追加**，不要覆盖原有参数：

```text
-sstdmiclayout=auto
```

- 自动识别在本机选择 SST layout 4（Alder Lake、2 麦）。**这是 IntelSSTDMIC 的布局编号，不是 AppleALC layout；不要把 21 改成 4。**
- 本目录配置的 `NVRAM → Delete` 已包含 `boot-args`，每次启动会按配置重新注入。沿用此机制时无需为了本次修改先 Reset NVRAM。
- SOF 固件已内嵌，不需要单独安装固件或重建系统内核集合。
- HAL 包是可选组件；本机成功记录中此前走普通 IOAudio 路径，无需把安装 HAL 当成内麦修复前提。

### 4.4 重启与实测

保存工作后重启；只复制驱动不会改变当前已加载的内核实例。

1. 拔掉耳机。
2. 系统设置 → 声音 → 输入，选择 **内建麦克风**，不是“线路输入”。
3. 观察电平，用语音备忘录或 QuickTime 录几秒人声并回放；按需给应用麦克风权限。
4. 再测试扬声器、耳机输出、耳机麦克风、重复录音及睡眠唤醒。

## 5. 修补思路与证据

AppleHDA 完整实现并未由 Apple 开源。本次分析的是公开的 IntelSSTDMIC、Lilu、SimpleHDA、AppleALC 源码，以及 SimpleHDA 内嵌 AppleHDA 的 Mach-O 符号表，**不是声称获得了 AppleHDA 完整源码**。

### 5.1 过滤非 AppleHDA 加载事件

上游 1.0.3 的 `appleHDALoaded()` 对所有收到的 kext ID 调用安装函数。但 Lilu 会向注册回调广播已监视的驱动事件。

修补后先验证 `id == appleHDAInfo.loadIndex`，其他事件只计数，不再污染 AppleHDA 的错误状态。清理旧错误之前保存运行镜像错误，并记录目标回调数、六个函数的解析地址/error/mask。

本机成功记录：总回调 15 次，真正 AppleHDA 1 次，忽略其他事件 14 次。旧版的“10 次回调 / 最后一个符号错误”不能解释为 AppleHDA 失败了 10 次。

### 5.2 兼容 SimpleHDA 的名称本地化

上游只接受 `IOAudioEngineDescription == "DevShortNameIMic"`。SimpleHDA 在链接时重绑定 `IOAudioEngine::setDescription`，本机实际属性变为“内建麦克风”。即使 hook 成功，这个精确名称判断也会失败。

修补后保留原始标识识别，增加语言无关回退：`IOAudioEngineDeviceDescription` 字典中的 **OSNumber `num-internal-mics > 0`**。保留 `ownsEngine()` 的 PCI 祖先约束，不根据显示名称模糊匹配。线路输入计数为 0，不会被此回退选中。

### 5.3 去掉存在 panic 风险的范围重试

原版先带回调地址/大小调用 `routeMultiple`，失败后才尝试无范围与 force。Lilu 对某些范围不符情况会直接 panic，后面的 fallback 未必能执行。

修补后在确定正确 kext ID 的前提下使用默认无回调范围路由，删除重复 force 重试；不硬编码函数地址，不绕过符号解析。

### 5.4 不能把联合成功夸大为单点归因

上述修补一起部署后，本机录音恢复。没有逐项 A/B 重启测试，因此不能断言“只改其中某一行就一定能恢复所有机器”。名称匹配问题是明确的独立兼容阻断；加载过滤与路由变化的各自贡献仍需单独验证。

六个目标函数在原 AppleHDA 600.2 payload 中均是已定义的 `N_SECT | N_EXT` 符号。Lilu KC 模式可以从运行态 `__LINKEDIT` / `LC_SYMTAB` 读取；磁盘上没有 AppleHDA 文件不能单独作为根因。本次成功也证明不需要另行替换 AppleHDA 恢复方案。

## 6. 成功判据与排错

只读诊断命令（不会录音）：

```sh
ioreg -r -c IntelSSTDMIC -l -w0 -d 1
```

| 字段 | 本机成功快照 | 含义 |
| --- | --- | --- |
| `CompatibilityBuild` | `simplehda-diagnostic-1` | 确认实际加载修补版；版本号仍是 1.0.3 |
| `HookTargetKextCb` | 1 | 收到了真正 AppleHDA 事件 |
| `HookRunningInfoError` | 0 | 没有记录到运行镜像更新错误 |
| `HookSymbolMask` | 63 | 六个目标符号全部找到 |
| `HookRouteOk` | 1 | 输入转换函数 hook 成功；2 表示失败 |
| `HookRouteEngine` | 31 | 五个生命周期 hook 全部成功 |
| `DspAlive` | Yes | DSP 已运行 |
| `LastError` | `OK FW_READY` | 固件已就绪 |
| `ImicTag` / `ImicStreams` | 1 / 1 | 已识别内麦输入及流 |
| `HookFills` / `HookFrames` | 6373 / 3196419 | 已实际填入采样，不再停在 0 |
| `HookFillFail` | 0 | 此快照没有填充失败 |

快照采于录音停止之后，`Streaming=No`、`SetupDone=No` 不可单独判故障；要结合固件日志、累计采样和真实回放。`Ready` / `DspActive` 只说明对象创建，不能替代录音成功证据。

- 没有修补标记：检查是否从正确 EFI 启动、是否复制了本目录驱动。
- `HookTargetKextCb=0`：先查加载事件，不要盲调增益/layout。
- 目标事件存在但 `HookSymbolMask!=63`：检查运行镜像和对应 `HookSymbol*Error`。
- 符号齐全但 hook 失败：检查函数路由；不能用声音设备名称证明成功。
- hook 正常但固件或流失败：再根据 `Log` / `LastError` 查 DSP 阶段。
- 录音计数增长但应用无声：核对输入设备、权限和实际回放，勿先覆盖整个 EFI。

## 7. 回退

保留自己的修改前 EFI。要完全停用 SST 内麦测试：

1. 将 `Kernel → Add` 中 `IntelSSTDMIC.kext` 的 `Enabled` 设为 `false`。
2. 只移除新增的 `-sstdmiclayout=auto`，保留其他启动参数。
3. 重启；AppleALC / SimpleHDA 与原来的耳机音频通路保持不变。

也可以直接恢复自己的修改前配置。驱动文件留在 Kexts 目录不会自动加载。若只想退回上游官方 SST，恢复之前的驱动包即可，但本机此前该组合内麦无声。

不能开机时，用已知可启动备用 EFI / 恢复环境挂载正确 EFI 分区后恢复。不要格式化 EFI，不要修改 Windows 引导目录。`-sstdmicoff` 可用于显式停用，但若 OpenCore 会覆盖 boot-args，仅在系统里临时写 NVRAM 可能不生效。

## 8. 来源、构建与许可

本修补版为本地修改，不是 IntelSSTDMIC 上游正式发布，也不是 Apple 官方签名驱动。详细版本固定、构建步骤及测试见 [BUILD.md](<BUILD.md>)。本地 ad-hoc 签名只保证包内部一致，不等于 Apple 审核或稳定性保证。

- [IntelSSTDMIC 1.0.3](https://github.com/qqaoshi888/IntelSSTDMIC/tree/1.0.3)
- [SimpleHDA 1.0.1](https://github.com/laobamac/SimpleHDA/tree/v1.0.1)
- [AppleALC CX8070 / 本机 codec 配置](https://github.com/acidanthera/AppleALC/blob/1.9.8/Resources/CX8070/Info.plist)
- [Lilu 固定源码](https://github.com/acidanthera/Lilu/tree/0249c3a918c68a43891350f35fded615b1575776)
- [SOF 固件上游](https://github.com/thesofproject/sof-bin)
- [驱动许可](<Licenses/IntelSSTDMIC-BSD-3-Clause.txt>)、[Intel SOF 固件许可](<Licenses/LICENCE.Intel>)
