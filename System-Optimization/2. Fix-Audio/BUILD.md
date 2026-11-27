# 修补版来源、构建与验证

## 固定版本

| 项目 | 版本 / commit |
| --- | --- |
| IntelSSTDMIC 基线 | `1.0.3` / `d30794efa718c004fb046fa318bb7baab719d01d` |
| 本地标记 | `simplehda-diagnostic-1`；CFBundleVersion 仍为 `1.0.3` |
| Lilu 编译头文件 | `0249c3a918c68a43891350f35fded615b1575776`，工程版本 1.7.3；当时没有官方 1.7.3 release tag |
| MacKernelSDK | `3f750085caa17ec3a7880f11c11bf4f48cd6a164` |
| 参考 SimpleHDA | `v1.0.1` / `18a16d43b85fd90118ab7307f92a8b46aecd501a` |
| 构建环境 | macOS x86_64，Xcode Command Line Tools，Apple clang 17.0.0 |

Lilu源码固定版本用于编译验证，不能据此声称已知本机Lilu二进制的精确构建commit。

## 本目录保存什么

- [完整补丁](<Patches/IntelSSTDMIC-1.0.3-simplehda.patch>)：五个文件的统一diff。
- [源文件副本](<Source/IntelSSTDMIC>)：修改后的五个文件；与补丁结果一致。
- [可部署驱动](<IntelSSTDMIC.kext>)：本机成功录音的构建。
- [host测试](<Tests/test_identity.py>)：从真实修改函数提取代码，在用户态mock属性对象上验证。
- [哈希清单](<SHA256SUMS>)：包括二进制、源码、补丁、配置和说明等。

只保存变更源码，不复制整套SDK、Lilu、上游固件或构建中间文件。构建需要获取完整上游源码及其内嵌固件。

## 从固定源码构建

以下命令在**新建的独立构建目录**运行，不在EFI中运行。安装需要另行备份和操作，构建本身不会修改EFI。

```sh
# 用本仓库音频目录的实际绝对路径替换
AUDIO_DIR="/absolute/path/to/Redmi-G-OpenCore/System-Optimization/2. Fix-Audio"

git clone https://github.com/qqaoshi888/IntelSSTDMIC.git
git -C IntelSSTDMIC checkout d30794efa718c004fb046fa318bb7baab719d01d

git clone https://github.com/acidanthera/Lilu.git
git -C Lilu checkout 0249c3a918c68a43891350f35fded615b1575776

git clone https://github.com/acidanthera/MacKernelSDK.git
git -C MacKernelSDK checkout 3f750085caa17ec3a7880f11c11bf4f48cd6a164

# 将Lilu源码整理成插件所需的Headers/Library布局
mkdir LiluResources
cp -R Lilu/Lilu/Headers LiluResources/Headers
cp -R Lilu/Lilu/Library LiluResources/Library
cp Lilu/hde/hde32.h Lilu/hde/hde64.h LiluResources/Headers/

patch --dry-run -d IntelSSTDMIC -p1 -i "$AUDIO_DIR/Patches/IntelSSTDMIC-1.0.3-simplehda.patch"
patch -d IntelSSTDMIC -p1 -i "$AUDIO_DIR/Patches/IntelSSTDMIC-1.0.3-simplehda.patch"

SDK_DIR="$PWD/MacKernelSDK"
LILU_DIR="$PWD/LiluResources"
make -C IntelSSTDMIC/kext SDK="$SDK_DIR" LILU="$LILU_DIR"
```

注意：上游Makefile会重建其 `kext/build/IntelSSTDMIC.kext`，只应在你刚创建的独立源码副本内执行。不要把SDK指向系统内核目录。首次构建网络获取与依赖需自行确认。

补丁会发布运行态 `CompatibilityBuild=simplehda-diagnostic-1`。本目录附带构建还在驱动元数据中增加 `IntelSSTDMICCompatibilityBuild`，便于未加载时识别。可在独立构建完成后执行：

```sh
/usr/libexec/PlistBuddy -c 'Add :IntelSSTDMICCompatibilityBuild string simplehda-diagnostic-1' \
  IntelSSTDMIC/kext/build/IntelSSTDMIC.kext/Contents/Info.plist
codesign --force --sign - IntelSSTDMIC/kext/build/IntelSSTDMIC.kext
codesign --verify --strict --verbose=2 IntelSSTDMIC/kext/build/IntelSSTDMIC.kext
plutil -lint IntelSSTDMIC/kext/build/IntelSSTDMIC.kext/Contents/Info.plist
```

若已设置元数据，不要重复Add。重新签名后，上游make生成的旧zip不会自动更新，应从最后的kext重新打包。代码/SDK/工具链/链接UUID和签名差异会改变二进制哈希，**本说明不承诺跨环境字节级可复现**。

## 回归测试

在本音频目录执行：

```sh
python3 Tests/test_identity.py
shasum -a 256 -c SHA256SUMS
```

host测试在新的临时目录生成、编译并执行一个小程序；不会安装kext、访问麦克风或写EFI。覆盖原始内麦key、中文/英文/其他语言、线路输入、耳麦、缺属性、零计数、null和错误属性类型共10例，还检查目标ID过滤、无范围路由和PCI祖先约束仍存在。

host测试不是内核运行测试；本机实际录音确认与计数证据见 [成功记录](<Diagnostics/recording-success-2026-11-27.json>)。

## 二进制身份

本目录已验证驱动可执行文件SHA256：

```text
cefa33991f512e2d192091e1a9b2e02a6a4a9822e9a67fdfc8b7f6b7fa46c0b3
```

这一哈希与部署到本机并恢复录音的构建一致。它是本地修补版，不是官方1.0.3发布包的哈希。

## 调试字段

- `HookTargetKextCb` / `HookIgnoredKextCb`：目标与非目标事件分离。
- `HookRunningInfoError`：在清除旧错误前保存Lilu运行镜像状态。
- `HookSymbolMask`：bit0 convert、bit1 init、bit2 start、bit3 stop、bit4 stopHardware、bit5 format，全部成功为63。
- `HookSymbol*Address` / `HookSymbol*Error`：逐符号诊断；公开日志前删除内核地址。
- `HookRouteEngine`：五个生命周期hook掩码，全部成功为31。

这些修改没有替换SOF固件、重做DSP算法或硬编码AppleHDA原始文件地址。上游回调与本地化两处问题是明确证据；联合部署成功并不能替代每个修改的独立A/B归因。
