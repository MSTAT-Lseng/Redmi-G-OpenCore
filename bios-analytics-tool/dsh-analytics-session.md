## Round 1

*prompt:*
 > 使用工作区内的工具或其他工具，解析 backup-FPTW64.fd。我需要找到 Intel 的 VT-d 功能在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
I'll start by examining the workspace and the target file.

The image is a fully structured Intel image. Let me check the setup-relevant pieces and the report structure.

The report is readable. Now let me extract the BIOS region and locate the HII form/string packages.

Now I understand the structure. Let me extract the HiiLayoutPkgDxe module and look inside.

The tool dumped the whole tree. Let me locate just the HiiLayoutPkgDxe file section.

I found the HiiLayoutPkgDxe 3MB module. Let me inspect it for the HII databases.

Now let me search this HII layout module for the VT-d IFR data.

That's the H2O UI layout CSS, not the setup forms. The setup forms must be in another module — let me find which FFS file holds the HII package list by scanning for the package-list GUID across the whole image.

Most of the BIOS is compressed. The H2O setup forms live in a compressed section. Let me write a proper UEFI LZMA decompressor and dump the compressed sections.

My GUID helper had a bug. Let me fix it and find the compressed setup sections.

Compression is LZMA (UEFI variant), 6 sections. Let me locate the one containing the setup forms — candidates near the H2O/Setup area.

Sections parsed. Now let me decompress all six LZMA sections and search them for the setup HII/IFR data.

Five real LZMA sections found. Let me decompress them.

Let me check if Python has the lzma module available — that's much simpler.

Python's lzma module is available. Let me use it to decompress the sections properly.

All five decompressed cleanly. Now let me search them for the setup HII forms and VT-d.

The 35 MB decompressed section contains the IFR data. Let me analyze it.

Those are network HII forms, not setup. The main BIOS setup forms must be elsewhere. Let me search more broadly across all decompressed data for the setup varstore.

Found the setup formset GUIDs. Let me use ifrextractor on the decompressed section.

ifrextractor works on this section. Now let me extract the full IFR and find VT-d.

ifrextractor produced combined form+string IFR text files. Let me search them for VT-d.

Found it — form package 10 with en-US strings. Let me examine those hits.

Found the key entry: VT-d at line 7406. Let me read the surrounding context, including the varstore definitions.

Now let me identify the varstore (VarStoreId 0x2) — which GUID/name it maps to.

Confirmed: VarStoreId 0x2 = SaSetup (GUID 72C5E28C-7783-43A1-8767-FAD73FCCAFA4), offset 0x7D. Let me verify the question ID (0x1412) and check the enabling conditions.

Let me confirm the VT-d Debug Settings block (line 471-490) and verify the varstore offsets map correctly.

The picture is complete. Let me verify the actual current value stored in the NVRAM SaSetup variable in the image.

Header offset is off by one. Let me re-align precisely.

The variable parses correctly now. Let me verify all SaSetup copies and cross-check with the DMAR/VT-d evidence.

All 15 copies consistently store 0x01 at offset 0x7D. Let me confirm which formset/module hosts this and sanity-check the DMAR table presence.

Let me verify the location of this formset inside the firmware image (which FFS module).

Confirmed. Let me verify that FFS header is genuinely a file header.

Off by a couple bytes. Let me align it exactly.

The GUID match may be a false positive. Let me verify using the UEFIExtract report which already names the SetupUtility module.

That full scan is slow. Let me kill it and use the report-based approach instead.

My $b[$i+1] initial check was wrong due to $i starting at non-byte step. Let me scan correctly.

The decompressed blob is a raw concatenation without FV wrappers. The report already gives the authoritative module mapping — let me verify via the H2O FormBrowser/SetupUtility relationship and confirm the varstore binding.

Everything is confirmed. Let me produce a concise deliverable summarizing the findings.

