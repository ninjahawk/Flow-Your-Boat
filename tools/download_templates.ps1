# Downloads Godot 4.6.2 export templates and installs them.
# Run once. Safe to re-run if interrupted.

$version   = "4.6.2-stable"
$url       = "https://github.com/godotengine/godot/releases/download/$version/Godot_v$version`_export_templates.tpz"
$outDir    = "$env:APPDATA\Godot\export_templates"
$tpzFile   = "$outDir\templates.tpz"
$finalDir  = "$outDir\$version"

if (Test-Path $finalDir) {
    Write-Host "Templates already installed at $finalDir"
    exit 0
}

New-Item -ItemType Directory -Force $outDir | Out-Null

if (-not (Test-Path $tpzFile)) {
    Write-Host "Downloading export templates (~1.3 GB)..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $tpzFile)
    Write-Host "Download complete."
} else {
    Write-Host "Already downloaded: $tpzFile ($([math]::Round((Get-Item $tpzFile).Length/1MB,0)) MB)"
}

Write-Host "Extracting..."
# .tpz is a renamed .zip
$zipDest = $tpzFile -replace '\.tpz$', '.zip'
Copy-Item $tpzFile $zipDest -Force
Expand-Archive -Path $zipDest -DestinationPath $outDir -Force
Remove-Item $zipDest -ErrorAction SilentlyContinue

# Godot extracts to a folder called "templates" inside the .tpz
$extracted = "$outDir\templates"
if (Test-Path $extracted) {
    Rename-Item $extracted $finalDir
    Remove-Item $tpzFile -ErrorAction SilentlyContinue
    Write-Host "Templates installed to: $finalDir"
} else {
    Write-Host "Extraction complete. Check $outDir"
}
