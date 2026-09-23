# Installs proj for the current user: creates ~/.proj/bin, the proj.bat command, and adds the folder to PATH.
$ErrorActionPreference = 'Stop'

$projHome = if ($env:PROJ_HOME) { $env:PROJ_HOME } else { Join-Path $HOME '.proj' }
$binDir = Join-Path $projHome 'bin'
$script = Join-Path $PSScriptRoot 'proj.ps1'

New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# Prefer pwsh (PowerShell 7) when present, otherwise the Windows PowerShell that ships with Windows.
$shim = @"
@echo off
where pwsh >nul 2>nul
if errorlevel 1 goto winps
pwsh -NoProfile -ExecutionPolicy Bypass -File "$script" %*
exit /b %errorlevel%
:winps
powershell -NoProfile -ExecutionPolicy Bypass -File "$script" %*
"@
[IO.File]::WriteAllText((Join-Path $binDir 'proj.bat'), ($shim -replace "`r?`n", "`r`n"), [Text.Encoding]::ASCII)

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = @($userPath -split ';' | Where-Object { $_ })
if ($entries -notcontains $binDir) {
    # Put it first: a very long PATH can get truncated and lose its last entries.
    [Environment]::SetEnvironmentVariable('Path', (@($binDir) + $entries) -join ';', 'User')
    Write-Host "Added to PATH: $binDir"
}

Write-Host "proj installed. Open a new terminal and run: proj"
