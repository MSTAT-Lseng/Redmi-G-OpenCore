## Fix-Network-Location

目前 26.0Tahoe 仅能支持 itlwm+HeliPort 的方式，此种方式不是 **macOS 原生 Wifi 驱动**，系统设置里看不到 WiFi，且定位服务也不能用。
修复方法：

 - 在设置中升级 **macOS26.7.1** 及以上（macOS26）版本。
 - 前往 https://github.com/laobamac/itlwm/releases/tag/v2.4.0-alpha 下载 Tahoe Release 版本
 - 根据 https://www.bilibili.com/video/BV1YRHt6RE3B/ 安装（注意：需要禁用 itlwm、启用 AirportItlwm）
 - 重启即可获得原生 WiFi 体验和定位服务