已经解析完成，定位到 VT-d 的准确位置。
```

*answer:*
已经解析完成，定位到 VT-d 的准确位置。

## 结论

| 项目 | 值 |
|---|---|
| **所在表（NVRAM 变量）** | **`SaSetup`** |
| 变量 GUID | `72C5E28C-7783-43A1-8767-FAD73FCCAFA4` |
| 变量长度 | `0x477` (1143) 字节，属性 NV+BS+RT |
| **字节偏移** | **`0x7D`** |
| 位宽 | UINT8，取值 0..1 |
| **开 (Enabled)** | **`0x01`** |
| **关 (Disabled)** | **`0x00`** |
| IFR QuestionId | `0x1412` |
| 出厂默认 | `1` = Enabled |
| 本镜像实测 | `0x01` → **已开启**（15 份副本全部一致） |

菜单路径：`Advanced` → `System Agent (SA) Configuration` (FormId 0x1029) → `VT-d`

## 需要注意的配套项

同一 `SaSetup` 变量内还有子域：`0x88` IGD VTD、`0x89` IPU VTD、`0x8A` IOP VTD（均为 1=Enabled）；`0x86` X2APIC Opt Out、`0x87` DMA Control Guarantee。

另有关联项在 **`Setup`** 变量（GUID `EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9`）的 **`0x976`**：`Control Iommu Pre-boot Behavior`，0 = Disable IOMMU，1 = Enable IOMMU during boot。

## 显示条件

VT-d 项被 `SuppressIf`/`GrayOutIf` 包住：`SetupVolatileData+0x05`(QID 0xFBC) 为 0 时**整项隐藏**，`MeSetupStorage+0x04`(QID 0xFCD) 为 1 时**置灰不可改**。所以如果菜单里看不到 VT-d，通常是前者为 0（CPU/平台能力标志）。反过来，VT-d 为 0 时下方的 IOMMU 预启动、X2APIC、DMA Control Guarantee 均置灰。

## 解析路径

原盘中 `ifrextractor` 报 "No IFR data found"，因为 Setup 表单所在的 FV 是 LZMA 压缩的。处理步骤：按 descriptor 切出 BIOS 区（`0x01000000`，16 MB）→ 找到 GUID-defined LZMA 段（`EE4E5898-...`，段头 `0x0140C090`）→ 解压得到 35.5 MB → HII form package #10 位于偏移 `0x01A7E824`，配 en-US 字符串包 #62 → 导出 IFR 文本定位到第 7406 行。

FormSet GUID 为 `C6D4769E-7F48-4D2A-98E9-87ADCCF35CCC`，标题 "Advanced"。

## 关于直接改二进制

在镜像里找到 `SaSetup` 变量记录（EFI variable header 以 `AA 55` 起，VendorGuid 后是 UNICODE 名 `S a S e t u p`），数据区起始 + `0x7D` 写 `01`/`00` 即可。但这台机器是 **12th Gen Intel Core i5-12450H + Boot Guard**（镜像里能看到 "Boot Guard Measured S-CRTM" 和 FIT 表），改完不重算校验会刷不进去。运行时用 setup 变量写入工具更稳。

完整报告（含偏移表、结构说明、定位链）在 [VT-d_分析报告.md](VT-d_分析报告.md)。

## Round 2

*prompt:*
 > 继续查找，我需要找到 CSM （兼容性支持模块）在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
I have the decompressed setup data already. Let me search it for CSM.

Those are "CSME" false positives. Let me search the IFR text directly, which is authoritative.

Many hits are "Legacy" noise. Let me narrow to actual CSM prompts.

Only a help-text mention in the SA formset. The actual CSM control likely lives in the Setup formset. Let me search that one.

That's the boot menu. Let me check formset 21 (largest, 182 hits) and the Setup formset specifically.

Only one mention — a help text. The CSM control may be in a different FV or use a different label. Let me search the raw decompressed data and other sections.

That's an Insyde-style "Boot Type" selector. This BIOS may not expose CSM under that exact name. Let me check the other decompressed sections and the whole image for CSM-related setup tokens.

All CSM hits are "CSME" (Intel ME). Let me verify whether this platform even has a CSM module, and check the "Boot Type" selector that replaces it.

CSM modules exist (CsmInt10Block, CsmInt10HookSmm). The control is likely in Setup/PchSetup with a different label. Let me find the CsmInt10 driver's variable.

Let me check the Boot/CSM-related formset in the full IFR set, and search PchSetup and Setup for a legacy/CSM toggle by its IFR variable name.

The "Advanced" formset has no CSM toggle. Let me check the other formsets — especially the Setup-based one (formset 21 was Boot Manager). Let me list all formsets and their titles.

This is an Insyde-based BIOS. Let me look at formset 9 (GUID A6712873, "Power") — that's the Insyde Setup formset — and check the "Front Page" and Advanced forms for CSM.

The remaining formsets are BDS/network. The CSM toggle might be in the Setup varstore but exposed only in a hidden form. Let me search Setup variables for a legacy/CSM-named option.

Confirmed: there is no CSM toggle in any setup form on this platform — only "CSME" (Intel Management Engine) false matches, plus one help-text mention. Let me verify the hardware/BIOS-level reason.

找到了 — line 865760: Boot Type，VarStoreId: 0x1（即 Setup 变量），VarOffset: 0x83F。这是 Insyde 的 CSM/传统引导开关。让我确认它的取值。

Offset 0x83F is a false match (ACPI Debug serial). Let me check the real Boot Type at QID 0x58 in the other formset.

These are mis-paired string packages (wrong pairing). Let me use the correct zh-CN/en-US pairing and re-extract formset 9's actual Boot Type.

These are all mis-paired. The "Boot Type" hits come from the Insyde formset using a different string package. Let me pair formset 9's form package with the right strings by matching on the "Power" title.

The mis-paired dump is unreliable. Let me decode the IFR binary directly for the Boot Type question to get authoritative data.

The offsets in the ifrextractor listing are for a different region. Let me locate form package 9 by its actual signature.

That's slow. Let me use the offsets ifrextractor already reported and verify with the correct base.

The package list header sits at 0x1A7D5A4; the form package starts 4 bytes later. Let me parse from there.

I've confirmed the structure. Rather than reverse-engineer the IFR bytes, let me verify by pairing form package 9 with each string package systematically and looking for a coherent "Boot Type" with real option names.

Let me instead verify the Boot Type finding semantically — check if the string package contains the actual option strings "UEFI"/"Legacy"/"Dual".

These are Insyde generic setup strings for a different platform template — not this board's active menu. Let me settle this definitively by checking which formset the board's actual setup uses.

This is definitively an Intel/Aptio-core BIOS (H2O/AMI-style formset), not Insyde — the earlier "Legacy Boot Type" strings came from an unused Insyde-formatted string block. Let me confirm no CSM toggle exists and check the DMAR/Aptio-level legacy support.

Confirmed. Let me verify against the BIOS's own CSM module to see what controls it, and check the Platform Settings form.

Platform Settings has no CSM either. Let me confirm definitively by checking the highest-offset Setup variables and the actual NVRAM for a CSM flag.

The Setup variable is fully populated with non-CSM items. Let me do a final decisive check — dump the actual current NVRAM Setup variable and look for a CSM-ish flag, and confirm the CSM driver's own variable usage.

Confirmed — there is no CSM variable at all in NVRAM. Let me do one final verification on the CSM driver's actual boot-mode switch.

The picture is now conclusive. Let me update the report file.
```

