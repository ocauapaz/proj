# proj - atalhos de terminal que abrem um comando (claude, por padrao) dentro da pasta de um projeto.
# Compativel com Windows PowerShell 5.1 e PowerShell 7+.

$ErrorActionPreference = 'Stop'

$projHome = if ($env:PROJ_HOME) { $env:PROJ_HOME } else { Join-Path $HOME '.proj' }
$binDir = Join-Path $projHome 'bin'
$configPath = Join-Path $projHome 'config.json'
$marker = 'rem proj-shortcut'

function Read-Config {
    if (-not (Test-Path -LiteralPath $configPath)) {
        return [pscustomobject]@{ command = 'claude'; bases = [pscustomobject]@{} }
    }
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if (-not $config.command) { $config | Add-Member command 'claude' -Force }
    if (-not $config.bases) { $config | Add-Member bases ([pscustomobject]@{}) -Force }
    return $config
}

function Save-Config($config) {
    New-Item -ItemType Directory -Force -Path $projHome | Out-Null
    $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Fail($message) {
    Write-Host $message
    exit 1
}

# cmd.exe le .bat no codepage OEM; gravar em UTF-8 quebraria caminhos com acento.
function Get-BatEncoding {
    try { return [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage) }
    catch { return [Text.Encoding]::UTF8 }
}

function Get-Shortcuts {
    if (-not (Test-Path -LiteralPath $binDir)) { return @() }
    Get-ChildItem -LiteralPath $binDir -Filter *.bat | Where-Object {
        (Get-Content -LiteralPath $_.FullName -TotalCount 2) -contains $marker
    }
}

function Get-ShortcutTarget($file) {
    $cdLine = Get-Content -LiteralPath $file.FullName | Where-Object { $_ -like 'cd /d *' } | Select-Object -First 1
    return $cdLine -replace '^cd /d "?(.*?)"?$', '$1'
}

function Split-Args($list) {
    $positional = @()
    $baseKey = $null
    foreach ($arg in $list) {
        if ($arg -match '^-([A-Za-z0-9]+)$') { $baseKey = $Matches[1] } else { $positional += $arg }
    }
    return @{ Positional = $positional; BaseKey = $baseKey }
}

function Show-Usage {
    Write-Host @"
Uso:
  proj list                        lista os atalhos
  proj add <nome> [pasta]          atalho pra qualquer pasta (padrao = pasta atual)
  proj add <nome> -<base> [pasta]  atalho dentro de uma pasta base (padrao = <nome>)
  proj rm <nome>                   remove o atalho (a pasta do projeto fica intacta)

  proj base                        lista as pastas base
  proj base add <chave> <pasta>    cria base, ex: proj base add r "E:\Roblox Projects"
  proj base rm <chave>             remove base

  Se a pasta do projeto nao existir, ela e criada.
  Config: $configPath
"@
}

function Invoke-List {
    $shortcuts = @(Get-Shortcuts)
    if ($shortcuts.Count -eq 0) { 'Nenhum atalho. Crie um com: proj add <nome> [pasta]'; return }
    foreach ($s in $shortcuts) { '{0,-14} {1}' -f $s.BaseName, (Get-ShortcutTarget $s) }
}

function Invoke-Add($list) {
    $parsed = Split-Args $list
    $name = $parsed.Positional | Select-Object -First 1
    $folder = $parsed.Positional | Select-Object -Skip 1 -First 1

    if (-not $name) { Show-Usage; exit 1 }
    if ($name -notmatch '^[A-Za-z0-9_-]+$') { Fail "Nome invalido: '$name' (use letras, numeros, - ou _)" }
    if (Get-Command $name -ErrorAction SilentlyContinue) { Fail "'$name' ja existe como comando. Escolha outro nome." }

    $config = Read-Config
    if ($parsed.BaseKey) {
        $base = $config.bases.($parsed.BaseKey)
        if (-not $base) { Fail "Base '-$($parsed.BaseKey)' nao existe. Veja com: proj base" }
        if (-not (Test-Path -LiteralPath $base -PathType Container)) { Fail "Pasta da base '-$($parsed.BaseKey)' nao existe: $base" }
        $target = Join-Path $base $(if ($folder) { $folder } else { $name })
    }
    elseif ($folder) { $target = $folder }
    else { $target = (Get-Location).Path }

    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        New-Item -ItemType Directory -Path $target | Out-Null
        Write-Host "Pasta criada: $target"
    }
    $target = (Resolve-Path -LiteralPath $target).Path

    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    $content = "@echo off`r`n$marker`r`ncd /d `"$target`"`r`n$($config.command) %*`r`n"
    [IO.File]::WriteAllText((Join-Path $binDir "$name.bat"), $content, (Get-BatEncoding))
    Write-Host "Criado: $name -> $target"
}

function Invoke-Remove($name) {
    if (-not $name) { Show-Usage; exit 1 }
    $file = Get-Shortcuts | Where-Object { $_.BaseName -eq $name }
    if (-not $file) { Fail "Atalho '$name' nao encontrado. Use: proj list" }
    Remove-Item -LiteralPath $file.FullName
    Write-Host "Removido: $name"
}

function Invoke-Base($list) {
    $sub = $list | Select-Object -First 1
    if (-not $sub) { $sub = 'list' }
    $key = $list | Select-Object -Skip 1 -First 1
    $folder = $list | Select-Object -Skip 2 -First 1
    $config = Read-Config

    switch ($sub) {
        { $_ -in 'list', 'ls' } {
            $props = @($config.bases.PSObject.Properties)
            if ($props.Count -eq 0) { 'Nenhuma base. Crie com: proj base add <chave> <pasta>'; return }
            foreach ($p in $props) { '-{0,-8} {1}' -f $p.Name, $p.Value }
        }
        { $_ -in 'add', 'set' } {
            if (-not $key -or -not $folder) { Fail 'Uso: proj base add <chave> <pasta>' }
            $key = $key.TrimStart('-')
            if ($key -notmatch '^[A-Za-z0-9]+$') { Fail "Chave invalida: '$key' (use so letras e numeros)" }
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) { Fail "Pasta nao existe: $folder" }
            $folder = (Resolve-Path -LiteralPath $folder).Path
            $config.bases | Add-Member -NotePropertyName $key -NotePropertyValue $folder -Force
            Save-Config $config
            Write-Host "Base -$key -> $folder"
        }
        { $_ -in 'rm', 'remove', 'del' } {
            if (-not $key) { Fail 'Uso: proj base rm <chave>' }
            $key = $key.TrimStart('-')
            if (-not $config.bases.$key) { Fail "Base '-$key' nao existe." }
            $config.bases.PSObject.Properties.Remove($key)
            Save-Config $config
            Write-Host "Base -$key removida."
        }
        default { Show-Usage; exit 1 }
    }
}

$action = $args | Select-Object -First 1
if (-not $action) { $action = 'help' }
$rest = @($args | Select-Object -Skip 1)

switch ($action) {
    { $_ -in 'list', 'ls' } { Invoke-List }
    { $_ -in 'add', 'new' } { Invoke-Add $rest }
    { $_ -in 'rm', 'remove', 'del' } { Invoke-Remove ($rest | Select-Object -First 1) }
    'base' { Invoke-Base $rest }
    default { Show-Usage }
}
