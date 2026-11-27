# 第三方许可与来源

本地修补版基于 [IntelSSTDMIC 1.0.3](https://github.com/qqaoshi888/IntelSSTDMIC/tree/1.0.3)，保留上游作者版权声明。驱动及本目录修改源文件/补丁遵循随附的 [BSD 3-Clause 许可](<IntelSSTDMIC-BSD-3-Clause.txt>)。

驱动二进制包含上游提供的TGL、CML、ADL Intel SOF固件，未修改固件内容。固件单独适用 [LICENCE.Intel](<LICENCE.Intel>)，不应将驱动源码许可证当成固件的唯一许可证。

固件许可文本取自 [thesofproject/sof-bin](https://github.com/thesofproject/sof-bin/blob/main/LICENCE.Intel)，获取日期2026-11-27，Git blob：`f1e086a735ec31a0594caaa6ff5b3f423574bef4`。上游驱动LICENSE末尾仍引用旧目录名；本地未擅改版权文本，采用此说明补充当前内嵌固件范围。

本目录原有AppleALC、SimpleHDA及可选HAL安装包保持原样，各自版权和许可归其上游所有：

- https://github.com/acidanthera/AppleALC
- https://github.com/laobamac/SimpleHDA

本地修补不是上游作者或Apple背书，ad-hoc签名不代表Apple审核。
