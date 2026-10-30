# Update-GPU.ps1 - Background daemon for Quadro P2000 telemetry
$jsonPath = "$env:USERPROFILE\.glzr\zebar\packs\nord\dist\glazewm\gpu.json"

while ($true) {
    try {
        $temp = (& nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null).Trim()
        if ($temp -match '^\d+$') {
            $json = "{`"temp`": $temp, `"name`": `"Quadro P2000`"}"
            [System.IO.File]::WriteAllText($jsonPath, $json)
        }
    } catch {
        # Silent on error
    }
    Start-Sleep -Seconds 2
}
