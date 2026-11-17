# Redmi G (Pro) 2022 - Hackintosh

![截屏2026-11-17 19.46.22.png](https://files.seeusercontent.com/2026/11/18/4nYa/2026-11-17-194622.png)

*安装过程由本人研究，安装教程由DeepSeek整理编写*

> 适用于：Redmi G (Pro) 2022 / 主板 `TIMI REDMI G 2022` / i5-12450H + RTX 3050 Laptop / macOS 26 Tahoe
>
> 本教程基于本仓库已有的文件编写，**不需要你再去下载别人的 EFI**。全过程大约 2～4 小时，其中大部分时间在等镜像恢复和系统安装。
>
> 如果只想知道"每步做什么、卡住了怎么办"，可以只看第 0 节的流程图和第 9 节的排错表。

---

## 目录

- [0. 开始之前：必读](#0-开始之前必读)
  - [0.1 你要面对的现实](#01-你要面对的现实)
  - [0.2 本机配置与兼容性](#02-本机配置与兼容性)
  - [0.3 总体流程图](#03-总体流程图)
  - [0.4 准备清单](#04-准备清单)
  - [0.5 备份与还原](#05-备份与还原)
- [1. 关闭安全启动（BIOS 界面内可做的部分）](#1-关闭安全启动bios-界面内可做的部分)
- [2.（可选）备份 BIOS 与升级 BIOS](#2可选备份-bios-与升级-bios)
  - [2.1 用 FPTW64 备份当前 BIOS](#21-用-fptw64-备份当前-bios)
  - [2.2 升级到 RMGAD6T0P1313](#22-升级到-rmgad6t0p1313)
- [3. 制作 RU 启动盘](#3-制作-ru-启动盘)
- [4. 用 RU 改 BIOS 隐藏项（最关键的一步）](#4-用-ru-改-bios-隐藏项最关键的一步)
  - [4.1 进入 RU](#41-进入-ru)
  - [4.2 第一组：SaSetup 表](#42-第一组sasetup-表)
  - [4.3 第二组：CPUSetup 表](#43-第二组cpusetup-表)
  - [4.4 改完后的自检清单](#44-改完后的自检清单)
- [5. 准备 macOS 系统盘（rdr 恢复法）](#5-准备-macos-系统盘rdr-恢复法)
- [6. 部署 OpenCore EFI](#6-部署-opencore-efi)
- [7. 安装 macOS 与首次进入系统](#7-安装-macos-与首次进入系统)
  - [7.1 恢复镜像](#71-恢复镜像)
  - [7.2 第一次启动 macOS](#72-第一次启动-macos)
  - [7.3 黑屏只剩光标：建一个管理员账号](#73-黑屏只剩光标建一个管理员账号)
  - [7.4 进桌面并合并剩余空间](#74-进桌面并合并剩余空间)
- [8. 安装 NVIDIA 驱动与各项驱动](#8-安装-nvidia-驱动与各项驱动)
- [9. 排错大全](#9-排错大全)
- [10. 附录](#10-附录)
  - [10.1 本仓库 EFI 详解](#101-本仓库-efi-详解)
  - [10.2 config.plist 关键值对照表](#102-configplist-关键值对照表)
  - [10.3 应急还原 BIOS 设置](#103-应急还原-bios-设置)
  - [10.4 参考链接](#104-参考链接)

---

## 0. 开始之前：必读

### 0.1 你要面对的现实

先把丑话说在前面，看完这些觉得还能接受，再往下做。

| 问题 | 说明 |
|---|---|
| **这是"能用"，不是"好用"** | RTX 3050 由 NullMoth 驱动（第三方开源 Metal 驱动）驱动，**不是**苹果官方驱动。硬件加速支持不全，**不适合当生产力机器**。作者自己的话说："驱动成功 ≠ 可以正常使用"。 |
| **没有 MUX 直连的笔记本可能点不亮内屏** | 本机内屏接在 Intel 核显上（`CSO1616` 接 `Intel(R) UHD Graphics`），所以画面走 **WhateverXe（Intel Xe 核显驱动）**，RTX 3050 只负责算力。少部分机型需要外接显示器。 |
| **BIOS 被锁了一堆选项** | 小米把 VT-d、超线程、CFG Lock、Resizable BAR 这些关键项藏在 BIOS 界面外面，**必须用 RU 工具直接改固件变量**，否则开不了机（卡 `[EB\|#LOG:EXITBS:START]`）。这是本教程最长的一章，也是唯一有变砖风险的一步。 |
| **必须关超线程** | 12 代 i5 在这套配置下**必须关 HT**，否则必定卡在 `EXITBS:START`。代价是 i5-12450H 从 12 线程变成 8 线程。 |
| **不能用 Apple ID 之类的敏感操作时就别硬上** | 黑苹果没有 T2/安全隔膜，SIP 已被降到 `0x0A43`，安全性远低于白苹果。**别用它处理银行、工作、隐私数据。** |
| **系统更新可能翻车** | 大版本更新（如 26.x → 26.y）前请先做好备份，并且重新确认 OpenCore 与驱动版本。 |

> ⚠️ **免责声明**：改 BIOS 变量、刷写 SPI Flash 属于高风险操作，操作不当可能导致无法开机（需返厂或用编程器救砖）。本教程只负责把仓库里的信息讲清楚，**风险由操作者自行承担**。

### 0.2 本机配置与兼容性

| 部件 | 型号 | macOS 下状态 |
|---|---|---|
| CPU | 12th Gen Intel Core **i5-12450H**（Alder Lake-H，4P+4E） | ✅ 可用，需 `CpuTopologyRebuild`，**必须关超线程** |
| 主板 | TIMI REDMI G 2022，BIOS `RMGAD6T0P1313` | ✅ 见第 4 章 |
| 独显 | **NVIDIA GeForce RTX 3050 Laptop GPU**（`10DE-25E2`，ACPI `\_SB.PC00.PEG1.PEGP`） | ✅ 靠 NullMoth 驱动，**需自行安装** |
| 核显 | Intel UHD Graphics（`8086-46A3`，ACPI `\_SB.PC00.GFX0`） | ⚠️ WhateverXe 0.8.2，**内屏走这里，但 12 代 CPU 不一定能正确驱动核显** |
| 无线网卡 | Intel Wi-Fi 6 **AX201**（`8086-51F0`） | ⚠️ `itlwm.kext`（需配 HeliPort），**1401自动生成的OpenCore不能正确驱动无线网卡，后续还要你自行配置** |
| 有线网卡 | Realtek PCIe GbE（`10EC-8168`） | ✅ `RealtekRTL8111.kext` |
| 蓝牙 | Intel 无线 Bluetooth（`8087-0026`） | ✅ `IntelBluetoothFirmware` + `IntelBTPatcher` + `BlueToolFixup` |
| 硬盘 | PS5019-E19 PCIe4 NVMe | ✅ `NVMeFix.kext` |
| 触摸板 | `MSFT0001` I2C HID | ✅ `VoodooI2C` + `VoodooI2CHID` |
| 读卡器 | Genesys Logic（`17A0-9755`） | ❌ 已在配置里禁用 |
| 声卡 | Senary Audio（`14F1-1F86`） | ⚠️ 本仓库 **未包含** `AppleALC`，音量/内建扬声器不可用，**需要你后续自行安装驱动** |
| 指纹 / 摄像头 | — | ❌ 无驱动 |

### 0.3 总体流程图

```
┌──────────────────────────────────────────────────────────────┐
 ① 关闭安全启动（BIOS 界面）
      ↓
 ②（看情况）备份 BIOS / 升级到 RMGAD6T0P1313
      ↓
 ③ 做一个 FAT32 小分区，放入 RU-tools\EFI，设为第一启动项
      ↓
 ④ 用 RU.efi 改 6 个隐藏项（VT-d / X2APIC / ReBAR /          
    Hyper-Threading / CFG Lock）← 不改必卡 EXITBS:START
      ↓
 ⑤ 用 rdr 把 macOS 26 恢复到新分区
      ↓
 ⑥ （可选项）把 OpenCore\EFI 放到 EFI 分区，设 OpenCore 为第一启动项
      ↓
 ⑦ 启动 macOS → 黑屏只剩光标 → 用脚本建管理员账号
      ↓
 ⑧ 进桌面 → 装 NullMoth NVIDIA 驱动 → 装 HeliPort 连 Wi-Fi
└──────────────────────────────────────────────────────────────┘
```

### 0.4 准备清单

**硬件**

- 一个 **U 盘（≥ 8 GB 也可以，但要能整个被清空）** —— 本教程用它来放 RU 引导 + 后期放驱动。
- 笔记本原装电源适配器（刷 BIOS 时**必须**插电，且电量 > 20%，这是小米官方 SOP 的要求）。
- 一个有线鼠标（第一次进系统时触控板可能没好，有鼠标能救命）。

**软件（按需下载，放在 Windows 里）**

| 用途 | 软件 | 说明 |
|---|---|---|
| 磁盘分区 | **DiskGenius**（≥ 5.4.6） | 压缩分区、建 FAT32、设置 UEFI 启动项 |
| 恢复 rdr 镜像 | **R-Drive Image 7**（`RDriveImage7`） | rdr 格式专用；注册机会被杀软误报，操作前请关掉实时防护 |
| macOS 镜像 | `Install macOS Tahoe 26.x ... .rdr` | 见第 5 章下载地址；解压/恢复密码一般是 `imacos.top` |
| NullMoth 驱动 | `1401-Mac-3.0.zip` / `.dmg` | 已在仓库 `OpenCore/NullMoth/` 内，也可以自己去 GitHub Releases 下最新版 |
| Wi-Fi 客户端 | **HeliPort** | `itlwm` 不自带密码输入界面，连 Wi-Fi 必须靠它 |

> 💡 网盘下载（imacos.top，解压密码统一为 `imacos.top`）：rdr 镜像见 [rdr 安装教程](https://imacos.top/2025/10/20/rdr-mac/)，1401 驱动工具见 [1401 教程](https://imacos.top/2026/10/23/1401/)。你也可以直接用仓库里 `OpenCore/NullMoth/` 里的 3.0 版本。

**本仓库提供的文件（对应关系）**

| 目录 | 作用 | 在教程哪一步用 |
|---|---|---|
| `RU-tools/` | RU.efi + GRUB，用来改 BIOS 隐藏项 | 第 3、4 章 |
| `bios-backup-tools/` | FPTW64，备份当前 BIOS 镜像 | 第 2.1 节 |
| `bios-resources/` | 官方 BIOS 升级包 + 已解出的 `.fd` 镜像 + 更新 SOP | 第 2.2 节 |
| `bios-analytics-tool/` | UEFITool / ifrextractor 等逆向工具 | 第 10.1 节（研究/校验用，装机不需要） |
| `OpenCore/` | **本机专用 EFI** + NullMoth 驱动包 + `finish-setup.sh` | 第 6、7、8 章 |
| `create-user.sh` | 在恢复环境里建管理员账号的脚本 | 第 7.3 节 |

### 0.5 备份与还原

在做任何事之前，请务必：

1. **备份 Windows 里所有重要数据**到移动硬盘或网盘。后面要压缩分区、改启动项，分区表一旦出错数据就没了。
2. **记下当前 BIOS 版本**：Windows 里按 `Win + R` → 输入 `msinfo32` → 看"BIOS 版本/日期"。本仓库的偏移量对应 **`RMGAD6T0P1313`**。
3. **（强烈建议）用第 2.1 节备份一份完整 BIOS 镜像**，万一改坏了还有救。
4. **准备一个 Windows 安装 U 盘或 PE 盘**，用来在最坏情况下重建启动项。

---

## 1. 关闭安全启动（BIOS 界面内可做的部分）

小米的 BIOS 里能做的不多，安全启动是其中之一，**必须先关**，否则 OpenCore 起不来。

1. 关机，按 **F2**（或 `Fn + F2`）开机进 BIOS。（小米部分机型的 Boot Menu 是 **F12**）
2. 找到 **Security（安全）** 页。
3. 先 **设置管理员密码（Supervisor / Administrator Password）** —— 很多选项在没有管理员密码时是灰色的，设了密码才会解锁。
   - 密码请设一个你记得住的（比如 `1234`），**下一步马上就会删掉**。
4. 在 **Security → Secure Boot** 里，把 **Secure Boot** 设为 **Disabled**。
5. 按 **F10 保存并退出**，重启。
6. 再次按 **F2** 进 BIOS，到 Security 里把管理员密码**改成空**（新密码留空、确认也留空），保存退出。
7. **在 BIOS 中将显卡模式调整为独显输出（如果有）**

> ✅ 做完这一步，`Secure Boot` 状态应该显示为 **Disabled**，且 BIOS 里不再有密码。
> 为什么要"设了再删"？因为小米 BIOS 的某些选项只有在"当前会话已通过管理员验证"时才可写，删除密码后再进，选项会重新变灰——但**修改结果已经保存进 NVRAM 了**。这也是后面要用 RU 的原因之一。

---

## 2.（可选）备份 BIOS 与升级 BIOS

**如果你的 BIOS 已经是 `RMGAD6T0P1313`，可以直接跳到第 3 章。**
**如果版本更旧**，建议先升级——本仓库所有偏移量都是基于 `RMGAD6T0P1313` 逆向出来的。
**如果版本更新**，⭐ **请立刻停下**：新版 BIOS 的标志位可能已经变了，照抄本章的偏移量可能改坏东西，需要重新逆向分析。

*怎么查看 BIOS 版本？*
答：使用 **CPU-Z** 查看，切到 **主板** 选项卡就可以查看 BIOS 版本。
![QQ_2026-11-18_11-06-39.png](https://files.seeusercontent.com/2026/11/18/9Cfc/QQ_2026-11-18_11-06-39.png)

### 2.1 用 FPTW64 备份当前 BIOS

`bios-backup-tools/` 里是 Intel Flash Programming Tool。用它把当前 BIOS 整片读出来存成 `.fd`。

**前置条件**（必须在第 1 章做完之后）：

- Secure Boot 已关闭
- BIOS 管理员密码已删除
- Windows 以**管理员**身份运行
- **已经关闭内核隔离中的选项**
![QQ_2026-11-18_11-11-23.png](https://files.seeusercontent.com/2026/11/18/kuY3/QQ_2026-11-18_11-11-23.png)

**操作**：

1. 把 `bios-backup-tools` 整个文件夹复制到本机磁盘（不要在 U 盘或网盘同步目录里跑）。
2. 右键 **`backup.bat`** → **以管理员身份运行**。它内部只做一件事：

   ```bat
   fptw64.exe -d backup.fd
   ```

   也可以打开管理员命令提示符，手动执行 `fptw64.exe -d backup.fd`。
3. 看到 `FPT Operation Successful` 之类提示即为成功，同目录会出现 `backup.fd`（约 16～18 MB）。

**备份文件怎么用？**

- 留着当保险：将来想刷回去，`fptw64.exe -f backup.fd`（⚠️ 高危，非必要不要做）。
- 放进 `bios-analytics-tool/` 目录，改名 `backup-FPTW64.fd`，就能按 `dsh-analytics-session.md` 里记录的方法，用 `UEFIExtract.exe` / `ifrextractor.exe` 重新定位各项的偏移量（见第 10.1 节）。

### 2.2 升级到 RMGAD6T0P1313 （如果是同版本可跳过此步骤）

`bios-resources/` 里是小米官方 BIOS 升级包：

| 文件 | 说明 |
|---|---|
| `RMGAD6T0P1313.exe` | 官方升级程序（Insyde H2OFFT 自解压包，**经过加密**） |
| `RMGAD6T0P1313.fd` | 从 exe 中提取出的裸 BIOS 镜像，仅供研究。**不要直接拿它刷机**，请用官方 exe |
| `install.bat` | 只有一行 `RMGAD6T0P1313.exe`，等价于双击运行 |
| `XiaoMi 笔记本BIOS更新SOP.docx` | 小米官方更新说明 |

**官方 SOP 的原文步骤**（已从 docx 中提取）：

1. 插上电脑的充电器，并保证电池剩余电量 **大于 20%**。
2. 将下载的 BIOS 文件复制到电脑上，解压缩，**OS 版本要求为 Windows 10**。
3. 双击运行此应用程序，点击"是"进入下一步。
4. 弹出提示 BIOS 升级风险说明，若确定要更新，请点击"确定"进入下一步。
5. 电脑自动重启，进入刷新阶段，**此过程中请勿对电脑做任何操作**。
6. 更新完成后，请等约 **1 分钟**，电脑会自动重启进入 OS，升级完成。

**操作要点**：

- 全程插电，**绝对不能断电**。
- 升级期间不要按任何键、不要合盖。
- 升级完再回到 BIOS 确认版本已变为 `RMGAD6T0P1313`。
- 升级后 **Secure Boot 可能会重新开启**，请回到第 1 章再检查一遍。

---

## 3. 制作 RU 启动盘

RU（AMI 工程师 James Wang 的工具）能直接读写 BIOS 的 Setup 变量，这是绕过小米 BIOS 隐藏选项的唯一途径。

### 3.1 建一个 50 MB 的 FAT32 分区

使用 **DiskGenius**：

1. 选中系统盘（或任意一块**内置硬盘**，选 U 盘也行，但内置盘更稳）。
2. 右键分区 → **调整分区大小**，从未分配空间/尾部收缩出 **50 MB**。
3. 在空出来的 50 MB 上 **新建分区**：
   - 文件系统：**FAT32**
   - 卷标：`RU`（随便起，能认出来就行）
4. 保存更改并格式化。

**三个前提条件**：

| 前提 | 怎么检查 / 怎么做 |
|---|---|
| 关闭"设备安全性 → 内存隔离" | Windows 设置 → 隐私和安全性 → Windows 安全中心 → 设备安全性 → 内核隔离详细信息 → **内存完整性 = 关**，重启 |
| 关闭 BitLocker | 控制面板 → 系统和安全 → BitLocker 驱动器加密 → 全部**关闭**（或搜索 `manage-bde -status` 确认全部 Off） |
| 分区表为 **GPT** | DiskGenius 里看磁盘类型。MBR 的话后面 rdr 恢复会报"APFS 容器只能复制到 GPT" |

### 3.2 复制 EFI 文件

把仓库里 **`RU-tools/EFI`** 整个文件夹复制到新分区的**根目录**，结构必须是：

```
<新分区根目录>\
└── EFI\
    └── BOOT\
        ├── BOOTx64.efi
        ├── grub.efi
        └── RU.efi
```

> 复制过去后如果根目录里是 `EFI\EFI\BOOT`，就多套了一层，手动改成 `EFI\BOOT`。

### 3.3 把这个分区设为第一启动项

重启按 **F2** 进 BIOS → `高级选项` 页 → 调整启动顺序 → 将新加的分区调整为第一位 → F10 保存。

> ✅ 重启后如果看到一个 **GRUB 菜单**，或者直接进了 RU 的蓝底字符界面，说明启动盘制作成功。

---

## 4. 用 RU 改 BIOS 隐藏项（最关键的一步）

这一章是所有步骤里**最容易出错**的地方。请慢慢做，每改一个值就保存一次。

**参考视频**：[RU 使用教程（12/13/14 代 Intel 笔记本使用）](https://www.bilibili.com/video/BV12XATehE4b)（B 站，默之霜）。界面看不懂时对着视频看一遍最快。

### 4.1 进入 RU

1. 重启，从刚才的 RU 分区启动。
2. 进入 GRUB 菜单后，**随便按一个键**停住，在命令行输入并回车：

   ```
   ru.efi
   ```

3. RU 启动后可能会弹一个提示框，**按回车消掉**。
4. 按 **`NumLk`（数字锁定）键** 解除数字锁——不然后面输数字会变成方向键。
5. 按 **`Alt` + `=`**（或 `Alt` + 等号键）调出 **Setup 变量表列表**。

![IMG_5611.jpg](https://files.seeusercontent.com/2026/11/18/8aFy/IMG_5611.jpg)

> 🔹 **RU 的基本操作**（记住这五条就够了）：
>
> | 操作 | 按键 |
> |---|---|
> | 上下选择表 / 行 | `↑` `↓` |
> | 左右移动光标（按字节） | `←` `→` |
> | 编辑当前字节 | 直接敲两个十六进制字符（如 `00`、`01`） |
> | **保存当前表** | `Ctrl` + `W` |
> | 重启 | `Ctrl` + `Alt` + `Del` |
> | 翻页（表内） | `Ctrl` + `PgDn` / `Ctrl` + `PgUp` |

> 🔹 **坐标怎么读**：教程里写的 `第7行，7D` 表示 —— 光标先上下移到**行号 7**，再左右移到**列偏移 `7D`**，然后在该位置输入新的两位值。**行号是十六进制**，`7` 就是 `7`，`4` 后面的行是 `5`。

### 4.2 第一组：SaSetup 表

在 **`Alt` + `=`** 弹出的表列表里，按 `↓` 找到表名 **`SaSetup`**（也叫 `SaSetup`），按回车进入。

#### ① 关闭 VT-d —— 行 `7`，偏移 `7D`，`01 → 00`

```
移动到：第 7 行，列 7D
原值：01
改成：00        ← 关闭 VT-d
按 ← 回到行首，按 Ctrl + W 保存
```

| 项目 | 值 |
|---|---|
| 变量 | `SaSetup`（GUID `72C5E28C-7783-43A1-8767-FAD73FCCAFA4`） |
| 偏移 | `0x7D` |
| 取值 | `01` = 开启 / **`00` = 关闭** |
| 出厂值 | `01`（开启） |

> ❓ **为什么要关 VT-d？** 关闭 VT-d 之后，`config.plist` 里的 `DisableIoMapper = true` 才能让 macOS 正常接管 IOMMU。不关的话 12 代平台会卡在 PCI 配置阶段或 `EXITBS:START`。NullMoth 官方文档对 12 代及更新的 Intel 也是明确要求**关 VT-d**。

#### ② 启用 X2APIC Opt Out —— 行 `8`，偏移 `86`，`00 → 01`

```
移动到：第 8 行，列 86
原值：00
改成：01        ← 设置 X2APIC_OPT_OUT
按 ← 回到行首，按 Ctrl + W 保存
```

| 项目 | 值 |
|---|---|
| 变量 | `SaSetup` |
| 偏移 | `0x86` |
| 取值 | **`01` = 禁用 X2APIC（回退传统 xAPIC）** / `00` = X2APIC 可用 |
| 出厂值 | `00` |

> ⚠️ **这一项语义是反的！** 它叫 "X2APIC Opt Out"，不是 "X2APIC Enable"。这里改成 `01` 是**关掉 X2APIC**。macOS 在这套平台上用传统 xAPIC 更稳，照做即可，别被名字迷惑。

#### ③ 打开 PCIE Resizable BAR —— 第 4 页，偏移 `42B`，`02 → 01`

```
按住 Ctrl + PgDn 向下翻页，一直翻到第 4 页（Page 4）
移动到：列 42B
原值：02（Auto）
改成：01        ← 强制 Enabled
按 ← 回到行首，按 Ctrl + W 保存
```

| 项目 | 值 |
|---|---|
| 变量 | `SaSetup` |
| 偏移 | `0x42B` |
| 取值 | `02` = Auto（出厂） / **`01` = Enabled** / `00` = Disabled |

> 📌 **三态而不是开关**。NullMoth 驱动在 BAR 已开启的情况下是经过验证的配置，所以这里强制写 `01`。
> 📌 另一个相关项 **Above 4G Decoding（`SaSetup + 0x7E`）出厂就是 `01`（开启）**，不需要动。如果后面驱动报 BAR 相关错误，可以回来检查它是否仍为 `01`。

#### 保存并重启

```
按 Ctrl + Alt + Del 重启，让改动生效
```

### 4.3 第二组：CPUSetup 表

重启后**再次进入 RU**（重复 4.1 的步骤），这次在表列表里选 **`CPUSetup`**。

#### ④ 关闭超线程（Hyper-Threading）—— 行 `0`，偏移 `05`，`01 → 00`

```
移动到：第 0 行，列 05
原值：01
改成：00        ← 关闭 HT
按 ← 回到行首，按 Ctrl + W 保存
```

| 项目 | 值 |
|---|---|
| 变量 | `CpuSetup`（GUID `B08F97FF-E6E8-4193-A997-5E9E9B0ADB32`） |
| 偏移 | `0x05` |
| 取值 | `01` = 开启（出厂） / **`00` = 关闭** |

> ❗❗ **这一步不做，百分之百卡在 `[EB|#LOG:EXITBS:START]`。**
>
> 原因：`config.plist` 里带了一组 `_cpu_thread_alloc` 内核补丁（Comment 为 `force HT enabled for …`），它假设 CPU 的 HT 是**关闭**的、由 macOS 按物理核去分配线程。如果 BIOS 里 HT 还开着，这套补丁反而会让内核启动失败。参考：[Reddit 上同一问题的解决方案](https://www.reddit.com/r/hackintosh/comments/1xp8gi4/macos_tahoe_stuck_at_exitbsstart_using_nullmoth/)（评论区给的答案就是 *"just disable hyper threading in bios"*）。
>
> 📌 **副作用**：i5-12450H 从 4P×2 + 4E×1 = **12 线程** 变成 4 + 4 = **8 线程**。macOS 里"关于本机"会显示 8 核。

#### ⑤ 关闭 CFG Lock —— 行 `4`，偏移 `43`，`01 → 00`

```
移动到：第 4 行，列 43
原值：01
改成：00        ← 解锁 MSR 0xE2
按 ← 回到行首，按 Ctrl + W 保存
```

| 项目 | 值 |
|---|---|
| 变量 | `CpuSetup` |
| 偏移 | `0x43` |
| 取值 | `01` = 锁定（出厂） / **`00` = 解锁** |

> ⚠️ **同样是反的**：这一项叫 "CFG Lock"，`01` 是**锁**、`00` 是**解锁**。它控制 MSR `0xE2` 的第 15 位。
> 虽然 `config.plist` 里已经开了 `AppleXcpmCfgLock = true`（用 OpenCore 绕过），但在 RU 里真正解锁更干净，能避免某些电源管理问题（睡眠、变频）。**建议两个都做。**

#### 保存并重启

```
按 Ctrl + Alt + Del 重启
```

### 4.4 改完后的自检清单

重启后可以再进一次 RU 逐项核对，也可以直接往下做（如果第 7 章能进系统，就说明改对了）。

| # | 表 | 行 / 偏移 | 正确值 | 作用 |
|---|---|---|---|---|
| ① | `SaSetup` | 行 7 / `0x7D` | `00` | VT-d 关闭 |
| ② | `SaSetup` | 行 8 / `0x86` | `01` | X2APIC Opt Out（禁用 x2APIC） |
| ③ | `SaSetup` | 第 4 页 / `0x42B` | `01` | Resizable BAR 强制开启 |
| ④ | `CpuSetup` | 行 0 / `0x05` | `00` | **超线程关闭** |
| ⑤ | `CpuSetup` | 行 4 / `0x43` | `00` | CFG Lock 解锁 |

> 📎 另外这两个**出厂就是对的，不用改**（列出来方便你核验）：
> - `SaSetup + 0x7E` = `01` → Above 4G Decoding 开启
> - `SaSetup + 0x87` = `01` → DMA Control Guarantee 开启

> 💡 **RU 写完不生效 / 重启后变回原值？**
> 1. 确认是按 `Ctrl + W` 而不是 `Ctrl + S`；
> 2. 确认你已经**退出管理员密码**（第 1 章第 6 步），带着密码时某些变量会被固件拒绝写入；
> 3. 试试在 RU 里改完后直接 `Ctrl + Alt + Del`（不要走系统正常重启）；

---

## 5. 准备 macOS 系统盘（rdr 恢复法）

rdr 是"恢复版镜像"——不制作安装 U 盘，直接把一个装好的 macOS 系统还原到一个分区里，速度快、对新手友好，而且镜像里自带 winPE，搞坏了还能进 PE 救。

### 5.1 从 Windows 压缩出一个 macOS 分区

1. 右键 **开始 → 磁盘管理**（或 DiskGenius）。
2. 选一块有空间的磁盘 → 右键 → **压缩卷**。
3. 压出 **≥ 64 GB**（建议 **80 GB** 以上）的未分配空间。
4. **不要**在这里新建分区，保持"未分配"状态，交给 rdr 恢复时使用。

> ⚠️ **必须是 GPT 分区表**。MBR 磁盘恢复 rdr 镜像时会报 `APFS 容器只能复制到 GPT`。转换分区表会丢数据，请先备份。

### 5.2 安装 R-Drive Image 7

1. **先退出杀毒软件和 Windows 自带实时防护**（`patch-Astron.exe` / `Keygen.exe` 会被误报）。
2. 解压下载的 `rdr版黑苹果安装工具`，里面通常有 `RDriveImage7.exe`、`patch-Astron.exe`、`Keygen.exe`。
3. 双击 `RDriveImage7.exe` 完成安装，**取消**勾选"发布 R-Drive Image"。
4. 把 `patch-Astron.exe` 复制到软件安装目录（默认 `C:\Program Files (x86)\R-Drive Image`），右键**以管理员身份运行**，点右下角 **Patch**。
5. 打开 `Keygen.exe` 生成注册信息填入（名称随便填邮箱、公司填 `tsz`），完成激活。

### 5.3 恢复 rdr 镜像

1. 打开 R-Drive Image → **恢复映像（Restore）**。
2. 选择你下载的 `Install macOS Tahoe 26.x ... .rdr`。
3. 提示输入映像密码：一般为 **`imacos.top`**。
4. 在分区列表里，你会看到镜像内有 4 个分区：

   ```
   1) OC         ← OpenCore 引导（本仓库的 OpenCore/EFI 更适配你的机器，一般不需要它）
   2) Clover     ← 四叶草引导（备用）
   3) winPE      ← 急救用 PE
   4) macOS系统盘 ← ★ 只需要恢复这一个
   ```

   **只勾选第 4 个（macOS 系统盘）**，目标选择刚才压缩出的未分配空间。
5. 点"下一步"→"启动"，等恢复完成。

> 💡 如果你担心操作失误，可以**把 winPE 分区也恢复出来**（第 3 个），万一引导坏了能进 PE 用 DiskGenius 修启动项。
> 💡 恢复完成后，磁盘管理里会多出一个 `Macintosh HD` 之类的 APFS 分区（Windows 原生不认 APFS，可能显示为"未知分区"，这是正常的）。

---

## 6. 部署 OpenCore EFI

本仓库的 `OpenCore/EFI` 是专门为这台机器生成的，**不要换成网上别的 EFI**。

### 6.1 建一个 EFI 分区（如果还没有）

rdr 镜像通常已经带了一个 EFI 分区。如果没有：

- DiskGenius → 在磁盘上新建一个 **200～300 MB** 的 **FAT32** 分区，分区类型设为 **EFI System Partition (ESP)**。

### 6.2 复制 EFI 目录

1. 用 DiskGenius 的"浏览文件"或直接挂载该 ESP 分区。
2. 把仓库里的 **`OpenCore/EFI`** 整个目录复制到该分区的**根目录**，最终结构：

   ```
   <ESP 分区>\
   └── EFI\
       ├── BOOT\
       │   └── BOOTx64.efi          ← OpenCore 的引导加载器
       └── OC\
           ├── OpenCore.efi
           ├── config.plist
           ├── ACPI\        (11 个 SSDT)
           ├── Drivers\     (OpenCanopy / OpenRuntime / ResetNvramEntry / HfsPlus / apfs_aligned)
           ├── Kexts\       (21 个驱动)
           └── Resources\   (图形界面主题 GoldenGate)
   ```

3. **（可选）把 `create-user.sh` 复制到这张 ESP 分区的根目录**，第 7.3 节要用。
   > 也可以放到 macOS 系统盘的根目录，或者放 U 盘根目录——只要恢复环境的终端里能 `cd` 到就行。

### 6.3 设置 OpenCore 为第一启动项

重复第 3.3 节的三选一方法，这次选择 **`EFI\BOOT\BOOTx64.efi`**，命名为 `OpenCore`，并移到第一位。

### 6.4 检查启动项顺序

最终 BIOS 的启动顺序应该是：

```
1. OpenCore   （ESP 分区里的 EFI\BOOT\BOOTx64.efi）
2. Windows Boot Manager
3. RU         （做完第 4 章后可以删掉）
```

---

## 7. 安装 macOS 与首次进入系统

### 7.1 恢复镜像

rdr 恢复的是**已经安装好的系统**，所以这里不需要跑安装程序，只需要：

1. 重启，选择 **OpenCore**。
2. OpenCore 图形界面（GoldenGate 主题）出现，用方向键选中带苹果图标的 **`Macintosh HD`**，回车。
3. 会出现滚动的内核日志（`-v` 参数是开着的）。
4. 日志跑完后……**画面会变成一个黑屏 + 一个孤零零的光标**。

**这在预期之内**，不是你做错了。原因是：macOS 26 的图形界面（Liquid Glass / Setup Assistant / 登录窗口）需要显卡驱动才能画出来，而 NVIDIA 驱动又只能在系统启动后才能安装——于是死循环。参考视频：[Nullmoth 1401 Guide: macOS Tahoe Black Screen with Cursor After Install](https://www.youtube.com/watch?v=7c1lddOtCY0)。

### 7.2 第一次启动 macOS

进不去桌面，我们就手动"把设置流程走完"：

1. 强制关机（长按电源键 5 秒）。
2. 重新开机 → OpenCore → 选择 **`Recovery xxx`** 进入 **macOS 恢复模式**。
   > 恢复环境的界面是**不会**黑屏的（它不加载 NVIDIA 驱动）。
3. 进入"macOS 恢复"后，顶部菜单选择 **实用工具 → 终端（Utilities → Terminal）**。

### 7.3 黑屏只剩光标：建一个管理员账号

仓库根目录的 `create-user.sh` 就是干这个的：在恢复环境里直接往系统盘的 Data 卷写一个管理员账号，并打上"设置已完成"的标记，这样下次启动就会**直接进桌面**，跳过设置助理。

#### 步骤

1. 确认脚本位置。假设你把它放在了 EFI 分区的根目录，先看看它挂载在哪：

   ```bash
   ls /Volumes
   ```

   一般会看到 `Macintosh HD`、`Macintosh HD - Data`、`EFI`、`Com.apple.recovery.boot` 等。

2. **先看一眼数字锁定**（`NumLk`）！开着的话你输入的密码会被加进数字，导致开机密码永远输错。

   ```bash
   # 如果不知道开没开，就先随便敲一下小键盘上的 7，看屏幕上是不是 7
   ```

3. `cd` 到脚本所在目录（位置是你存 sh 的位置），例如：

   ```bash
   cd "/Volumes/EFI"
   ls                      # 确认能看到 create-user.sh
   ```

   > 路径里有空格一定要加引号。

4. 运行脚本，第一个参数是**短用户名**，第二个是**显示用全名**：

   ```bash
   bash ./create-user.sh username "你想要的用户名"
   ```

   > ⚠️ `你想要的用户名` 请换成你自己的（建议全小写、不要空格、不要中文）。

5. 脚本会去找系统盘的 Data 卷（`/Volumes/*/private/var/db/dslocal/nodes/Default`）。
   - 只找到一个 → 自动使用；
   - 找到多个 → 会列出编号，**输入带 ` - 数据` 字样的那一项对应的数字**，回车。

6. 按提示输入密码两次（输入时屏幕不显示，这是正常的）。

7. 看到类似下面的输出就成功了：

   ```
   Using Data volume: /Volumes/Macintosh HD - Data
   Creating user:     mac (Mac User)
   ...
   Verification:
   UniqueID: 501
   ...
   .AppleSetupDone: present

   Done. Reboot and log in as 'mac'.
   ```

#### 脚本做了什么（想搞懂可以看）

| 动作 | 说明 |
|---|---|
| 定位 Data 卷 | 扫 `/Volumes/*/private/var/db/dslocal/nodes/Default`，找不到就尝试 `diskutil mount` 所有 Data 卷 |
| 检查重复 | 用户已存在就中止，不会覆盖 |
| 建账号 | `dscl -f <node> localhost -create …`，UID `501`、GID `20`、Shell `/bin/zsh` |
| 给管理员权限 | `-append /Local/Default/Groups/admin GroupMembership <user>` |
| 建家目录 | `mkdir -p <Data>/Users/<user>`，`chown 501:20` |
| 跳过设置助理 | `touch <Data>/private/var/db/.AppleSetupDone` |

#### 如果脚本报错

| 报错 | 原因 | 处理 |
|---|---|---|
| `Could not find a Data volume with a local directory node` | Data 卷没挂上 | `diskutil apfs list` 找到 Data 卷编号，`diskutil mount disk0sXsX`，然后重跑；开了 FileVault 的要先在磁盘工具里解锁 |
| `User 'xxx' already exists` | 之前建过了 | 改用别的用户名，或直接重启进系统用这个账号登录 |
| `Passwords are empty or do not match` | 两次输入不一致 | 注意数字锁、慢一点敲 |
| `dscl … failed` | 卷只读 / 被 FileVault 锁住 | 确认挂载点是 `/Volumes/...` 且可写（`touch` 测试一下） |

### 7.4 进桌面并合并剩余空间

1. 终端里输入 `reboot` 或菜单重启。
2. OpenCore → 选 **`Macintosh HD`**。
3. **这次应该能进桌面了。**

> 🔁 **弹出设置选项，点确定、下一步后还是会白屏光标？**
> 这是已知现象，**强制重启几次（1～3 次）** 再进，通常就好了。原笔记作者的记录是"大概 2 次"。
> 如果始终不行，看第 9 章。

4. 进桌面后打开 **磁盘工具（Disk Utility）** → 左上角 **显示 → 显示所有设备**。
5. 选中 `Macintosh HD` → 点右上角 **分区**。
6. 把 macOS 分区**后面的未分配空间**合并进来：在"大小"里直接输入"当前大小 + 未分配空间"（例如 `38.7 + 24.1 = 62.8 GB`），回车 → **应用 → 分区**。

> ⚠️ APFS 分区**只能往后（朝磁盘尾部）扩容**。如果未分配空间在 macOS 分区前面，先把 macOS 分区删了重排（会丢数据！），所以第 5.1 节压缩空间时要注意位置。

---

## 8. 安装 NVIDIA 驱动与各项驱动

### 8.1 前提：确认 config 已就绪

本仓库 `OpenCore/EFI/OC/config.plist` **已经按 NullMoth 的要求配好了**，逐项核对如下（这一节主要用于你手工排错或换 EFI 时对照）：

| 项目 | 要求值 | 本仓库实际值 | 位置 |
|---|---|---|---|
| `boot-args` | 含 `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | ✅ 全部包含（另有 `-v debug=0x100 keepsyms=1` 等调试参数） | `NVRAM → Add → 7C436110-…` |
| `csr-active-config` | `430A0000`（即 `0x0A43`） | ✅ `QwoAAA==` 解码为 `43 0A 00 00` | 同上 |
| `SecureBootModel` | `Disabled` | ✅ `Disabled` | `Misc → Security` |
| `Lilu.kext` / `AMFIPass.kext` | 在 `Kernel → Add` 中且启用 | ✅ 都在（Lilu 1.7.3 / AMFIPass 1.4.1） | `Kernel → Add` |
| `ResizeAppleGpuBars` | `0`（安装/首次启动用小块 BAR） | ✅ `0` | `Booter → Quirks` |
| `ResizeGpuBars` | `-1`（不动固件 BAR） | ✅ `-1` | `UEFI → Quirks` |
| `Kernel → Block` | `com.apple.iokit.IONDRVSupport`（Strategy `Exclude`） | ❌ **为空** | 见下方说明 |
| `nv_disable=1` / `-wegnoegpu` | **不能有** | ✅ 没有 | — |
| `DeviceProperties` 给独显 | 不需要 | ✅ 没有 | — |

> ⚠️ **关于 `Kernel → Block`**：NullMoth 文档要求驱动**装好之后**把 `com.apple.iokit.IONDRVSupport` 以 `Exclude` 策略屏蔽，否则固件帧缓冲会抢到 NVRMFB 的显示索引 0。本仓库的 `config.plist` 这一项是空的。
>
> **建议做法**：先按现状启动并装驱动（`IONDRVSupport` 保留，安装阶段是需要的）；如果装完驱动后出现"画面正常但没有硬件加速 / 显示索引异常 / 黑屏"的现象，再回 EFI 分区，用 **OpenCore Configurator** 或任何 plist 编辑器，在 `Kernel → Block` 里加一条：
>
> | 字段 | 值 |
> |---|---|
> | Identifier | `com.apple.iokit.IONDRVSupport` |
> | Strategy | `Exclude` |
> | Enabled | `true` |
> | MaxKernel / MinKernel | 留空 |
>
> 改完保存，重启。

### 8.2 安装 NullMoth NVIDIA 驱动

**准备工作（必须做）**

在 Windows 下下载 https://download.nvidia.com/XFree86/Linux-x86_64/620.70.06/NVIDIA-Linux-x86_64-620.70.06.run 到 `OpenCore/NullMoth/` 下并命名为 `NVIDIA-Linux-x86_64-620.70.06.run`。


**方式 A：用仓库带的 1401 Mac 应用（推荐）**

1. 把 `OpenCore/NullMoth` 复制到 macOS 里（U 盘 / 共享盘都行），解压 `1401-Mac-3.0.zip`。
2. 拖 `1401 Mac.app` 到"应用程序"。
3. 首次打开如果提示"无法验证开发者"：**系统设置 → 隐私与安全性 → 滚到底 → "仍要打开"** → 输入密码。
4. 打开 App，按它给的步骤走：它会
   - 找到启动这台 Mac 的 OpenCore 分区（`EFI/OC` 或 `EFI/BOOT`，在 EFI 或 FAT32 分区上）；
   - **先展示所有改动**，再备份 `config.plist`（备份名形如 `config.plist.before-1401-<日期>`）；
   - 安装驱动到 `/Library/Extensions` 并重建辅助内核集合（AKC）；
   - 在 OpenCore 启动菜单里加上 `1401: Remove NVIDIA driver` 和 `1401: Start once without NVIDIA driver` 两个救援项。
5. **全程把 OpenCore 所在的磁盘/U 盘插着**，App 改的就是它。
6. 装完**重启**。
   > 第一次带驱动启动时，画面会在 `PCI configuration end` 停最多 1 分钟，这是驱动在等 GPU 起来，**别急着重启**。

**方式 B：命令行动手装（不想用 App 时）**

```bash
# 1) 先解压（补上仓库里缺的那个文件前提，见 8.6）
cd ~/Downloads
tar -xzf nullmoth-nvidia-3.0.tar.gz
cd pkgroot

# 2) 校验（每个文件都要显示 OK）
shasum -a 256 -c SHA256SUMS

# 3) 安装（会重建辅助内核集合）
sudo ./install.sh

# 4) 重启
sudo shutdown -r now
```

macOS 第一次会在 **系统设置 → 隐私与安全性** 底部要求你"允许"这些扩展，点允许后**再重启一次**。

**方式 C：1401 for Windows 生成的在线安装（没装 macOS 时）**

> 这条路径本教程**不推荐**：它需要重新做 U 盘、下载系统，而且会覆盖掉本仓库调好的 EFI。你已经用 rdr 装好了系统，没必要。

### 8.3 验证驱动是否生效

```bash
kmutil showloaded --list-only | grep nullmoth
```
**应该输出 4 行**（NVRM、NVAccel、NVRMFB、NVRMAGDC）。

```bash
system_profiler SPDisplaysDataType | head -20
```
**应该能看到 GeForce 显卡，且 `Metal: Supported`。**

> 📌 **笔记本没有 MUX 的情况**：内屏由 Intel 核显（WhateverXe）驱动，NVIDIA 卡拿不到 `Metal` 设备是**正常的**——它只在需要 GPU 的应用里出现。只有外接显示器才会走 NVIDIA 输出。

### 8.4 Wi-Fi：装 HeliPort

`itlwm.kext` 只提供底层驱动，**不提供连接界面**。必须配合 **HeliPort**：

1. 从 [OpenIntelWireless/itlwm](https://github.com/OpenIntelWireless/itlwm/releases) 下载 `HeliPort.dmg`。
2. 拖进"应用程序"，打开，在菜单栏图标里扫描并连接 Wi-Fi。
3. 想开机自动连，在 HeliPort 设置里勾选"登录时启动"。

> 💡 有线网卡（Realtek RTL8111）已经由 `RealtekRTL8111.kext` 驱动，插网线即用，比 Wi-Fi 稳，**装驱动时优先插网线**。

### 8.5 其他已内置的驱动

这些**不需要你再做任何事**，已经在 `OpenCore/EFI/OC/Kexts` 里且 `config.plist` 里启用了：

| 驱动 | 版本 | 作用 |
|---|---|---|
| `Lilu` | 1.7.3 | 所有补丁的基础框架 |
| `VirtualSMC` + `SMCProcessor` / `SMCSuperIO` / `SMCBatteryManager` / `SMCLightSensor` | 1.3.9 | 模拟 SMC、CPU 温度、风扇转速、电池电量、环境光 |
| `WhateverXe` | 0.8.2 | **Intel 核显驱动（内屏靠它）** |
| `CpuTopologyRebuild` | 2.0.2 | 12 代大小核拓扑修正 |
| `USBToolBox` + `UTBDefault` | 1.2.0 / 1.0 | USB 端口映射 |
| `XHCI-unsupported` | 0.9.2 | 额外 USB 控制器 ID |
| `NVMeFix` | 1.1.4 | NVMe 电源管理（PS5019 是 DRAM-less 盘，很有用） |
| `itlwm` | 2.3.0 | Intel AX201 Wi-Fi |
| `IntelBluetoothFirmware` / `IntelBTPatcher` / `BlueToolFixup` | 2.5.0 / 2.5.0 / 2.7.3 | 蓝牙 |
| `RealtekRTL8111` | 2.4.2 | 有线网卡 |
| `VoodooI2C` / `VoodooI2CHID`（含 GPIO/Services/Input 插件） | 2.9.1 | I2C 触控板 |
| `BrightnessKeys` | 1.0.4 | 亮度快捷键 |
| `RestrictEvents` | 1.1.7 | 隐藏不必要的更新/事件提示 |
| `AMFIPass` | 1.4.1 | 让 AMFI 放行 NullMoth 的内核扩展 |

> ❌ **没包含**：`AppleALC`（声卡）、读卡器驱动、摄像头、指纹。想要声音可以自行加 `AppleALC` + `lilu`，并在 `DeviceProperties` 里给 HDEF 设 `layout-id`。本仓库未验证，请自行测试。

### 8.7 开启系统睡眠要谨慎（该部分由AI生成，未做验证）

NullMoth 驱动的睡眠/唤醒支持是**较新**的功能，笔记本（面板挂在 Intel 核显上，即 `NMIntelFB`）的唤醒路径**尚未覆盖**。如果遇到"睡眠后黑屏需要硬重启"：

```bash
sudo pmset -a sleep 0      # 关掉系统睡眠
```

并且不要用 苹果菜单 → 睡眠。想彻底关掉驱动对电源树的参与，可以在 `boot-args` 里加 `-nvrmnopm`。

### 8.8 常用排错启动参数

在 `config.plist → NVRAM → Add → 7C436110-… → boot-args` 末尾追加：

| 参数 | 作用 |
|---|---|
| `-nvrmnoflip` | 光标移动时桌面闪烁/撕裂 → 关掉零拷贝扫描输出 |
| `-nvrmnopm` | 关掉系统睡眠支持 |
| `-nvrmnobootscreen` | 不截图启动画面 |
| `-nvrmnogo` | 驱动待机，等 `nvrmctl go` 再启动 GPU |
| `gfxrst=4` | 装了 WhateverGreen 时防止启动画面崩溃（本仓库用的是 WhateverXe，**一般不需要**） |
| `-nvoff` | 本次启动不加载驱动（救急用） |

> ⚠️ **改了 `boot-args` 之后**，记得同步在 `NVRAM → Delete` 里加上 `boot-args`，否则旧值可能被 NVRAM 记住而不被覆盖。

### 8.9 想卸载驱动

- **有菜单项**：OpenCore 里选 `1401: Remove NVIDIA driver` → 按 `Y` → 选 macOS，它会自己删掉并重启。
- **没画面但需要卸载**：进恢复模式 → 终端：

  ```bash
  nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:nullmoth-remove=1
  ```

  重启后系统会自己移除驱动。

---

## 9. 排错大全

### 9.1 启动阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| 卡在 **`[EB\|#LOG:EXITBS:START]`** | ① 超线程没关（最常见）<br>② VT-d 没关<br>③ CPU 拓扑/内存映射问题 | 回到第 4 章 ④ 关掉 HT；① 关掉 VT-d；还不行再看下一条 |
| 卡在 **`PCI configuration`** | Above 4G Decoding 没开 / CSM 没关 / BAR 设置不对 | `SaSetup + 0x7E` 应为 `01`；确认 `ResizeAppleGpuBars = 0` |
| 卡在 `EXITBS` 且键盘灯灭 | 同上，多半是 HT 或 VT-d | 同上 |
| **黑屏只有光标（跑完内核日志后）** | macOS 26 画不出设置助理/登录窗口（缺显卡驱动） | 见 [7.3](#73-黑屏只剩光标建一个管理员账号)；也可以先盲打密码试一下 |
| **白屏 + 鼠标** | 同上，或需要重启几次 | 强制重启 1～3 次 |
| 一直重启循环 / 五国 | 多半是 kext 冲突 | 加 `-v` 看最后一行；OpenCore 菜单按空格显示辅助项，试 `Recovery` 或安全模式 |
| 选择器里**看不到 macOS 分区** | `ScanPolicy` / 文件系统问题 | 本仓库 `ScanPolicy = 0`（全部扫描）；确认 `HfsPlus.efi`、`apfs_aligned.efi` 都在 `Drivers` 里 |
| 卡在 `OCB: DMG has been altered` | U 盘/镜像损坏 | 重做镜像 |
| **提示"这台电脑的固件不支持"** / Secure Boot 报错 | Secure Boot 还开着 | 回到第 1 章 |

### 9.2 系统内

| 现象 | 原因 | 处理 |
|---|---|---|
| 装完驱动后**黑屏** | BAR / 显示索引问题 | 加 `-nvrmnoflip`；检查 `Kernel → Block` 是否要加 `IONDRVSupport`（见 8.1） |
| 桌面显示一分钟后就黑屏只剩光标 | 零拷贝扫描输出遇到小 BAR | 加 `-nvrmnoflip` |
| `Metal: Supported` 但应用很卡 | 驱动不支持全部硬件加速 | 预期行为，别指望生产力 |
| **没有声音** | 本仓库没带 `AppleALC` | 自行添加 `AppleALC.kext` 并设置 `layout-id`；或外接 USB 声卡 |
| Wi-Fi 搜不到 / 不会自动连 | `itlwm` 需要 HeliPort | 见 [8.4](#84-wi-fi装-heliport) |
| 蓝牙能开但连不上外设 | 固件未加载 | 确认 `IntelBluetoothFirmware` 已启用；删掉 `bluetoothInternalControllerInfo` 的 NVRAM 值后重启 |
| 电池不显示百分比 | `SMCBatteryManager` 未生效 | 确认 kext 已启用；偶发需重启 |
| 亮度调不了 | `PNLF` SSDT 未匹配 | 确认 `SSDT-PNLF.aml` + `PNLF to XNLF` 补丁都在；用 `BrightnessKeys` 用键盘调 |
| 触控板只能单击、没有手势 | `VoodooI2C` 模式不对 | `boot-args` 里已有 `-vi2c-force-polling`，可尝试去掉看看 |
| 睡眠后黑屏、要长按电源 | 驱动睡眠支持对笔记本内屏未覆盖 | `sudo pmset -a sleep 0` |
| 系统更新后驱动失效 | 内核集合被重建 | 打开 1401 Mac 应用重新安装驱动 |
| `kmutil showloaded \| grep nullmoth` 没有输出 | 驱动没被允许加载 | 系统设置 → 隐私与安全性 → 允许；或 `sudo kmutil load -p <路径>` |

### 9.3 RU / BIOS 阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| RU 里输入数字变成移动光标 | 数字锁没开 | 按 `NumLk` |
| RU 里改了，重启后又变回去 | 没按 `Ctrl + W`，或 BIOS 管理员密码还在 | 保存；删密码后重做（第 1 章） |
| `Alt + =` 没反应 | 在 GRUB 里没进 RU | 确认输的是 `ru.efi`，不是 `RU.efi` |
| 找不到 `SaSetup` 表 | BIOS 版本不对 | 确认版本为 `RMGAD6T0P1313`；旧版需先升级（第 2.2 节） |
| 找不到 `第 4 页 / 42B` | 翻页方式不对 | `Ctrl + PgDn` 是表内翻页，不是 `PgDn` 单独按 |
| 改完开不了机 | 改错了别的字节 | 见 [10.3](#103-应急还原-bios-设置) |
| `fptw64` 报 `Error 167` | BIOS 写保护 | 在 RU 里把 `PchSetup + 0x1C` 改成 `00`；或干脆只用 RU 改 |

### 9.4 分区 / 恢复阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| R-Drive Image 报 **"APFS 容器只能复制到 GPT"** | 磁盘是 MBR | 备份后转 GPT，或换一块盘 |
| 看不到刚压缩出来的空间 | 没刷新 / 分区没归并 | 磁盘管理"重新扫描磁盘"，或删掉中间的小分区 |
| 恢复完 Windows 认不出 APFS 分区 | 正常现象 | 不用管 |
| 建了账号但进系统还是设置助理 | `.AppleSetupDone` 没写进去 | 重新跑脚本，确认 Data 卷选对了 |
| 密码怎么输都不对 | `NumLk` 开着 | 恢复模式里先按 `NumLk` 再重设，或者用 `sudo passwd` 改 |

---

## 10. 附录

### 10.1 本仓库 EFI 详解

#### ACPI（`OpenCore/EFI/OC/ACPI`）

| 文件 | 作用 |
|---|---|
| `SSDT-ALS0.aml` | 环境光传感器（配合 `SMCLightSensor`） |
| `SSDT-EC.aml` | 伪造 EC 设备（macOS 必需） |
| `SSDT-GPI0.aml` | I2C GPIO 控制器（触控板） |
| `SSDT-MCHC.aml` | 内存控制器设备 |
| `SSDT-PLUG-ALT.aml` | CPU 电源管理 `plugin-type = 1` |
| `SSDT-PNLF.aml` | 屏幕背光控制 |
| `SSDT-SBUS.aml` | `SMBus` / `SBUS` 补全 |
| `SSDT-RTCAWAC.aml` | RTC 唤醒修正 |
| `SSDT-USB-Reset.aml` | USB 端口复位（内建修复） |
| `SSDT-USBX.aml` | USB 电源属性（充电速度） |
| `SSDT-XOSI.aml` | Windows 兼容判断（配合 `_OSI to XOSI` 重命名） |

**ACPI → Patch 里的重命名**：`GPI0 _STA → XSTA`、`H_EC _STA → XSTA`、`PNLF → XNLF`、`_OSI → XOSI`。
**ACPI 末尾还有一批 `Hide processor PR12～PR63` 的重命名**，用来把 MADT 里没启用的逻辑处理器（对应被关掉的超线程/E 核）隐藏掉，配合 `CpuTopologyRebuild` 让 macOS 认成正确的物理核。

#### Drivers

| 文件 | 作用 |
|---|---|
| `HfsPlus.efi` | 读取 HFS+ 卷（恢复镜像用） |
| `OpenCanopy.efi` | 图形化启动选择器（GoldenGate 主题） |
| `OpenRuntime.efi` | 运行时服务（**必须有**） |
| `ResetNvramEntry.efi` | 选择器里的"重置 NVRAM"入口 |
| `apfs_aligned.efi` | APFS 驱动 |

#### 关键 Quirks（`config.plist`）

| 位置 | 键 | 值 | 说明 |
|---|---|---|---|
| `Booter → Quirks` | `AllowRelocationBlock` | `true` | 分配重定位块 |
| | `AvoidRuntimeDefrag` | `true` | 避免运行时内存整理（必需） |
| | `DevirtualiseMmio` | `false` | 笔记本上关闭 |
| | `RebuildAppleMemoryMap` | `true` | 重建内存映射 |
| | `ResizeAppleGpuBars` | `0` | 安装阶段用小 BAR |
| | `SetupVirtualMap` | `true` | 必需 |
| | `SyncRuntimePermissions` | `true` | 同步运行时权限 |
| `Kernel → Quirks` | `AppleXcpmCfgLock` | `true` | 绕过 CFG Lock |
| | `DisableIoMapper` | `true` | 绕过 IOMMU（所以需要关 VT-d） |
| | `DisableLinkeditJettison` | `true` | 配合 Lilu |
| | `ProvideCurrentCpuInfo` | `true` | 12 代必需 |
| | `SetApfsTrimTimeout` | `-1` | 关闭 APFS TRIM 超时判断 |
| `Kernel → Patch` | `force HT enabled for …` ×3 | 启用 | `_cpu_thread_alloc` 补丁，**前提是 BIOS 里 HT 已关** |
| `UEFI → Quirks` | `ResizeGpuBars` | `-1` | 不动固件 BAR |
| `PlatformInfo` | `SystemProductName` | `MacBookPro16,2` | SMBIOS 机型 |
| `Misc → Security` | `SecureBootModel` | `Disabled` | 必需 |
| `Misc → Boot` | `PickerMode` | `External` | 用 OpenCanopy |
| | `Timeout` | `5` | 选择器 5 秒自动启动 |

> 📌 **SMBIOS 说明**：本仓库用的是 `MacBookPro16,2`（**不是** NullMoth 官方教程里的 `iMacPro1,1`）。`MacBookPro16,2` 是带核显的笔记本机型，正好对应"内屏走 Intel、独显做算力"的这台机器；`iMacPro1,1` 是无核显的台式机型，套在笔记本上反而会出问题。**保持现状，不要改。**
> 📌 里面的 `SystemSerialNumber` / `SystemUUID` 是**示例值**，同一份 EFI 在多台机器上用会导致 iCloud 冲突。介意的话用 OpenCore Configurator 生成新的（`PlatformInfo → 生成`）。

### 10.2 config.plist 关键值对照表

| 需求 | 变量 / 偏移 | 取值 | 本仓库 |
|---|---|---|---|
| VT-d | `SaSetup + 0x7D` | 1=开 / 0=关 | 需改成 `0` |
| Above 4G Decoding | `SaSetup + 0x7E` | 1=开 / 0=关 | 出厂 `1` ✓ |
| X2APIC Opt Out | `SaSetup + 0x86` | **1=禁用 / 0=可用（反向）** | 需改成 `1` |
| DMA Control Guarantee | `SaSetup + 0x87` | 1=开 / 0=关 | 出厂 `1` ✓ |
| Resizable BAR | `SaSetup + 0x42B` | 0=关 / 1=开 / **2=Auto** | 需改成 `1` |
| CFG Lock | `CpuSetup + 0x43` | **1=锁定 / 0=解锁（反向）** | 需改成 `0` |
| Hyper-Threading | `CpuSetup + 0x05` | 1=开 / 0=关 | 需改成 `0` |
| CSM | — | 本平台**不存在**该开关 | — |

**变量 GUID**

- `SaSetup`：`72C5E28C-7783-43A1-8767-FAD73FCCAFA4`，长度 `0x477`
- `CpuSetup`：`B08F97FF-E6E8-4193-A997-5E9E9B0ADB32`，长度 `0x379`

> 📎 这张表来自 `bios-analytics-tool/dsh-analytics-session.md` 的逆向记录。想自己复核或者换机型时，按那个文件里的方法做：
> 1. `UEFIFind.exe` / `UEFIExtract.exe` 切出 BIOS 区；
> 2. 找到 LZMA 压缩段（GUID 定义段 `EE4E5898-…`）并用 Python `lzma` 解开（原始 `ifrextractor.exe` 会报 "No IFR data found"，因为 Setup 表单在压缩段里）；
> 3. `ifrextractor.exe` 导出 IFR 文本；
> 4. 在 IFR 里找 `OneOf "选项名"` 的 `VarStoreId` 与 `VarOffset`。
>
> ⚠️ `ifrextractor ... all` 会把 form package 和 string package **乱配**，绝大多数组合是错的（比如把 `ACPI Debug` 显示成 `Boot Type`）。判断依据是表单标题和选项语义是否自洽。

### 10.3 应急还原 BIOS 设置

如果改错字节导致开不了机：

1. **先试放电**：断电，长按电源键 30 秒；或拆后盖拔主板电池 1 分钟。部分机型会重置 Setup 变量。
2. **用 U 盘还原**：
   - 重启进 RU（第 3 章的分区还在的话）；
   - 把第 4.4 节表里的项**改回出厂值**（`SaSetup 0x7D=01`、`0x86=00`、`0x42B=02`；`CpuSetup 0x05=01`、`0x43=01`）；
   - `Ctrl + W` 保存。
3. **刷回备份**：如果你做了第 2.1 节的备份，在能进 BIOS / PE 的情况下用 `fptw64.exe -f backup.fd` 刷回。
4. **最坏情况**：需要拆机用编程器（CH341A 等）刷 SPI Flash，或者返厂。

> 💡 **一条经验**：RU 里改错一个字节通常不会立刻变砖（Setup 变量是可重建的），真正危险的是**刷写 SPI Flash**。所以第 4 章只改变量、不刷固件，相对安全。

### 10.4 参考链接

**本项目内**

- [OpenCore/README.md](OpenCore/README.md) —— EFI 与 NVIDIA 驱动说明
- [RU-tools/README.md](RU-tools/README.md) —— RU 安装方法
- [bios-backup-tools/README.md](bios-backup-tools/README.md) —— BIOS 备份说明
- [bios-resources/README.md](bios-resources/README.md) —— 官方 BIOS 与版本匹配要求
- [bios-analytics-tool/dsh-analytics-session.md](bios-analytics-tool/dsh-analytics-session.md) —— 偏移量逆向全过程
- [create-user.sh](create-user.sh) / [OpenCore/NullMoth/finish-setup.sh](OpenCore/NullMoth/finish-setup.sh) —— 建账号脚本

**外部**

- [nullmoth/1401](https://github.com/nullmoth/1401) —— Windows 端 EFI 生成工具（本仓库 EFI 的来源）
- [nullmoth/nvidia-macos-driver](https://github.com/nullmoth/nvidia-macos-driver) —— NVIDIA 驱动本体
- [驱动故障排查文档](https://github.com/nullmoth/nvidia-macos-driver/blob/main/docs/TROUBLESHOOTING.md) —— 最常见问题的官方答案
- [显卡支持列表](https://github.com/nullmoth/nvidia-macos-driver/blob/main/docs/CARD-SUPPORT.md)
- [睡眠/唤醒说明](https://github.com/nullmoth/nvidia-macos-driver/blob/main/docs/SLEEP-WAKE.md)
- [1401 工作原理](https://github.com/nullmoth/1401/blob/main/docs/HOW-IT-WORKS.md)
- [黑苹果屋：NVIDIA 1401 驱动教程](https://imacos.top/2026/10/23/1401/) / [1401 for Mac v3.0](https://imacos.top/2026/11/16/1401-for-mac-v3-0/)
- [黑苹果屋：rdr 双系统安装教程](https://imacos.top/2025/10/20/rdr-mac/)
- [B 站：RU 使用教程（12/13/14 代 Intel 笔记本）](https://www.bilibili.com/video/BV12XATehE4b)（原笔记引用 / `BV1RzHG6SEpP` 为 1401 教程）
- [Reddit：macOS Tahoe 卡 EXITBS:START（关超线程）](https://www.reddit.com/r/hackintosh/comments/1xp8gi4/macos_tahoe_stuck_at_exitbsstart_using_nullmoth/)
- [YouTube：装完黑屏只剩光标的解决办法](https://www.youtube.com/watch?v=7c1lddOtCY0)
- [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/)（想手工搭 EFI 时看这个）

---

## 附：一页纸速查

```
① BIOS：设管理员密码 → 关 Secure Boot → F10 → 删管理员密码
② （可选）FPTW64 -d backup.fd；已旧版则跑 RMGAD6T0P1313.exe 升级
③ DiskGenius 建 50MB FAT32 → 放 RU-tools\EFI → 设为第一启动项
④ RU.efi：
     SaSetup  行7  7D=00   (关 VT-d)
     SaSetup  行8  86=01   (X2APIC Opt Out)
     SaSetup  第4页 42B=01 (ReBAR)
     CpuSetup 行0  05=00   (关超线程) ★关键
     CpuSetup 行4  43=00   (解 CFG Lock)
     每次 Ctrl+W 保存，最后 Ctrl+Alt+Del
⑤ 压缩 ≥64GB → R-Drive Image 恢复 rdr 里的"macOS 系统盘"
⑥ 把 OpenCore\EFI 复制到 ESP 根目录 → OpenCore 设为第一启动项
⑦ 启动 macOS（黑屏只有光标是正常的）
     → Cmd+R 进恢复 → 终端 → cd 到 create-user.sh → NumLk 确认
     → bash ./create-user.sh mac "Mac User" → 选 "- Data" 卷 → 输两次密码
     → 重启，进桌面（可能要多强制重启几次）
⑧ 装 1401-Mac-3.0 → 装 NVIDIA 驱动 → 重启（等 1 分钟）
     → 装 HeliPort 连 Wi-Fi
     → 验证：kmutil showloaded --list-only | grep nullmoth   （应有 4 行）
```
