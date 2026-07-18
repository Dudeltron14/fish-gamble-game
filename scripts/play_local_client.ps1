param([string]$Godot = $env:GODOT_BIN)

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $Godot) {
	$Godot = (Get-Command godot -ErrorAction SilentlyContinue).Source
}
if (-not $Godot) {
	$Godot = Join-Path $env:USERPROFILE "Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) {
	throw "Godot was not found. Pass -Godot <path> or set GODOT_BIN."
}

$env:BRINDLE_SERVER_URL = "wss://fishserver-staging.dudeltron14.win"
& $Godot --path $projectRoot
