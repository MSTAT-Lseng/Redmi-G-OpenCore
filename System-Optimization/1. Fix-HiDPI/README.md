## Fix-HiDPI

设置方法：
 - 打开 1401软件，挂载 EFI 磁盘（我的 EFI **不是**从 U 盘引导的）。
![QQ_2026-11-19_09-30-09.png](https://files.seeusercontent.com/2026/11/19/p7lT/QQ_2026-11-19_09-30-09.png)
 - 启用 `BUILT-IN SCREEN BRIGHTNESS (LAPTOPS)` 和 `HIDPI (RETINA) MODES`。两个都需要输入密码。
 - 启用后执行下面的命令
```
cd（display-override 文件存放的目录）
sudo ./install-override.sh
```
 - 执行完毕后重启，使用 **BetterDisplay** 即可调节更多 HiDPI 分辨率。