*answer:*
查完了，结论和 VT-d 的情况**不一样**：

## 结论：这台机器的 BIOS 里没有 CSM 开关

不存在「哪个表、哪个变量、哪个值」——因为全盘遍历后确认，这个平台上**没有任何可写的 CSM 设置项**。

### 证据一：全部设置项里搜不到 CSM

我把解压后的 Setup HII 数据（35.5 MB）导出成 2002 个 IFR 文本（22 个 form package × 91 个 string package），全量检索 `CSM`，只有 5 类命中，**全部是 "CSME"（Intel 管理引擎）**，另加一句帮助文字：

> `Above 4GB MMIO BIOS assignment is automatically enabled when selecting 2048MB aperture. To use this feature, please disable CSM Support.`

这句帮助文字引用的 `CSM Support` 选项——**在这份 BIOS 里并不存在**。这是 Aptio 参考代码里遗留的文案。

### 证据二：NVRAM 里没有 CSM 变量

镜像内共 125 个 EFI 变量，没有任何 CSM/Compatibility 项。作为对照，VT-d 的 `SaSetup` 就在这个列表里。**CSM 连变量都没有，自然没有偏移和取值。**

### 证据三：CSM 只剩驱动残留

镜像里确实有 `CsmInt10Block`、`CsmInt10HookSmm`、`CsmInt15HookSmm`、`LegacyBiosDxe`、`LegacyBiosPlatformDxe`——但这是 Intel/Aptio 打包时带进来的**标准组件**。从 Alder Lake（本机 i5-12450H）起 Intel 就取消了 Legacy 引导路径，这些驱动在 FV 里但没有被任何表单暴露开关。

## 顺带纠了一个坑

搜索过程中我一度看到 `Boot Type`（"Dual type, Legacy type or UEFI type"，偏移 0x83F）以为找到了。核对后发现：那是 **Insyde 模板的字符串块**，和本机实际用的 `Advanced` 表单（FormSet `C6D4769E`，Intel/H2O 风格）配不上——`ifrextractor` 把 form package 和 string package 错配了。偏移 0x83F 在真实表单里其实是 `ACPI Debug` 的串口打印开关。

