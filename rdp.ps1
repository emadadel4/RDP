# Download and extract Ngrok
Invoke-WebRequest https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip -OutFile ngrok.zip
Expand-Archive -Path ngrok.zip -DestinationPath .

# Authenticate Ngrok
.\ngrok\ngrok.exe authtoken $Env:NGROK_AUTH_TOKEN

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1

# Set Admin Password
Set-LocalUser -Name "runneradmin" -Password (ConvertTo-SecureString -AsPlainText "P@ssw0rd!" -Force)

# Start Ngrok tunnel
Start-Process -FilePath .\ngrok\ngrok.exe -ArgumentList "tcp 3389" -NoNewWindow
Start-Sleep -Seconds 1

# Fetch Ngrok public URL
$ngrokUrl = Invoke-RestMethod -Uri http://localhost:4040/api/tunnels |
            Select-Object -ExpandProperty tunnels |
            Select-Object -First 1 |
            Select-Object -ExpandProperty public_url -ErrorAction SilentlyContinue

# Prepare message details
$urlWithoutProtocol = $ngrokUrl -replace "^tcp://", ""
$UrlPort = $urlWithoutProtocol.Split(":")[-1]
$urlWithoutPort = $urlWithoutProtocol -replace ":\d+$", ""
$message = "Ngrok URL Details:`n`nHost: $urlWithoutPort`nPort: $UrlPort `n`Username: runneradmin`n`Password: P@ssw0rd!"

# Get list of active RDP sessions
$rdpSessions = query user | Select-String "Active" | ForEach-Object { $_.Line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)[0] }
if ($rdpSessions) {
    $message += "`n`nActive RDP Sessions:`n$($rdpSessions -join "`n")"
} else {
    $message += "`n`nNo active RDP sessions found."
}

# Send message to Telegram
$botToken = $Env:TELEGRAM_BOT_TOKEN
$chatIds = $Env:TELEGRAM_CHAT_IDS -split "," | ForEach-Object { $_.Trim() }
foreach ($chatId in $chatIds) {
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/sendMessage" `
            -Method Post `
            -ContentType "application/json" `
            -Body (@{chat_id=$chatId; text=$message} | ConvertTo-Json)
    } catch {
        Write-Host "Failed to send message to chat_id: $chatId"
        Write-Host $_.Exception.Message
    }
}

# Keep Ngrok running
Write-Host "Ngrok is running. Press Ctrl+C to exit."
while ($true) { Start-Sleep -Seconds 10 }
