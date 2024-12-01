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

    $chatIds = $Env:TELEGRAM_CHAT_IDS -split "," | ForEach-Object { $_.Trim() }
    $uri = "https://api.telegram.org/bot$Env:TELEGRAM_BOT_TOKEN/sendDocument"

    foreach ($chatId in $chatIds) {
        # Create a new HttpClient instance
        $httpClient = New-Object System.Net.Http.HttpClient
    
        # Create MultipartFormDataContent
        $formContent = New-Object System.Net.Http.MultipartFormDataContent
    
        # Add the chat_id and document fields to the form data
        $formContent.Add((New-Object System.Net.Http.StringContent($chatId)), "chat_id")
        $fileStream = [System.IO.File]::OpenRead($RdpFilePath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $fileContent.Headers.Add("Content-Type", "application/octet-stream")
        $formContent.Add($fileContent, "document", [System.IO.Path]::GetFileName($RdpFilePath))
    
        # Send the request
        $response = $httpClient.PostAsync($uri, $formContent).Result
    
        # Check response status
        if ($response.IsSuccessStatusCode) {
            Write-Host "File sent successfully to $chatId"
        } else {
            Write-Host "Failed to send file to $chatId"
        }
    
        # Dispose of the HttpClient instance
        $httpClient.Dispose()
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
    -Password "P@assw0rd!" 


    # Keep Ngrok running
    Write-Host "Ngrok is running. Press Ctrl+C to exit."
    while ($true) { Start-Sleep -Seconds 2 }
}

function Main {
    
    Download-Ngrok
    Enable-Remote-Desktop
    CreateNgrok
}

Main