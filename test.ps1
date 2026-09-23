# Teste rapido: roda o proj numa PROJ_HOME temporaria e confere o fluxo base/add/list/rm.
$ErrorActionPreference = 'Stop'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "proj-test-$PID"
$env:PROJ_HOME = Join-Path $tmp 'home'
$proj = Join-Path $PSScriptRoot 'proj.ps1'
$base = New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'Base Com Espaco')

function Assert($condition, $message) { if (-not $condition) { throw "FALHOU: $message" } }
function Read-Json { Get-Content (Join-Path $env:PROJ_HOME 'config.json') -Raw | ConvertFrom-Json }

try {
    & $proj base add r $base.FullName | Out-Null
    Assert ((& $proj base) -match 'Base Com Espaco') 'base listada'

    & $proj add zzprojtest -r 'Novo Projeto' | Out-Null
    Assert (Test-Path (Join-Path $base.FullName 'Novo Projeto')) 'pasta criada dentro da base'
    $bat = Get-Content (Join-Path $env:PROJ_HOME 'bin\zzprojtest.bat')
    Assert ($bat -contains "cd /d `"$($base.FullName)\Novo Projeto`"") 'bat aponta pra pasta certa'
    Assert ((& $proj list) -match 'zzprojtest') 'atalho listado'

    & $proj rm zzprojtest | Out-Null
    Assert (-not (Test-Path (Join-Path $env:PROJ_HOME 'bin\zzprojtest.bat'))) 'atalho removido'
    Assert (Test-Path (Join-Path $base.FullName 'Novo Projeto')) 'rm nao apaga a pasta do projeto'

    & $proj base default r | Out-Null
    Assert ((& $proj base) -match '\(padrao\)') 'base padrao marcada'
    & $proj add zzprojdef | Out-Null
    Assert ((Get-Content (Join-Path $env:PROJ_HOME 'bin\zzprojdef.bat')) -contains "cd /d `"$($base.FullName)\zzprojdef`"") 'add sem flag usa a base padrao'
    Push-Location $tmp
    & $proj add zzprojdot . | Out-Null
    Pop-Location
    Assert ((Get-Content (Join-Path $env:PROJ_HOME 'bin\zzprojdot.bat')) -contains "cd /d `"$tmp`"") '. ignora a base padrao'

    & $proj base rm r | Out-Null
    Assert (-not (Read-Json).default) 'remover a base limpa o padrao'
    Assert ((& $proj base) -match 'Nenhuma base') 'base removida'

    Write-Host 'OK: todos os testes passaram'
}
finally {
    Remove-Item -Recurse -Force $tmp
}
