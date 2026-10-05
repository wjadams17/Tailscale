Windows Installer (PowerShell - Run As Administrator): $ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://github.com/wjadams17/Tailscale/releases/latest/download/TS.Automated.Install.AuthKey.ps1'))

Linux Install: curl -sSL "https://github.com/wjadams17/Tailscale/releases/latest/download/TS.Automated.Install.AuthKey.sh" | bash

macOS Config: curl -sSL "https://github.com/wjadams17/Tailscale/releases/latest/download/TS.Automated.Config.AuthKey.OSx.sh" | zsh