## 你可能真正想找的

| 需求 | 本 BIOS 对应项 | 变量 / 偏移 |
|---|---|---|
| 从传统设备引导 | **不存在** | — |
| OpROM 优先 EFI/Legacy | `PCI ROM Priority` | Setup +0x0B |
| 外部 OpROM 是否进 Setup | `Install Ext OpRom Before BIOS Setup` | PciBusSetup +0x00（0/1/2/3） |

报告在 [CSM_分析报告.md](CSM_分析报告.md)，里面还有通用定位方法（换 AMI Aptio 机器时怎么找 `Launch CSM` 的 VarStoreId/偏移/取值），以及复现命令。

如果你手上的目标其实是**另一台机器**的 BIOS，或者这台机器你记得菜单里确实有 Legacy 选项，告诉我具体型号或菜单截图，我再针对性排查——有可能是被 `SuppressIf` 条件隐藏了，而那种情况下变量仍然存在，只是表单不显示。

## Round 3

*prompt:*
 > 继续查找，我需要找到 Above 4G Decoding 在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
I already know the help text mentions "Above 4GB MMIO" at SaSetup+0x34. Let me confirm the actual option.

Found it at line 7462. Let me read the exact definition and option values.

Confirmed: SaSetup offset 0x7E, QuestionId 0x43F, 1=Enabled / 0=Disabled. Let me verify the stored value in NVRAM.

All 15 copies store 0x01. Let me verify the display condition (QID 0x455) and the neighbouring offsets.

Complete. Let me write the report and clean up.
```

*answer:*

找到了，这一次是明确存在的开关。

## 结论

| 项目 | 值 |
|---|---|
| **所在表（NVRAM 变量）** | **`SaSetup`** |
| 变量 GUID | `72C5E28C-7783-43A1-8767-FAD73FCCAFA4` |
| 变量长度 | `0x477` (1143) 字节，属性 NV+BS+RT |
| **字节偏移** | **`0x7E`** |
| 位宽 | UINT8，取值 0..1 |
| **开 (Enabled)** | **`0x01`** |
| **关 (Disabled)** | **`0x00`** |
| IFR QuestionId | `0x43F` |
| 出厂默认 | `1` = Enabled |
| 本镜像实测 | `0x01` → **已开启**（15 份副本全部一致） |

**BIOS 里的完整名称是 "Above 4GB MMIO BIOS assignment"**，也就是常说的 Above 4G Decoding。

菜单路径：`Advanced` → `System Agent (SA) Configuration` (FormId 0x1029) → `Above 4GB MMIO BIOS assignment`

IFR 原文：
```
OneOf "Above 4GB MMIO BIOS assignment", QuestionId 0x43F,
      VarStoreId 0x2, VarOffset 0x7E, Size 8, Min 0, Max 1
    OneOfOption "Enabled"  Value 1, Default, MfgDefault
    OneOfOption "Disabled" Value 0
