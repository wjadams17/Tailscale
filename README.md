Windows Installer (Run from Administrator PowerShell): $ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wjadams17/Tailscale/main/TS Automated Install AuthKey.ps1'))

Linux Install: curl -fsSL https://raw.githubusercontent.com/wjadams17/Tailscale/main/TS Automated Install AuthKey.ps | sudo bash
