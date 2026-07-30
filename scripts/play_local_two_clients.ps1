param(
	[string]$Godot = $env:GODOT_BIN,
	[int]$Port = 7073
)

$launcher = Join-Path $PSScriptRoot "play_local_client.ps1"
$arguments = @{ Port = $Port; Clients = 2 }
if ($Godot) {
	$arguments.Godot = $Godot
}
& $launcher @arguments
