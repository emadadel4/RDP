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