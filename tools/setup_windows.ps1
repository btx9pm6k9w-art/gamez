# One-time setup on Windows (ThinkPad): installs Godot 4.7 with winget if it is
# missing, then imports the project. Run from the repo folder:
#   powershell -ExecutionPolicy Bypass -File tools\setup_windows.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing Godot with winget..."
        winget install --id GodotEngine.GodotEngine -e --accept-source-agreements --accept-package-agreements
        $godot = Get-Command godot -ErrorAction SilentlyContinue
    }
}
if (-not $godot) {
    Write-Host "Godot not found. Download Godot 4.7 (standard, not .NET) from https://godotengine.org/download/windows,"
    Write-Host "unzip it anywhere, then open project.godot from the Godot project manager."
    exit 1
}
& $godot.Source --version
& $godot.Source --headless --path . --import | Out-Null
Write-Host "Done. Open project.godot in Godot and press Play. Start with the Medium preset (F2) on this laptop."