```

## 两个需要留意的点

**1. 被 `SuppressIf Aperture Size == 0xF` 包着，但这个条件实际不会触发**
`Aperture Size`（`SaSetup+0x34`，QID 0x455）的可选值只有 0/1/3/7（128MB/256MB/512MB/1024MB），IFR 里 `Max: 0x7`，根本没有 `0xF` 这一档。所以正常情况这一项**始终可见**——这个 `SuppressIf` 大概是给未来 2048MB 档位预留的。

**2. Aperture Size 设成 2048MB 时会强制覆盖**
帮助文本明确说 "This is enabled automatically when Aperture Size is set to 2048MB"。那种情况下改 0x7E 是无效的。

## 顺带梳理 SaSetup 里这一组相邻项

| 偏移 | 名称 | 取值 |
|---|---|---|
| `0x34` | Aperture Size | 0=128MB / 1=256MB / 3=512MB / 7=1024MB |
| `0x7D` | VT-d | 1=Enabled / 0=Disabled |
| **`0x7E`** | **Above 4GB MMIO BIOS assignment** | **1=Enabled / 0=Disabled** |
| `0x7F` | GNA Device | 1/0 |
| `0x80` | IPU Device | 1/0 |

你之前问的 VT-d 在 `0x7D`，这一项就在紧邻的 `0x7E`。

报告在 [Above4G_分析报告.md](Above4G_分析报告.md)，含复现命令和中间产物路径。

---

顺便说明一下这次搜索里发现的一个坑：`ifrextractor ... all` 会把每个 form package 和全部 91 个 string package **逐一乱配**，绝大多数组合是错的。只有少数组合（如 `10.62`）配对正确，其余会出现 "InvalidId" 或张冠李戴的选项名——比如把一个 ACPI Debug 的串口打印开关显示成 `Boot Type`。上次找 CSM 时就是这个坑。判断依据是表单标题是否合理、选项语义是否自洽。我已经把这条写进报告了。

## Round 4

*prompt:*
 > 继续查找，我需要找到 Resizable BAR / Re-Size BAR 在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
Resizable BAR on Intel ADL typically sits in the Graphics Configuration form near Above 4G. Let me search.

Found it. Let me read the exact definition with all option values.

Important detail — this is a 三态设置 (0/1/2), not a plain on/off. Let me verify context, the form path, and the stored value.

Menu path confirmed: Advanced → System Agent (SA) Configuration → PCI Express Configuration. Now the stored value.

All 15 copies store 0x02 = Auto. Let me verify there isn't a second ReBAR control elsewhere (common in Graphics Configuration).

Only one Resizable BAR control. Let me check the display condition and whether there's a related "Above 4G" dependency.

No SuppressIf/GrayOutIf wrapper — always visible. Let me confirm offset 0x42B isn't shared with another question.

0x42B is unique to ReBAR. Let me write the report.
```

*answer:*

找到了。但这一点和前面几项不一样——**它不是简单的开关**。

## 结论

| 项目 | 值 |
|---|---|
| **所在表（NVRAM 变量）** | **`SaSetup`** |
| 变量 GUID | `72C5E28C-7783-43A1-8767-FAD73FCCAFA4` |
| 变量长度 | `0x477` (1143) 字节 |
| **字节偏移** | **`0x42B`** |
| 位宽 | UINT8，取值域 **0..2** |
| IFR QuestionId | `0x7CE` |
| 出厂默认 | `2` = Auto |
| 本镜像实测 | `0x02` → **Auto**（15 份副本一致） |

## ⚠ 这里是三态，而不是二选一

BIOS 里叫 **"PCIE Resizable BAR Support"**：

| 值 | 选项名 | 含义 |
|---|---|---|
| **`0x02`** | **Auto** | 出厂默认，由 BIOS 按显卡/槽位自动判断 |
| **`0x01`** | **Enabled** | 强制开启 |
| **`0x00`** | **Disabled** | 强制关闭 |

所以：
- 要**强制开** → 写 `0x01`
- 要**强制关** → 写 `0x00`
- 要**恢复默认** → 写 `0x02`

本机出厂就是 `0x02 (Auto)`。如果你只是问「开和关」，答案是 `0x01`/`0x00`；但要知道写死 `0x01` 比默认行为更强，会覆盖 BIOS 的自动判断。

## 菜单路径

```
Advanced → System Agent (SA) Configuration
         → PCI Express Configuration
         → PCIE Resizable BAR Support
```

**无显示条件** —— 没有被 `SuppressIf`/`GrayOutIf` 包住，始终可见可改（不像同一表单里的各 Root Port，那些受 `QID 0x1001` 控制）。

## 与 Above 4G 的依赖关系

ReBAR 要让显卡把整段显存 BAR 暴露给 CPU，必须能映射到 4GB 以上，所以实际依赖：

| 依赖项 | 偏移 | 本机值 |
|---|---|---|
| Above 4GB MMIO BIOS assignment | `SaSetup + 0x7E` | `0x01` (Enabled) ✓ |
| Aperture Size | `SaSetup + 0x34` | 需 ≥ 256MB |

本机 Above 4G 是开的，ReBAR 已具备生效条件。

## 顺带确认了两件事

**唯一性**：全表单只有这一个 Resizable BAR 控制，`0x42B` 也没有被其他问题项共用。邻域偏移各自对应别的项（0x42C = MC Refresh Rate，0x42D = Realtime Memory Frequency，0x42E = Periodic DCC，0x42F = LPMode）。

**没找到独立的 "Above 4G / ReBAR 联动" 开关** —— 不像有些主板有个 "Resizable BAR = 64GB" 之类的隐藏档位，这个 BIOS 只有这三档。

报告在 [ResizableBAR_分析报告.md](ResizableBAR_分析报告.md)，含逐字节修改方法和邻域核对表。

