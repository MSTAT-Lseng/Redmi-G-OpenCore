#Requires -RunAsAdministrator
<#
    RMGAD6T0P1313.exe -> 提取 BIOS .fd
    需要管理员权限运行。

    背景结论（静态分析已完成）:
      * RMGAD6T0P1313.exe 是 Insyde H2OFFT 的 7zS.sfx 4.57 自解压包 (go32/DJGPP 构建的 x64 PE)
      * SFX 配置段在 0x90400，RunProgram="H2OFFT-Wx64.exe -sfx7z %%S execApp"
      * 载荷从文件偏移 0x90476 开始 (即 ';!@InstallEnd@!' + CRLF 之后)
      * 载荷是 Insyde 自定义加密容器，不是标准 7z:
            magic  = 6E F4 79 5F 4E 38
            version= 00 04
            其余   = 全加密 (熵 = 8.00 bits/byte，大小 mod 16 = 6)
        官方 7-Zip 25.01 无法识别，没有 7z 签名，加载器无 CryptoAPI 导入
        => 解密逻辑内置于 H2OFFT-Wx64.exe，密钥也在其中
      * 因此提取路径 = 拿到 H2OFFT-Wx64.exe，让它自己解包 (-sfx7z)

    本脚本做的事:
      1) 在 %TEMP% / C:\Windows\Temp 找 SFX 解压目录 (7zS*)
      2) 找到 H2OFFT-Wx64.exe 及同目录的载荷/.fd
      3) 若目录已被清理，从运行中的 H2OFFT 进程内存 dump 出 exe
      4) 把找到的东西全部复制到本脚本同目录的 _extracted\ 下

    使用方法：
      1) 先启动 BIOS 更新程序
      2) 再以管理员运行本 ps1 脚本
      3) 根据提示获得 BIOS 镜像
#>

$ErrorActionPreference = 'Continue'
$dest   = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $dest '_extracted'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Log($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)  { Write-Host "[+] $m" -ForegroundColor Green }
function Bad($m) { Write-Host "[!] $m" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 0. 权限检查
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Bad "没有管理员权限，请以管理员身份重新运行本脚本。"
    exit 1
}
Ok "管理员权限确认: $($id.Name)"

# ---------------------------------------------------------------- 1. 找 SFX 解压目录
Log "搜索 SFX 解压目录 (7zS*) ..."
$roots = @(
    $env:TEMP,
    'C:\Windows\Temp',
    "$env:SystemDrive\Temp",
    'C:\Windows\System32\config\systemprofile\AppData\Local\Temp',
    'C:\Windows\SysWOW64\config\systemprofile\AppData\Local\Temp'
) | Where-Object { Test-Path $_ }

$sfxDirs = @()
foreach ($r in $roots) {
    $d = Get-ChildItem $r -Directory -Force -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -like '7zS*' -or $_.Name -like '*sfx*' }
    foreach ($x in $d) { $sfxDirs += $x; Log "  发现: $($x.FullName)" }
}
if (-not $sfxDirs) { Bad "没有找到 7zS* 目录（SFX 可能已清理）" }

# ---------------------------------------------------------------- 2. 检查这些目录内容
$h2offtPath = $null
foreach ($d in $sfxDirs) {
    $files = Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Log "    $($f.Length)`t$($f.Name)"
        if ($f.Name -like 'H2OFFT*.exe') { $h2offtPath = $f.FullName }
    }
}

# ---------------------------------------------------------------- 3. 全盘找 H2OFFT-Wx64.exe / .fd
if (-not $h2offtPath) {
    Log "解压目录里没有 H2OFFT，全盘搜索 ..."
    foreach ($drv in (Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root)) {
        $r = Get-ChildItem $drv -Include 'H2OFFT-Wx64.exe', '*.fd' -Recurse -File -Force `
                 -ErrorAction SilentlyContinue -Depth 8 | Select-Object -First 20
        foreach ($f in $r) {
            Log "    $($f.Length)`t$($f.FullName)"
            if ($f.Name -like 'H2OFFT*.exe' -and -not $h2offtPath) { $h2offtPath = $f.FullName }
        }
    }
}

# ---------------------------------------------------------------- 4. 从运行中的进程 dump
if (-not $h2offtPath) {
    Log "磁盘上没有 H2OFFT，尝试从运行中的进程 dump ..."
    $proc = Get-Process -Name 'H2OFFT-Wx64' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        Ok "找到运行中的 H2OFFT-Wx64 (PID $($proc.Id))"
        try {
            $mod = $proc.Modules | Where-Object { $_.ModuleName -like 'H2OFFT*' } | Select-Object -First 1
            if ($mod) {
                Ok "模块路径: $($mod.FileName)"
                $h2offtPath = $mod.FileName
                if (Test-Path $mod.FileName) {
                    Copy-Item $mod.FileName (Join-Path $outDir 'H2OFFT-Wx64.exe') -Force
                    Ok "已复制到 $outDir\H2OFFT-Wx64.exe"
                } else {
                    Bad "模块文件已被删除，需要内存 dump（见下方说明）"
                }
            } else {
                Bad "无法枚举该进程模块"
            }
        } catch {
            Bad "枚举模块失败: $($_.Exception.Message)"
        }
        Log "  进程命令行:"
        (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)").CommandLine
        Log "  进程工作目录(PEB) 需要额外工具读取"
    } else {
        Bad "没有运行中的 H2OFFT-Wx64 进程"
    }
}

# ---------------------------------------------------------------- 5. 复制一切有用的东西
Log "复制结果到 $outDir ..."
$copied = 0
foreach ($d in $sfxDirs) {
    Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Copy-Item $_.FullName -Destination (Join-Path $outDir $_.Name) -Force -ErrorAction Stop
            $copied++
        } catch { }
    }
}
if ($h2offtPath -and (Test-Path $h2offtPath)) {
    Copy-Item $h2offtPath (Join-Path $outDir (Split-Path $h2offtPath -Leaf)) -Force
    $copied++
}
Ok "复制了 $copied 个文件"

# ---------------------------------------------------------------- 6. 列出最终结果
Write-Host ""
Log "===== $outDir 内容 ====="
Get-ChildItem $outDir -Force | Select-Object Length, LastWriteTime, Name | Format-Table -AutoSize

# ---------------------------------------------------------------- 7. 若拿到 H2OFFT，尝试解包
$h2 = Join-Path $outDir 'H2OFFT-Wx64.exe'
$payload = Join-Path $dest 'RMGAD6T0P1313.exe'
if ((Test-Path $h2) -and (Test-Path $payload)) {
    Write-Host ""
    Log "尝试用 H2OFFT 自身解开载荷 (-sfx7z) ..."
    Log "  用法: H2OFFT-Wx64.exe -sfx7z <SFX文件> <输出目录>"
    & $h2 '-sfx7z' $payload $outDir 2>&1 | ForEach-Object { Write-Host "    $_" }
    Log "  如无输出，请检查 $outDir 下是否出现 BIOSB.bin 文件或 .fd 文件，该文件就是 BIOS 镜像。"
} else {
    Write-Host ""
    Bad "未拿到 H2OFFT-Wx64.exe，无法自行解包。"
    Write-Host @"
下一步建议:
  A) 以管理员运行本脚本，若 %TEMP%\7zS* 目录还在，会直接抓到 H2OFFT-Wx64.exe
  B) 若目录已清理，用 Sysinternals ProcMon 监控 H2OFFT 的文件读取，定位载荷路径
  C) 用 Process Hacker / procdump 对 PID 做完整内存 dump，再从内存镜像里 carve 出 PE
"@
}
