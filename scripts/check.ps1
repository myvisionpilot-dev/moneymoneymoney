# Type-checks (luau-lsp, --!strict), lints (selene) and format-checks (stylua) both places.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/check.ps1
$ErrorActionPreference = "Continue"
$env:Path = "$env:USERPROFILE\.rokit\bin;$env:Path"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path globalTypes.d.luau)) {
	Invoke-WebRequest "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau" -OutFile globalTypes.d.luau
}

$failed = $false
foreach ($place in @("lobby", "match")) {
	Write-Host "== ${place}: types =="
	rojo sourcemap "$place.project.json" -o "sourcemap.$place.json"
	# Vendor/ holds third-party code (ProfileStore) that isn't --!strict; it's skipped here and in selene/stylua.
	luau-lsp analyze --definitions=@roblox=globalTypes.d.luau --sourcemap="sourcemap.$place.json" --ignore="**/Vendor/**" src/shared src/serverCommon "src/$place"
	if ($LASTEXITCODE -ne 0) { $failed = $true }
}

Write-Host "== lint =="
selene src
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host "== format =="
stylua --check src
if ($LASTEXITCODE -ne 0) { $failed = $true }

if ($failed) { exit 1 }
Write-Host "All checks passed."