---

四个问题的汇总，方便你对照（都在同一个 `SaSetup` 变量里）：

| 功能 | 偏移 | 取值 |
|---|---|---|
| VT-d | `0x7D` | 1=开 / 0=关 |
| Above 4G Decoding | `0x7E` | 1=开 / 0=关 |
| Resizable BAR | `0x42B` | 0=关 / 1=开 / 2=Auto |
| CSM | — | **本平台不存在** |

## Round 5

*prompt:*
 > 继续查找，我需要找到 X2APIC 在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
I already spotted X2APIC Opt Out at SaSetup+0x86 during the VT-d work. Let me verify it properly.

One hit. But X2APIC can also exist in CPU Configuration. Let me search more broadly.

Only one X2APIC control. Let me check the display condition (QID 0x1037) and read the stored value.

All 15 copies store 0x00 (Disabled). Let me confirm the parent form and check for a possible CPU-side X2APIC control.

CPU Configuration has no X2APIC control — only the SA-side one. Let me write the report.
```

*answer:*
找到了，但这一项**语义是反的**，需要特别注意。

## 结论

| 项目 | 值 |
|---|---|
| **所在表（NVRAM 变量）** | **`SaSetup`** |
| 变量 GUID | `72C5E28C-7783-43A1-8767-FAD73FCCAFA4` |
| 变量长度 | `0x477` (1143) 字节 |
| **字节偏移** | **`0x86`** |
| 位宽 | UINT8，取值 0..1 |
| IFR QuestionId | `0x439` |
| 出厂默认 | `0` = Disabled |
| 本镜像实测 | `0x00`（15 份副本全部一致） |

## ⚠ 它叫 "X2APIC Opt Out"，不是 "X2APIC Enable"

| 值 | 选项名 | 实际含义 |
|---|---|---|
| **`0x00`** | **Disabled** | 不设置 opt-out → **X2APIC 可用** |
| **`0x01`** | **Enabled** | 设置 X2APIC_OPT_OUT → **禁用 X2APIC**，回退传统 xAPIC |

所以：
- 想 **X2APIC 生效** → 写 `0x00`
- 想 **禁用 X2APIC**（老 OS 不认时）→ 写 `0x01`

**按「开=1、关=0」的直觉去改会得到相反结果。** 本机出厂就是 `0x00`，即 X2APIC 保持可用——这是正常推荐状态。

## 菜单路径

```
Advanced → System Agent (SA) Configuration → X2APIC Opt Out
```

## 两个显示/可用条件

**1. 依赖 CPU 能力**
被 `SuppressIf (SetupCpuFeatures + 0x18 == 0)` 包住。这个变量是运行期的 CPU 能力探测结果——CPU 支持 x2APIC 时该项才可见。i5-12450H 支持，所以能看见。

**2. 依赖 VT-d 开启**
它和 VT-d、DMA Control Guarantee 一起被外层 `GrayOutIf (VT-d == 0)` 控制——**VT-d 关掉时这一项会置灰**。

## 唯一性确认

我查了 CPU Configuration 表单（那里有 VMX 和 Hyper-Threading），**没有 X2APIC 控制**。全 BIOS 只有一个 X2APIC 开关，就是这个 SA 侧的。

## 简要背景

x2APIC 用 MSR 访问、APIC ID 扩到 32 位，替代传统 xAPIC 的 MMIO + 8 位 ID。作用是支撑大核数、改善中断投递，并与 VT-d 中断重映射更好配合。现代 Windows 10/11 和主流 Linux 都默认支持，`0x00` 是对的。

报告在 [X2APIC_分析报告.md](X2APIC_分析报告.md)。

---

## 五项汇总（全部在 `SaSetup` 变量）

| 功能 | 偏移 | 取值 | 本机值 |
|---|---|---|---|
| VT-d | `0x7D` | 1=开 / 0=关 | `0x01` 开 |
| Above 4G Decoding | `0x7E` | 1=开 / 0=关 | `0x01` 开 |
| **X2APIC** | **`0x86`** | **1=禁用 / 0=可用（反向）** | `0x00` 可用 |
| DMA Control Guarantee | `0x87` | 1=开 / 0=关 | `0x01` 开 |
| Resizable BAR | `0x42B` | 0=关 / 1=开 / 2=Auto | `0x02` Auto |
| CSM | — | 本平台不存在 | — |

规律：这几项都是 `SaSetup` 里的一个字节，VT-d / Above 4G / X2APIC / DMA 四个挤在 `0x7D`–`0x87` 这一小段里。

## Round 6

*prompt:*
 > 继续查找，我需要找到 CFG Lock 在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
CFG Lock is usually a hidden/undocumented option in CPU or PCH Setup. Let me search.
```

