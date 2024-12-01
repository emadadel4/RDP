function Send-RdpFileToTelegram {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteComputer,       

        [Parameter(Mandatory = $true)]
        [string]$Username,             

        [Parameter(Mandatory = $true)]
        [string]$Password,            

        [string]$RdpFilePath = "$env:USERPROFILE\Desktop\AutoConnect.rdp"  # Default RDP file path
    )

    # Create the RDP file content
    $RdpContent = @"
    smart sizing:i:1
    full address:s:$RemoteComputer
    username:s:$Username
    enablecredsspsupport:i:1
    prompt for credentials:i:0
    compression:i:1
    networkautodetect:i:0
    bandwidthautodetect:i:0
    connection type:i:1
    password 51:b:$([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Password)))
"@

    # Save the RDP file
    try {
        $RdpContent | Out-File -FilePath $RdpFilePath -Encoding UTF8
        Write-Host "RDP file saved: $RdpFilePath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to save RDP file: $_"
        return
    }

    # Send the RDP file to Telegram

    try {

        $chatIds = $Env:TELEGRAM_CHAT_IDS -split "," | ForEach-Object { $_.Trim() }
        foreach ($chatId in $chatIds)
        {
            $Response = Invoke-WebRequest -Uri "https://api.telegram.org/bot$Env:TELEGRAM_BOT_TOKEN/sendDocument" `
            -Method POST `
            -Form @{
                chat_id  = $chatId
                document = Get-Item $RdpFilePath
            }

            if ($Response.StatusCode -eq 200) {
                Write-Host "RDP file sent successfully to Telegram!" -ForegroundColor Green
            } else {
                Write-Error "Failed to send RDP file. Response: $($Response.StatusCode)"
            }
        }
    } 
    catch 
    {
        Write-Error "Error sending RDP file to Telegram: $_"
    }
}

function Download-Ngrok {
    param (
        $ngrok = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
    )

    # Download ngrok
    Invoke-WebRequest https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip -OutFile ngrok.zip
    Expand-Archive ngrok.zip
    .\ngrok\ngrok.exe authtoken $Env:NGROK_AUTH_TOKEN
}

function Enable-Remote-Desktop {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1
    Set-LocalUser -Name "runneradmin" -Password (ConvertTo-SecureString -AsPlainText "P@ssw0rd!" -Force)
}

function CreateNgrok{
    
    # Start Ngrok process
    Start-Process -FilePath .\ngrok\ngrok.exe -ArgumentList "tcp 3389" -NoNewWindow
    Start-Sleep -Seconds 1 # Allow Ngrok to start

    # Fetch the public Ngrok URL
    $ngrokUrl = Invoke-RestMethod -Uri http://localhost:4040/api/tunnels | 
    Select-Object -ExpandProperty tunnels | 
    Select-Object -First 1 | 
    Select-Object -ExpandProperty public_url -ErrorAction SilentlyContinue

    Send-RdpFileToTelegram `
    -RemoteComputer $ngrokUrl `
    -Username "runneradmin" `
    -Password "P@assw0rd!" `
    -TelegramBotToken $Env:TELEGRAM_BOT_TOKEN


    # Keep Ngrok running
    Write-Host "Ngrok is running. Press Ctrl+C to exit."
    while ($true) { Start-Sleep -Seconds 10 }
}

function Main {
    
    Download-Ngrok
    Enable-Remote-Desktop

    CreateNgrok
    
}




Main