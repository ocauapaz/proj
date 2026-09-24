# Quick test: runs proj against a temporary PROJ_HOME and HOME and checks the base/add/list/rm flow.
$ErrorActionPreference = 'Stop'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "proj-test-$PID"
$env:PROJ_HOME = Join-Path $tmp 'home'
$proj = Join-Path $PSScriptRoot 'proj.ps1'
$base = New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'Base With Spaces')
$fallback = Join-Path $HOME 'projects'

function Assert($condition, $message) { if (-not $condition) { throw "FAILED: $message" } }
function Read-Json { Get-Content (Join-Path $env:PROJ_HOME 'config.json') -Raw | ConvertFrom-Json }
function Read-Bat($name) { Get-Content (Join-Path $env:PROJ_HOME "bin\$name.bat") }

try {
    Assert ((& $proj base) -match [regex]::Escape($fallback)) 'fresh install lists ~/projects as default'

    & $proj base add r $base.FullName | Out-Null
    Assert ((& $proj base) -match 'Base With Spaces') 'base listed'

    & $proj add zzprojtest -r 'New Project' | Out-Null
    Assert (Test-Path (Join-Path $base.FullName 'New Project')) 'folder created inside base'
    Assert ((Read-Bat zzprojtest) -contains "cd /d `"$($base.FullName)\New Project`"") 'bat points to the right folder'
    Assert ((& $proj list) -match 'zzprojtest') 'shortcut listed'

    & $proj rm zzprojtest | Out-Null
    Assert (-not (Test-Path (Join-Path $env:PROJ_HOME 'bin\zzprojtest.bat'))) 'shortcut removed'
    Assert (Test-Path (Join-Path $base.FullName 'New Project')) 'rm keeps the project folder'

    & $proj base default r | Out-Null
    Assert ((& $proj base) -match '-r .*\(default\)') 'default base tagged'
    & $proj add zzprojdef | Out-Null
    Assert ((Read-Bat zzprojdef) -contains "cd /d `"$($base.FullName)\zzprojdef`"") 'add without flag uses the default base'

    Push-Location $tmp
    & $proj add zzprojdot . | Out-Null
    Pop-Location
    Assert ((Read-Bat zzprojdot) -contains "cd /d `"$tmp`"") '. skips the default base'

    & $proj base rm r | Out-Null
    Assert (-not (Read-Json).default) 'removing the base clears the default'

    # Run the generated .bat for real: normal path runs the command, --kade looks for KADE.
    $weird = New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'Weird (x86) Folder')
    $config = Read-Json
    $config.command = 'echo RAN'
    $config | ConvertTo-Json | Set-Content (Join-Path $env:PROJ_HOME 'config.json')
    & $proj add zzprojrun $weird.FullName | Out-Null
    $bat = Join-Path $env:PROJ_HOME 'bin\zzprojrun.bat'
    Assert ((cmd /c "`"$bat`" hello") -contains 'RAN hello') 'shortcut runs its command with the arguments'
    $env:KADE_EXE = Join-Path $tmp 'missing\kade.exe'
    $savedPath = $env:PATH
    $env:PATH = "$env:SystemRoot\system32"
    $out = cmd /c "`"$bat`" --kade"
    $code = $LASTEXITCODE
    $env:PATH = $savedPath
    Remove-Item Env:KADE_EXE
    Assert ($code -eq 1 -and ($out -match 'KADE not found')) '--kade without KADE fails with a clear message, even with ( ) in the path'

    # sync upgrades an old-format shortcut and keeps folder + command.
    $old = Join-Path $env:PROJ_HOME 'bin\zzprojold.bat'
    [IO.File]::WriteAllText($old, "@echo off`r`nrem proj-shortcut`r`ncd /d `"$tmp`"`r`ncode . %*`r`n")
    & $proj sync | Out-Null
    $synced = Get-Content $old
    Assert ($synced -contains 'if /i "%~1"=="--kade" goto kade') 'sync adds --kade'
    Assert ($synced -contains "cd /d `"$tmp`"") 'sync keeps the folder'
    Assert ($synced -contains 'code . %*') 'sync keeps the command'

    Write-Host 'OK: all tests passed'
}
finally {
    Remove-Item -Recurse -Force $tmp
}
