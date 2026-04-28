$webhook = "https://script.google.com/macros/s/AKfycbxel3xhviiR74eWndNTUsMiGlrzhDNmv3zmT57pPisP-xc0V6k0pcA6Ej8izDbGAn5F/exec"

$ConfigPath = Join-Path $PSScriptRoot "config.dat"

function Load-Or-CreateConfig {

    if (!(Test-Path $ConfigPath)) {
        Write-Host "`nfirst time setup"

        $keyName = Read-Host "key name"
        $secret  = Read-Host "secret (SECRET_KEY_...)"

        "$keyName|$secret" | Set-Content $ConfigPath

        Write-Host "config saved`n"
    }

    $line = Get-Content $ConfigPath | Select-Object -First 1
    $p = $line -split "\|"

    @{
        KeyName = $p[0].Trim()
        Secret  = $p[1].Trim()
    }
}

$config = Load-Or-CreateConfig

$keyName = $config.KeyName
$secret  = $config.Secret

function HMAC($msg, $key) {
    $h = New-Object System.Security.Cryptography.HMACSHA256
    $h.Key = [Text.Encoding]::UTF8.GetBytes($key)
    ($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($msg)) | ForEach-Object { $_.ToString("x2") }) -join ""
}

# This is a one way operation: the original input (here, your computer name) cannot be retrieved from the hash
# Used to avoid storing the raw computer name
function SHA256Base64($t) {
    $s = [System.Security.Cryptography.SHA256]::Create()
    [Convert]::ToBase64String($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($t)))
}

function Nonce { [guid]::NewGuid().ToString() }
function Timestamp { [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }



$rawMachineName = [string]$env:COMPUTERNAME
$uid = SHA256Base64 ($rawMachineName)



function Run-Fuzz($target, $wordlist, $limit, $extensions) {
    .\ffuf.exe -u $target -w $wordlist -rate $limit -e $extensions | Tee-Object -Variable ffufLine | ForEach-Object {
            
        Write-Host $_ -ForegroundColor Cyan
            
        $line = $_.ToString()
        $match = [regex]::Match($line, '(\S+)\s+\[Status:\s*(\d+),')

        if ($match.Success) {

            $word = $match.Groups[1].Value -replace '[^\x20-\x7E]', ''
            $status = [int]$match.Groups[2].Value

            if ($status -in 200,301,302,403) {

                $url = $target -replace "FUZZ", $word
                $baseUrl = $target -replace "FUZZ.*", "FUZZ"

                $payload = @{
                    word = $word
                    url = $url
                    baseUrl = $baseUrl
                    status = $status
                    wordlist = (Split-Path $wordlist -Leaf)
                    uid = $uid
                }

                $payloadJson = $payload | ConvertTo-Json -Compress

                $payloadHash = SHA256Base64 $payloadJson
                $ts = Timestamp
                $nonce = Nonce

                $base = "$keyName.$ts.$nonce.$payloadHash"
                $sig = HMAC $base $secret

                $body = @{
                    key = $keyName
                    ts = $ts
                    nonce = $nonce
                    payload = $payloadJson
                    sig = $sig
                }

                $json = $body | ConvertTo-Json -Compress

                try {
                    $response = Invoke-RestMethod -Uri $webhook -Method Post -Body $json -ContentType "application/json" -MaximumRedirection 5
                    Write-Host "`n[+] RESPONSE:" $response -ForegroundColor Green
                }
                catch {
                    Write-Host "`n[X] ERROR:" $_.Exception.Message -ForegroundColor Red
                }
            }
        }
    }
}


do {
    $target = Read-Host "Url (don't forget FUZZ)"
    $wordlist = Read-Host "Wordlist"
    $limit = Read-Host "Rate limit"

    $extInput = Read-Host "Extensions (comma separated, optional)"
    if (![string]::IsNullOrWhiteSpace($extInput)) {
        $extInput = ($extInput -split "," | ForEach-Object { $_.Trim() }) -join "," # Trim and clean input
    }

    Write-Host "`nstarting ffuf..."
    Run-Fuzz $target $wordlist $limit $extInput

    $again = Read-Host "`nRun again with another wordlist/extensions? (y/n)"

} while ($again -match '^(y|yes)$')
