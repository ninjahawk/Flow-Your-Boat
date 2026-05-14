# Full automated gameplay test.
# Patches TestPlayer into active mode, runs game, collects output + screenshots.
# Usage: .\tools\test.ps1

$godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Filter "Godot_v*.exe" |
         Where-Object { $_.Name -notlike "*console*" } |
         Sort-Object LastWriteTime -Descending |
         Select-Object -First 1 -ExpandProperty FullName
if (-not $godot) { Write-Error "No Godot executable found"; exit 1 }
Write-Host "Using: $godot"
$project  = "C:\Users\jedin\Desktop\Bag Trap"
$userdata = "$env:APPDATA\Godot\app_userdata\Flow Sorter"
$tpPath   = "$project\scripts\autoload\TestPlayer.gd"

$orig = Get-Content $tpPath -Raw
# Use regex to handle any whitespace between tokens
$patched = $orig -replace 'const ENABLED\s*:=\s*false', 'const ENABLED := true'
Set-Content $tpPath $patched -NoNewline

try {
    Write-Host "Running automated test (≈10s)..."
    $proc = Start-Process -FilePath $godot `
        -ArgumentList "--path `"$project`"" `
        -PassThru `
        -RedirectStandardOutput "$env:TEMP\tp_out.txt" `
        -RedirectStandardError  "$env:TEMP\tp_err.txt"
    $proc.WaitForExit(20000) | Out-Null
    if (-not $proc.HasExited) { $proc.Kill() }
} finally {
    Set-Content $tpPath $orig -NoNewline
}

Write-Host "`n=== TEST LOG ==="
$combined = @()
$combined += Get-Content "$env:TEMP\tp_out.txt" -ErrorAction SilentlyContinue
$combined += Get-Content "$env:TEMP\tp_err.txt" -ErrorAction SilentlyContinue
$combined | Select-String "t=|SCORE|LIVES|GAME|SHOT|FINAL|ERROR|SCRIPT"

Write-Host "`n=== SCREENSHOTS ==="
Get-ChildItem $userdata -Filter "shot_*.png" | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.FullName)"
}
