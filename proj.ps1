# proj - terminal shortcuts that open a command (claude by default) inside a project folder.
# Works on Windows PowerShell 5.1 and PowerShell 7+.

$ErrorActionPreference = 'Stop'

$projHome = if ($env:PROJ_HOME) { $env:PROJ_HOME } else { Join-Path $HOME '.proj' }
$binDir = Join-Path $projHome 'bin'
$configPath = Join-Path $projHome 'config.json'
$fallbackBase = Join-Path $HOME 'projects'
$marker = 'rem proj-shortcut'

function Read-Config {
    if (-not (Test-Path -LiteralPath $configPath)) {
        return [pscustomobject]@{ command = 'claude'; default = $null; bases = [pscustomobject]@{} }
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

# cmd.exe reads .bat files in the OEM codepage; writing UTF-8 would break paths with accents.
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

function Get-BasePath($config, $key) {
    $base = $config.bases.$key
    if (-not $base) { Fail "Base '-$key' does not exist. See: proj base" }
    if (-not (Test-Path -LiteralPath $base -PathType Container)) { Fail "Folder for base '-$key' does not exist: $base" }
    return $base
}

function Show-Usage {
    Write-Host @"
Usage:
  proj list                        list shortcuts
  proj add <name> [folder]         create in the default base (folder defaults to <name>)
  proj add <name> -<base> [folder] create in a specific base
  proj add <name> <C:\full\path>   full path skips the base; use . for the current folder
  proj rm <name>                   remove a shortcut (the project folder is kept)

  proj base                        list bases
  proj base add <key> <folder>     add a base, e.g. proj base add r "E:\Roblox Projects"
  proj base rm <key>               remove a base
  proj base default <key>          base used when add has no flag (off = back to $fallbackBase)

  Missing project folders are created.
  Config: $configPath
"@
}

function Invoke-List {
    $shortcuts = @(Get-Shortcuts)
    if ($shortcuts.Count -eq 0) { 'No shortcuts. Create one with: proj add <name>'; return }
    foreach ($s in $shortcuts) { '{0,-14} {1}' -f $s.BaseName, (Get-ShortcutTarget $s) }
}

function Invoke-Add($list) {
    $parsed = Split-Args $list
    $name = $parsed.Positional | Select-Object -First 1
    $folder = $parsed.Positional | Select-Object -Skip 1 -First 1

    if (-not $name) { Show-Usage; exit 1 }
    if ($name -notmatch '^[A-Za-z0-9_-]+$') { Fail "Invalid name: '$name' (use letters, digits, - or _)" }
    if (Get-Command $name -ErrorAction SilentlyContinue) { Fail "'$name' is already a command. Pick another name." }

    $config = Read-Config
    # A full path or explicit relative path (., ..\x) skips the default base.
    $isExplicitPath = $folder -and ([IO.Path]::IsPathRooted($folder) -or $folder.StartsWith('.'))
    $subfolder = if ($folder) { $folder } else { $name }

    if ($parsed.BaseKey) { $target = Join-Path (Get-BasePath $config $parsed.BaseKey) $subfolder }
    elseif ($isExplicitPath) { $target = $folder }
    elseif ($config.default) { $target = Join-Path (Get-BasePath $config $config.default) $subfolder }
    else { $target = Join-Path $fallbackBase $subfolder }

    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        New-Item -ItemType Directory -Path $target | Out-Null
        Write-Host "Created folder: $target"
    }
    $target = (Resolve-Path -LiteralPath $target).Path

    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    $content = "@echo off`r`n$marker`r`ncd /d `"$target`"`r`n$($config.command) %*`r`n"
    [IO.File]::WriteAllText((Join-Path $binDir "$name.bat"), $content, (Get-BatEncoding))
    Write-Host "Created: $name -> $target"
}

function Invoke-Remove($name) {
    if (-not $name) { Show-Usage; exit 1 }
    $file = Get-Shortcuts | Where-Object { $_.BaseName -eq $name }
    if (-not $file) { Fail "Shortcut '$name' not found. See: proj list" }
    Remove-Item -LiteralPath $file.FullName
    Write-Host "Removed: $name"
}

function Invoke-Base($list) {
    $sub = $list | Select-Object -First 1
    if (-not $sub) { $sub = 'list' }
    $key = $list | Select-Object -Skip 1 -First 1
    $folder = $list | Select-Object -Skip 2 -First 1
    $config = Read-Config

    switch ($sub) {
        { $_ -in 'list', 'ls' } {
            if (-not $config.default) { '{0,-9} {1} (default)' -f '(none)', $fallbackBase }
            foreach ($p in $config.bases.PSObject.Properties) {
                $tag = if ($p.Name -eq $config.default) { '(default)' } else { '' }
                '-{0,-8} {1} {2}' -f $p.Name, $p.Value, $tag
            }
        }
        { $_ -in 'add', 'set' } {
            if (-not $key -or -not $folder) { Fail 'Usage: proj base add <key> <folder>' }
            $key = $key.TrimStart('-')
            if ($key -notmatch '^[A-Za-z0-9]+$') { Fail "Invalid key: '$key' (letters and digits only)" }
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) { Fail "Folder does not exist: $folder" }
            $folder = (Resolve-Path -LiteralPath $folder).Path
            $config.bases | Add-Member -NotePropertyName $key -NotePropertyValue $folder -Force
            Save-Config $config
            Write-Host "Base -$key -> $folder"
        }
        { $_ -in 'rm', 'remove', 'del' } {
            if (-not $key) { Fail 'Usage: proj base rm <key>' }
            $key = $key.TrimStart('-')
            if (-not $config.bases.$key) { Fail "Base '-$key' does not exist." }
            $config.bases.PSObject.Properties.Remove($key)
            if ($config.default -eq $key) { $config | Add-Member default $null -Force }
            Save-Config $config
            Write-Host "Removed base -$key."
        }
        'default' {
            if (-not $key) { Fail 'Usage: proj base default <key>   |   proj base default off' }
            $key = $key.TrimStart('-')
            if ($key -eq 'off') {
                $config | Add-Member default $null -Force
                Save-Config $config
                Write-Host "Default base: $fallbackBase"
                return
            }
            Get-BasePath $config $key | Out-Null
            $config | Add-Member default $key -Force
            Save-Config $config
            Write-Host "Default base: -$key ($($config.bases.$key))"
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
