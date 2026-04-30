:: Update the scripts if needed
powershell -ExecutionPolicy Bypass -NoProfile -File "BridgeFiles/updater.ps1"

:: Launch the bridge
powershell -ExecutionPolicy Bypass -NoProfile -File "BridgeFiles/ffuf_launcher.ps1"
pause