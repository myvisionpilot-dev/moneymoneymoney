# Fallback sync when the Rojo plugin isn't connected: builds each place's code into a model inside
# Studio's content folder, so Studio can load it with game:GetObjects("rbxasset://mmm/<place>-code.rbxm").
# Then run tools/load_code.luau in that place (Studio command bar or the MCP) to swap the code in.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/sync-studio.ps1
$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
Set-Location (Split-Path $PSScriptRoot -Parent)

# Prefer the install that's running right now; otherwise the newest one.
$running = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Select-Object -First 1
if ($running) {
	$studioDir = Split-Path $running.Path -Parent
} else {
	$latest = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Directory |
		Where-Object { Test-Path (Join-Path $_.FullName "RobloxStudioBeta.exe") } |
		Sort-Object LastWriteTime -Descending | Select-Object -First 1
	if (-not $latest) { throw "Roblox Studio install not found" }
	$studioDir = $latest.FullName
}

$target = Join-Path $studioDir "content\mmm"
New-Item -ItemType Directory -Force $target | Out-Null
foreach ($place in @("lobby", "match")) {
	rojo build "scripts/$place-code.project.json" -o (Join-Path $target "$place-code.rbxm")
}
# tools/*.luau as ModuleScripts, e.g. require(game:GetObjects("rbxasset://mmm/tools.rbxm")[1].build_match_map)
rojo build "scripts/tools.project.json" -o (Join-Path $target "tools.rbxm")
Write-Host "Built to $target"
