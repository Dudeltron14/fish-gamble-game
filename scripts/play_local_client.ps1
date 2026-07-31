param(
	[string]$Godot = $env:GODOT_BIN,
	[int]$Port = 7073,
	[ValidateRange(1, 4)]
	[int]$Clients = 1,
	[switch]$Staging
)

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $Godot) {
	$Godot = (Get-Command godot -ErrorAction SilentlyContinue).Source
}
if (-not $Godot) {
	$Godot = Join-Path $env:USERPROFILE "Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) {
	throw "Godot was not found. Pass -Godot <path> or set GODOT_BIN."
}

if ($Staging) {
	$env:BRINDLE_SERVER_URL = "wss://fishserver-staging.dudeltron14.win"
	& $Godot --path $projectRoot
	return
}

$server = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", $projectRoot, "--", "--server", "--port", $Port, "--local-test") -PassThru
Start-Sleep -Seconds 1
if ($server.HasExited) {
	throw "Local server exited during startup."
}

$previousServerUrl = $env:BRINDLE_SERVER_URL
$extraClients = @()
try {
	$env:BRINDLE_SERVER_URL = "ws://127.0.0.1:$Port"
	for ($client = 2; $client -le $Clients; $client++) {
		$extraClients += Start-Process -FilePath $Godot -ArgumentList @("--path", $projectRoot) -PassThru
	}
	& $Godot --path $projectRoot
}
finally {
	$env:BRINDLE_SERVER_URL = $previousServerUrl
	foreach ($client in $extraClients) {
		if (-not $client.HasExited) {
			Stop-Process -Id $client.Id
		}
	}
	if (-not $server.HasExited) {
		Stop-Process -Id $server.Id
	}
}
