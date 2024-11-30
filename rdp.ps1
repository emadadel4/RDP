function Send-RdpFileToTelegram {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteComputer,        # Remote desktop address

        [Parameter(Mandatory = $true)]
        [string]$Username,             # Remote username

        [Parameter(Mandatory = $true)]
        [string]$Password,             # Remote password

        [Parameter(Mandatory = $true)]
        [string]$TelegramBotToken,     # Telegram Bot API token

        [Parameter(Mandatory = $true)]
        [string]$ChatID,               # Telegram chat ID

        [string]$RdpFilePath = "$env:USERPROFILE\Desktop\AutoConnect.rdp"  # Default RDP file path
    )

    try {
        # Step 1: Create the RDP file
        Write-Host "Creating RDP file with smart sizing and modem speed settings..." -ForegroundColor Cyan
        @"
smart sizing:i:1
full address:s:$RemoteComputer
username:s:$Username
enablecredsspsupport:i:1
prompt for credentials:i:0
compression:i:1
networkautodetect:i:0
bandwidthautodetect:i:0
connection type:i:1
password 51:b:" + [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($Password)) + @"
"@ | Out-File -Encoding UTF8 -FilePath $RdpFilePath

        Write-Host "RDP file has been saved to: $RdpFilePath" -ForegroundColor Green

        # Step 2: Send the RDP file to Telegram
        Write-Host "Sending RDP file to Telegram..." -ForegroundColor Cyan
        $FileContent = Get-Content -Path $RdpFilePath -Encoding Byte
        $Boundary = [System.Guid]::NewGuid().ToString()
        $Body = @"
--$Boundary
Content-Disposition: form-data; name="chat_id"

$ChatID
--$Boundary
Content-Disposition: form-data; name="document"; filename="AutoConnect.rdp"
Content-Type: application/x-rdp

"@ + [System.Text.Encoding]::UTF8.GetString($FileContent) + @"
--$Boundary--
"@

        Invoke-WebRequest -Uri "https://api.telegram.org/bot$TelegramBotToken/sendDocument" `
            -Method POST `
            -Headers @{"Content-Type" = "multipart/form-data; boundary=$Boundary"} `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($Body))

        Write-Host "RDP file sent successfully to Telegram!" -ForegroundColor Green
    } catch {
        Write-Error "An error occurred: $_"
    }
}


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


# $message = "Ngrok URL Details:`n`nHost: $urlWithoutPort`nPort: $UrlPort `n`Username: runneradmin`n`Password: P@ssw0rd!"




# # Get list of active RDP sessions
# $rdpSessions = query user | Select-String "Active" | ForEach-Object { $_.Line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)[0] }
# if ($rdpSessions) {
#     $message += "`n`nActive RDP Sessions:`n$($rdpSessions -join "`n")"
# } else {
#     $message += "`n`nNo active RDP sessions found."
# }

# Send message to Telegram
$botToken = $Env:TELEGRAM_BOT_TOKEN
$chatIds = $Env:TELEGRAM_CHAT_ID -split "," | ForEach-Object { $_.Trim() }

foreach ($chatId in $chatIds) {
    try {

        Send-RdpFileToTelegram `
        -RemoteComputer $ngrokUrl `
        -Username "runneradmin" `
        -Password "P@assw0rd!" `
        -TelegramBotToken $botToken `
        -ChatID $chatId

    } catch {
        Write-Host "Failed to send message to chat_id: $chatId"
        Write-Host $_.Exception.Message
    }
}

# Keep Ngrok running
Write-Host "Ngrok is running. Press Ctrl+C to exit."
while ($true) { Start-Sleep -Seconds 10 }



