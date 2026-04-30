:: Update the scripts if needed
powershell -ExecutionPolicy Bypass -NoProfile -File "updater.ps1"

:: Launch the bridge
powershell -ExecutionPolicy Bypass -NoProfile -File "ffuf_launcher.ps1"
pause