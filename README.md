Windows Installer (Run from Administrator PowerShell): $ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wjadams17/Tailscale/main/TS Automated Install AuthKey.ps1'))

Linux Install: curl -sSL "https://raw.githubusercontent.com/wjadams17/Tailscale/main/TS Automated Install AuthKey.sh" | bash

macOS Config: curl -sSL "https://raw.githubusercontent.com/wjadams17/Tailscale/main/TS Automated Config AuthKey OSx.sh" | zsh
