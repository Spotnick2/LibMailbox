<#
    run.ps1 - Syntax-check the library and run every tests\test_*.lua under
    Lua 5.1, through WowTestKit's runner at the commit tests\kit.pin names.

    Usage:
        pwsh tests/run.ps1
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
        pwsh tests/run.ps1 -KitDev        # the ..\WowTestKit working copy instead of the pin
#>

param(
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe",
    [switch]$KitDev
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "kit.ps1")
$kit = Get-WowTestKit -RepoRoot $RepoRoot -KitDev:$KitDev

# No TOC (a library): the files the XML loads are the ones to check.
$xml = (Get-Content -LiteralPath (Join-Path $RepoRoot "LibMailbox-1.0.xml") -Raw) -replace '(?s)<!--.*?-->', ''
$scripts = @([regex]::Matches($xml, '<Script\s+file="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
& (Join-Path $kit "scripts\run.ps1") -RepoRoot $RepoRoot -Extra $scripts -Lua $Lua
exit $LASTEXITCODE
