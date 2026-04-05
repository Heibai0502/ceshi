Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSCommandPath
$sourceScript = Join-Path $projectRoot "LuoKe.ahk"
$iconPath = Join-Path $projectRoot "Luoke.ico"
$distRoot = Join-Path $projectRoot "dist"
$releaseDir = Join-Path $distRoot "release"
$outputExe = Join-Path $releaseDir "LuoKeAuto.exe"

$compilerCandidates = @(
    $env:AUTOHOTKEY_COMPILER,
    "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
    "C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe",
    "C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe",
    (Join-Path $env:LOCALAPPDATA "AutoHotkey\Compiler\Ahk2Exe.exe")
) | Where-Object { $_ -and $_.Trim() -ne "" }

$compilerPath = $compilerCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $compilerPath) {
    throw "Ahk2Exe.exe not found. Install the AutoHotkey compiler or set AUTOHOTKEY_COMPILER."
}

$baseCandidates = @(
    $env:AUTOHOTKEY_BASE,
    "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
    "C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe",
    "C:\Program Files\AutoHotkey\AutoHotkey.exe"
) | Where-Object { $_ -and $_.Trim() -ne "" }

$basePath = $baseCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $basePath) {
    throw "Base AutoHotkey executable not found. Install AutoHotkey v2 or set AUTOHOTKEY_BASE."
}

if (-not (Test-Path $sourceScript)) {
    throw "Main script not found: $sourceScript"
}
if (-not (Test-Path $iconPath)) {
    throw "Icon file not found: $iconPath"
}

Remove-Item $releaseDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

Write-Host "Compiler:" $compilerPath
Write-Host "Base:" $basePath
Write-Host "Icon:" $iconPath
$argLine = "/base `"$basePath`" /in `"$sourceScript`" /out `"$outputExe`" /icon `"$iconPath`" /silent verbose"
$proc = Start-Process -FilePath $compilerPath -ArgumentList $argLine -Wait -PassThru
$exitCode = [int]$proc.ExitCode

$waitMs = 0
while ($waitMs -lt 5000 -and -not (Test-Path $outputExe)) {
    Start-Sleep -Milliseconds 250
    $waitMs += 250
}
if (-not (Test-Path $outputExe)) {
    throw "EXE build failed."
}
if ($exitCode -ne 0) {
    Write-Warning "Ahk2Exe returned exit code $exitCode, but the EXE was created successfully. Continuing packaging."
}

foreach ($name in @("README.md", "LICENSE")) {
    $path = Join-Path $projectRoot $name
    if (Test-Path $path) {
        Copy-Item $path $releaseDir -Recurse -Force
    }
}

Write-Host "Build complete:" $releaseDir
