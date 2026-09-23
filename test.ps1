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

    Write-Host 'OK: all tests passed'
}
finally {
    Remove-Item -Recurse -Force $tmp
}
