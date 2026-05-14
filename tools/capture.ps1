# Headless screenshot capture for visual testing.
# Usage: .\tools\capture.ps1

$project = "C:\Users\jedin\Desktop\Bag Trap"
$shotdir = "$env:APPDATA\Godot\app_userdata\Flow Sorter"
$shot    = "$shotdir\debug_screenshot.png"

# Find whatever Godot exe is installed — newest wins
$godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v*.exe" |
         Where-Object { $_.Name -notlike "*console*" } |
         Sort-Object LastWriteTime -Descending |
         Select-Object -First 1 -ExpandProperty FullName

if (-not $godot) { Write-Error "No Godot executable found"; exit 1 }
Write-Host "Using: $godot"

$dcPath  = "$project\scripts\autoload\DebugCapture.gd"
$orig    = Get-Content $dcPath -Raw
$patched = $orig -replace 'const ENABLED\s*:=\s*false',    'const ENABLED    := true'
$patched = $patched -replace 'const QUIT_AFTER\s*:=\s*false', 'const QUIT_AFTER := true'
Set-Content $dcPath $patched -NoNewline

try {
    $proc = Start-Process -FilePath $godot -ArgumentList "--path `"$project`"" -PassThru
    $proc.WaitForExit(15000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }
} finally {
    Set-Content $dcPath $orig -NoNewline
}

if (Test-Path $shot) { Write-Host "Screenshot saved: $shot" }
else                 { Write-Host "ERROR: Screenshot not found" }