*answer:*
找到了。这一项换了变量——不在 `SaSetup`，而在 **`CpuSetup`**。

## 结论

| 项目 | 值 |
|---|---|
| **所在表（NVRAM 变量）** | **`CpuSetup`** |
| 变量 GUID | `B08F97FF-E6E8-4193-A997-5E9E9B0ADB32` |
| 变量长度 | `0x379` (889) 字节 |
| **字节偏移** | **`0x43`** |
| 位宽 | UINT8，取值 0..1 |
| IFR QuestionId | `0x189` |
| 出厂默认 | `1` = Enable |
| 本镜像实测 | `0x01` → **已锁定**（15 份副本一致） |

## 语义：「开」= 锁、「关」= 解锁

CFG Lock 控制的是 **MSR 0xE2 第 15 位**（帮助原文：`Configure MSR 0xE2[15], CFG Lock bit`）：

| 值 | 选项名 | 含义 |
|---|---|---|
| **`0x01`** | **Enable** | **锁定** —— MSR 0xE2 写保护，OS 改不了 CPU 电源管理 |
| **`0x00`** | **Disable** | **解锁** —— 允许 OS/工具写入 MSR 0xE2 |

所以：
- 想**解锁**（黑苹果、Linux 降压调频、超频）→ 写 `0x00`
- 保持**锁定**（出厂默认，更安全）→ `0x01`

IFR 里 `Disable` 排在 `Enable` 前面，加上名字本身，最容易看反的就是这一项。

## 菜单路径

```
Advanced → Power & Performance
         → CPU - Power Management Control
         → CPU Lock Configuration    (FormId 0x1012)
         → CFG Lock
```

**好消息**：这一项和它的入口表单都**没有任何 `SuppressIf`/`GrayOutIf` 包裹**，始终可见可改。很多 OEM 会用 `SuppressIf True` 把 `CPU Lock Configuration` 藏起来，这里没藏——所以你大概率能直接在 BIOS 界面里改，不必走偏移写入。

## 同一表单里还有一个配套锁

| 偏移 | 名称 | 取值 | 本机值 |
|---|---|---|---|
| `0x43` | **CFG Lock** | 1=锁 / 0=解锁 | `0x01` |
| `0x10E` | **Overclocking Lock** | 1=锁 / 0=解锁 | `0x01` |

`Overclocking Lock` 控制 `FLEX_RATIO(0x194) MSR` 的 BIT 20。**要超频得两个都解锁**（都写 `0x00`）。

## 别和 "BIOS Lock" 混淆

搜索时同时命中了一个名字相近的项：

| | CFG Lock | BIOS Lock |
|---|---|---|
| 变量 | `CpuSetup` + `0x43` | `PchSetup` + `0x1C` |
| 保护对象 | MSR 0xE2（CPU 电源管理） | SPI Flash 写入 |
| 用途 | 黑苹果/降压/超频 | 刷 BIOS 镜像时临时关闭 |

报告在 [CFGLock_分析报告.md](CFGLock_分析报告.md)。

---

## 六项汇总

| 功能 | 变量 | 偏移 | 取值 | 本机值 |
|---|---|---|---|---|
| VT-d | `SaSetup` | `0x7D` | 1=开 / 0=关 | `0x01` |
| Above 4G Decoding | `SaSetup` | `0x7E` | 1=开 / 0=关 | `0x01` |
| X2APIC | `SaSetup` | `0x86` | 1=禁用 / 0=可用（反向） | `0x00` |
| DMA Control Guarantee | `SaSetup` | `0x87` | 1=开 / 0=关 | `0x01` |
| Resizable BAR | `SaSetup` | `0x42B` | 0=关 / 1=开 / 2=Auto | `0x02` |
| **CFG Lock** | **`CpuSetup`** | **`0x43`** | **1=锁定 / 0=解锁** | `0x01` |
| CSM | — | — | 本平台不存在 | — |

这六个里有三个是"反直觉"的，提醒一下：**X2APIC**（1=禁用）、**CFG Lock**（1=锁定）、**Resizable BAR**（三态，默认 Auto=2）。

## Round 7
*prompt:*
 > 我需要找到 hyper threading 在 BIOS 的哪个表里的哪个变量，哪个值代表开和关。

