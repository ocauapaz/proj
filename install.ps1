# Instala o proj pro usuario atual: cria ~/.proj/bin, o comando proj.bat e coloca a pasta no PATH.
$ErrorActionPreference = 'Stop'

$projHome = if ($env:PROJ_HOME) { $env:PROJ_HOME } else { Join-Path $HOME '.proj' }
$binDir = Join-Path $projHome 'bin'
$script = Join-Path $PSScriptRoot 'proj.ps1'

New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# Usa pwsh (PowerShell 7) se existir, senao o Windows PowerShell que vem com o Windows.
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
    # No inicio do PATH: um PATH longo pode ser truncado e perder as entradas do final.
    [Environment]::SetEnvironmentVariable('Path', (@($binDir) + $entries) -join ';', 'User')
    Write-Host "Adicionado ao PATH: $binDir"
}

Write-Host "proj instalado. Abra um terminal novo e rode: proj"
