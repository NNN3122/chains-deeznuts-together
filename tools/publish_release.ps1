# Publishes a new version of the game on GitHub:
#   1. builds the friend zip (make_friend_zip.ps1)
#   2. commits and pushes any source changes
#   3. creates the next release (v1, v2, ...) with the zip attached as CHAINS-DEEZNUTS-TOGETHER.zip
# Friends always get the newest one from the same link:
#   https://github.com/<owner>/<repo>/releases/latest/download/CHAINS-DEEZNUTS-TOGETHER.zip
# Needs git and the GitHub CLI (gh), signed in, in a folder already linked to the GitHub repo.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$asset = 'CHAINS-DEEZNUTS-TOGETHER.zip'
$zip = Join-Path ([Environment]::GetFolderPath('Desktop')) 'CHAINS DEEZNUTS TOGETHER - send to friends\CHAINS DEEZNUTS TOGETHER.zip'

# Native tools print progress on stderr; only their exit codes decide success.
function Invoke-Tool([string]$Exe, [string[]]$ToolArgs) {
	$saved = $ErrorActionPreference
	$ErrorActionPreference = 'Continue'
	$output = & $Exe @ToolArgs 2>&1 | ForEach-Object { "$_" }
	$code = $LASTEXITCODE
	$ErrorActionPreference = $saved
	if ($code -ne 0) {
		$output | Select-Object -Last 15 | Write-Host
		throw "$Exe $($ToolArgs[0]) failed."
	}
	return $output
}

Push-Location $root
try {
	$repo = (Invoke-Tool 'gh' @('repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner') | Select-Object -Last 1).Trim()

	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make_friend_zip.ps1')
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $zip)) {
		throw 'Building the game failed.'
	}

	$last = (Invoke-Tool 'gh' @('release', 'list', '--limit', '1', '--json', 'tagName', '--jq', '.[0].tagName') | Select-Object -Last 1)
	$n = if ("$last" -match '^v(\d+)$') { [int]$Matches[1] + 1 } else { 1 }
	$tag = "v$n"

	Write-Host "Pushing the source ..."
	Invoke-Tool 'git' @('add', '-A') | Out-Null
	if (Invoke-Tool 'git' @('status', '--porcelain')) {
		Invoke-Tool 'git' @('commit', '-q', '-m', "Game update $tag") | Out-Null
	}
	Invoke-Tool 'git' @('push', '-q', 'origin', 'HEAD') | Out-Null

	Write-Host "Publishing $tag ..."
	$tmp = Join-Path ([IO.Path]::GetTempPath()) ('cdt_release_' + [guid]::NewGuid().ToString('N'))
	New-Item -ItemType Directory -Path $tmp | Out-Null
	try {
		$upload = Join-Path $tmp $asset
		Copy-Item -LiteralPath $zip -Destination $upload
		$notes = Join-Path $tmp 'notes.md'
		$text = @(
			"Download **$asset** below, unzip it (right-click, Extract All) and double-click **CHAINS DEEZNUTS TOGETHER.exe**. Nothing to install.",
			'',
			'Playing together: the host clicks HOST CO-OP, presses Esc and clicks COPY INVITE. Everyone else clicks JOIN CO-OP, PASTE, CONNECT. Everyone needs the same version.'
		) -join "`n"
		[IO.File]::WriteAllText($notes, $text, (New-Object Text.UTF8Encoding($false)))
		Invoke-Tool 'gh' @('release', 'create', $tag, $upload, '--title', "CHAINS DEEZNUTS TOGETHER $tag", '--notes-file', $notes, '--latest') | Out-Null
	}
	finally {
		Remove-Item -LiteralPath $tmp -Recurse -Force
	}

	Write-Host ''
	Write-Host "Published $tag. Send your friends this link; it always downloads the newest version:"
	Write-Host "  https://github.com/$repo/releases/latest/download/$asset"
	Write-Host "Or the project page: https://github.com/$repo"
}
finally {
	Pop-Location
}