*thinking:*
```
I already saw Hyper-Threading at CpuSetup+0x5 during the X2APIC work. Let me verify it.

Located: CpuSetup (VarStoreId 0x3) offset 0x5. Let me read the full definition and option values.

Confirmed: CpuSetup + 0x5, 1=Enable / 0=Disable. Let me read the stored value and check the display conditions.

All 15 copies store 0x01 (Enabled). Let me trace the display conditions.

Now I understand the gating. Let me confirm the parent form and check for duplicate/parent checks.

Confirmed unique. Let me write the report.
```

找到了。这一项和 CFG Lock 在同一个变量（`CpuSetup`）里。

## 结论

| 项目 | 值 |
|---|---|
| **所在表（NVRAM 变量）** | **`CpuSetup`** |
| 变量 GUID | `B08F97FF-E6E8-4193-A997-5E9E9B0ADB32` |
| 变量长度 | `0x379` (889) 字节 |
| **字节偏移** | **`0x05`** |
| 位宽 | UINT8，取值 0..1 |
| **开 (Enable)** | **`0x01`** |
| **关 (Disable)** | **`0x00`** |
| IFR QuestionId | `0x1417` |
| 出厂默认 | `1` = Enable |
| 本镜像实测 | `0x01` → **Enabled**（15 份副本一致） |

**这一项语义是正向的**，1 = 开、0 = 关，符合直觉。前面问的 CFG Lock（1=锁）和 X2APIC（1=禁用）都是反的，这个不是。

## 菜单路径

```
Advanced → CPU Configuration → Hyper-Threading
```

## ⚠ 两个显示/可用条件

**1. 外层：CPU 能力探测**
`SuppressIf (SetupCpuFeatures + 0x04 == 0)` —— CPU 不支持 HT 时整项隐藏。i5-12450H 支持，所以可见。

**2. 内层：受 Intel TXT 制约** ← 这个是实操中容易卡住的地方
```
GrayOutIf  EqIdVal QuestionId: 0x1549, Value: 0x1
```
`QID 0x1549` = `CpuSetup + 0xC1`，即 **Intel Trusted Execution Technology (TXT)**。

**TXT 开着时，Hyper-Threading 会置灰不可改。** 这是 Intel 的硬性约束（TXT 要求所有逻辑核行为一致，不允许关 HT）。所以如果你想关 HT，得**先把 Intel TXT 设为 Disable**。

## 顺便说下这颗 CPU 的 HT 情况

i5-12450H 是 Alder Lake-H 异构架构：

| 核心类型 | 数量 | 支持 HT |
|---|---|---|
| P-core | 4 | ✅（4C/8T） |
| E-core | 4 | ❌（E-core 无 HT） |

总共 4×2 + 4×1 = **12 线程**。关掉 HT 后剩 4+4 = **8 线程**。

另外别和同表单里这两个搞混：
- `Active Performance-cores`（`+0x06`）—— 控制**启用几个 P-core**，不是 HT
- `Active Efficient-cores` —— 控制 E-core 数量

三者配合决定最终核心/线程数。

报告在 [HyperThreading_分析报告.md](HyperThreading_分析报告.md)。

---

## 七项汇总

| 功能 | 变量 | 偏移 | 取值 | 本机值 |
|---|---|---|---|---|
| VT-d | `SaSetup` | `0x7D` | 1=开 / 0=关 | `0x01` |
| Above 4G Decoding | `SaSetup` | `0x7E` | 1=开 / 0=关 | `0x01` |
| X2APIC | `SaSetup` | `0x86` | 1=禁用 / 0=可用 ⚠反向 | `0x00` |
| DMA Control Guarantee | `SaSetup` | `0x87` | 1=开 / 0=关 | `0x01` |
| Resizable BAR | `SaSetup` | `0x42B` | 0=关 / 1=开 / 2=Auto ⚠三态 | `0x02` |
| CFG Lock | `CpuSetup` | `0x43` | 1=锁 / 0=解锁 ⚠反向 | `0x01` |
| **Hyper-Threading** | **`CpuSetup`** | **`0x05`** | **1=开 / 0=关** | `0x01` |
| CSM | — | — | 本平台不存在 | — |

`CpuSetup` 里现在有两个了（`0x05` HT、`0x43` CFG Lock），还有 `0xC1` TXT 和 `0x10E` Overclocking Lock —— 如果需要这几个我也可以一并给。
