$RepoUrl = "https://raw.githubusercontent.com/nate-error/ffuf-bridge/master"
$ManifestFile = "manifest.txt"
$VersionFile = "version.txt"

Write-Host "Checking for updates..." -ForegroundColor Gray

$NeedsUpdate = $false

$RemoteVer = $null
$LocalVer = $null

try {
    # Get Remote Manifest
    $Raw = Invoke-WebRequest -Uri "$RepoUrl/BridgeFiles/$ManifestFile" -UseBasicParsing
    $RemoteData = $Raw.Content | ConvertFrom-StringData
    
    # Get Local Versions
    $LocalData = @{}

    if (Test-Path $VersionFile) {
        Get-Content "BridgeFiles/$VersionFile" | ForEach-Object {
            if ($_ -match "^\s*([^=]+)\s*=\s*(.+)\s*$") {
                $LocalData[$matches[1]] = $matches[2].Trim()
            }
        }
    }

    # Compare and Download
    foreach ($Key in $RemoteData.Keys) {

        $RemoteValue = $RemoteData[$Key].Trim()

        if (-not [version]::TryParse($RemoteValue, [ref]$RemoteVer)) {
            continue
        }

        $LocalValue = if ($LocalData.ContainsKey($Key)) { $LocalData[$Key] } else { "0.0.0" }

        if (-not [version]::TryParse($LocalValue, [ref]$LocalVer)) {
            $LocalVer = [version]"0.0.0"
        }

        if ($RemoteVer -gt $LocalVer) {

            $FileName = if ($Key -eq "batch") { "bridge_launcher.bat" } else { "BridgeFiles/ffuf_launcher.ps1" }

            Write-Host "Updating $FileName ($LocalVer → $RemoteVer)..." -ForegroundColor Yellow

            Invoke-WebRequest "$RepoUrl/$FileName" -OutFile ".\$FileName"

            $LocalData[$Key] = $RemoteVer.ToString()
            $NeedsUpdate = $true
        }
    }

    # Save new version file if changes were made
    if ($NeedsUpdate) {
        $LocalData.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Out-File "BridgeFiles/$VersionFile"
        Write-Host "Update complete." -ForegroundColor Green

    } else {
        Write-Host "Everything is up to date." -ForegroundColor Gray
    }

} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}