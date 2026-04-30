$RepoUrl = "https://raw.githubusercontent.com/nate-error/ffuf-bridge/master"
$ManifestFile = "manifest.txt"
$VersionFile = "version.txt"

Write-Host "Checking for updates..." -ForegroundColor Gray

try {
    # Get Remote Manifest
    $RemoteData = Invoke-RestMethod -Uri "$RepoUrl/$ManifestFile" -UseBasicParsing | ConvertFrom-StringData
    
    # Get Local Versions
    $LocalData = @{}
    if (Test-Path $VersionFile) {
        $LocalData = Get-Content $VersionFile | ConvertFrom-StringData
    }

    $NeedsUpdate = $false

    # Compare and Download
    foreach ($Key in $RemoteData.Keys) {
        $RemoteVer = [double]$RemoteData[$Key]
        $LocalVer  = if ($LocalData.ContainsKey($Key)) { [double]$LocalData[$Key] } else { 0 }

        if ($RemoteVer -gt $LocalVer) {
            # Determine actual filename
            $FileName = if ($Key -eq "batch") { "launcher_launcher.bat" } else { "ffuf_launcher.ps1" }
            
            Write-Host "Updating $FileName to v$RemoteVer..." -ForegroundColor Yellow
            
            $Url = "$RepoUrl/$FileName"
            Invoke-WebRequest -Uri $Url -OutFile ".\$FileName"
            
            $LocalData[$Key] = $RemoteVer.ToString()
            $NeedsUpdate = $true
        }
    }

    # Save new version file if changes were made
    if ($NeedsUpdate) {
        $LocalData.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Out-File $VersionFile
        Write-Host "Update complete." -ForegroundColor Green

        Write-Host "Restarting launcher..." -ForegroundColor Cyan
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"launcher_launcher.bat`""

    } else {
        Write-Host "Everything is up to date." -ForegroundColor Gray
    }

} catch {
    Write-Warning "Could not connect to update server. Starting in offline mode..."
}