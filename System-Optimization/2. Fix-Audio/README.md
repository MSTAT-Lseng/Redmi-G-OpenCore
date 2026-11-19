## Fix-Audio

修复音频问题。默认 1401 提供的 OpenCore 不包含声卡。

 - 将 `AppleALC.kext` 和 `SimpleHDA.kext` 放在 `EFI/OC/Kexts` 下
 - 替换 `config.plist` 到 `EFI/OC/` 下
 - 安装 `SimpleHDA-HAL-1.0.1.pkg`
 - 重启

重启后进设置 -> 声音
 - 输出选择 **内置扬声器**
 - 输入选择 **线路输入**

注意：**由于 macOS 系统原因，内建麦克风无法获得外界声音，如果需要录制声音，需要插入 3.5mm 麦克风或带录制功能的耳机。**
