# Builds the friend version of the game into "CHAINS DEEZNUTS TOGETHER - send to friends" on the
# Desktop:
#   CHAINS DEEZNUTS TOGETHER.zip  first-time download: the game, ready to double-click
#   CHAINS DEEZNUTS TOGETHER.pck  updates: just the game data, friends replace their old one
#   HOW TO SEND.txt
# The zip holds the official Godot executable renamed to "CHAINS DEEZNUTS TOGETHER.exe" plus the
# game packed into a .pck with the same name, which Godot loads automatically from beside it.
# That needs no export templates. Godot's MIT license and notices ship as LICENSES.txt.
param(
	[string]$OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'CHAINS DEEZNUTS TOGETHER - send to friends')
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$name = 'CHAINS DEEZNUTS TOGETHER'
$stage = Join-Path ([IO.Path]::GetTempPath()) ('cdt_friend_' + [guid]::NewGuid().ToString('N'))
$game = Join-Path $stage $name

# The same Godot that PLAY.bat uses (installed with winget).
$godotDir = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Filter 'GodotEngine.GodotEngine_*' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
$godot = if ($godotDir) { Get-ChildItem -Path $godotDir.FullName -Filter 'Godot_v4*_win64.exe' -File | Select-Object -Last 1 }
$console = if ($godotDir) { Get-ChildItem -Path $godotDir.FullName -Filter 'Godot_v4*_win64_console.exe' -File | Select-Object -Last 1 }
if (-not $godot -or -not $console) {
	throw 'Godot 4 was not found. Install it with: winget install GodotEngine.GodotEngine'
}

# Godot prints warnings on stderr; PowerShell must not treat those as fatal.
function Invoke-Godot([string[]]$GodotArgs) {
	$saved = $ErrorActionPreference
	$ErrorActionPreference = 'Continue'
	$output = & $console.FullName @GodotArgs 2>&1 | ForEach-Object { "$_" }
	$code = $LASTEXITCODE
	$ErrorActionPreference = $saved
	return @{ Code = $code; Output = $output }
}

function Write-CrlfText([string]$From, [string]$To) {
	$text = [IO.File]::ReadAllText($From)
	$text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
	[IO.File]::WriteAllText($To, $text, (New-Object Text.UTF8Encoding($false)))
}

try {
	New-Item -ItemType Directory -Path $game | Out-Null
	$pck = Join-Path $game "$name.pck"
	Write-Host 'Packing the game ...'
	$r = Invoke-Godot @('--headless', '--path', $root, '--export-pack', 'Windows Desktop', $pck)
	if ($r.Code -ne 0 -or -not (Test-Path $pck)) {
		$r.Output | Select-Object -Last 20 | Write-Host
		throw 'Packing the game failed (see the Godot output above).'
	}
	Copy-Item -Path $godot.FullName -Destination (Join-Path $game "$name.exe")

	$licenses = Join-Path $game 'LICENSES.txt'
	Push-Location $stage
	try {
		$r = Invoke-Godot @('--headless', '--script', (Join-Path $PSScriptRoot 'write_licenses.gd'), '--', $licenses)
	}
	finally {
		Pop-Location
	}
	if (-not (Test-Path $licenses)) {
		$r.Output | Select-Object -Last 20 | Write-Host
		throw 'Writing LICENSES.txt failed.'
	}
	Write-CrlfText (Join-Path $PSScriptRoot 'friend_package\READ ME.txt') (Join-Path $game 'READ ME.txt')

	Write-Host 'Zipping ...'
	New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
	$zip = Join-Path $OutDir "$name.zip"
	if (Test-Path -LiteralPath $zip) {
		Remove-Item -LiteralPath $zip
	}
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	[IO.Compression.ZipFile]::CreateFromDirectory($game, $zip, [IO.Compression.CompressionLevel]::Optimal, $true)
	Copy-Item -Path $pck -Destination (Join-Path $OutDir "$name.pck") -Force
	Write-CrlfText (Join-Path $PSScriptRoot 'friend_package\HOW TO SEND.txt') (Join-Path $OutDir 'HOW TO SEND.txt')

	$zipMb = (Get-Item -LiteralPath $zip).Length / 1MB
	$pckMb = (Get-Item -LiteralPath $pck).Length / 1MB
	Write-Host ('Done: "{0}"' -f $OutDir)
	Write-Host ('  {0}.zip  {1:N0} MB  first time: send this' -f $name, $zipMb)
	Write-Host ('  {0}.pck  {1:N1} MB  updates: send just this' -f $name, $pckMb)
}
finally {
	if (Test-Path $stage) {
		Remove-Item -LiteralPath $stage -Recurse -Force
	}
}
