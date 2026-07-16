# *******************************************************************************************
# *******************************************************************************************
#
#		Name :		bump-build.ps1
#		Purpose :	Increment GPC.P8's build number, in place, once per build
#		Date :		16th July 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		GPC.P8 carries a "word build_num = N" that it prints at startup as "V0.9.N". The Makefile
#		'build' target runs this first, so every GPC.PRG that gets built reports a new, rising
#		number and is identifiable on sight.
#
#		PowerShell, not Python, and in place -- this is a Windows build box. The file is rewritten
#		byte-for-byte apart from the digits: LF line endings and tabs are preserved, and no BOM is
#		added (GPC.P8 is ASCII, and Prog8's lexer would choke on one).
#
# *******************************************************************************************

$ErrorActionPreference = 'Stop'

$path = Join-Path $PSScriptRoot 'GPC.P8'

# ReadAllText / WriteAllText leave line endings exactly as they are -- Set-Content would rewrite
# every LF as CRLF and prepend a BOM. The regex touches only the digits, so nothing else moves.
$text = [System.IO.File]::ReadAllText($path)

$re = [regex]'(?<pre>build_num\s*=\s*)(?<num>\d+)'
$m  = $re.Match($text)
if (-not $m.Success) {
    Write-Error "bump-build: 'build_num = <n>' not found in $path"
    exit 1
}

$old  = [int]$m.Groups['num'].Value
$new  = $old + 1
$text = $re.Replace($text, "`${pre}$new", 1)     # `$ is a literal $, so ${pre} reaches .NET as the group

[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "GPC build number: $old -> $new"
