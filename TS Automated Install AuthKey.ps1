#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# ============================================================
# Tailscale Automated Installation
# Windows 10 / Windows 11
#
# - Downloads the latest Tailscale installer
# - Installs Tailscale silently
# - Uses an embedded auth key OR prompts for one
# - Uses the Windows computer name as the Tailscale hostname
# - Enables unattended mode
# - Verifies that the machine joined the tailnet
#
# ============================================================


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

# OPTIONAL:
# Put your Tailscale auth key between the quotes.
#
# Example:
# $AuthKey = "tskey-auth-xxxxxxxxxxxxxxxx"
#
# Leave this BLANK to be prompted for the key when the
# script runs.

$AuthKey = ""


# ------------------------------------------------------------
# CHECK ADMINISTRATOR PRIVILEGES
# ------------------------------------------------------------

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Host ""
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host ""
    exit 1
}


# ------------------------------------------------------------
# GET WINDOWS COMPUTER NAME
# ------------------------------------------------------------

$ComputerName = $env:COMPUTERNAME

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Tailscale Automated Installation" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Windows computer name: $ComputerName" -ForegroundColor White
Write-Host ""


# ------------------------------------------------------------
# GET AUTH KEY IF NOT EMBEDDED
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($AuthKey)) {

    Write-Host "No auth key is configured in the script." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enter your Tailscale auth key." -ForegroundColor White
    Write-Host "The key will not be displayed while you type/paste it."
    Write-Host ""

    $SecureAuthKey = Read-Host "Tailscale Auth Key" -AsSecureString

    # Convert SecureString to plain text only in memory.
    $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
        $SecureAuthKey
    )

    try {
        $AuthKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }

}

if ([string]::IsNullOrWhiteSpace($AuthKey)) {
    Write-Host ""
    Write-Host "ERROR: No auth key was provided." -ForegroundColor Red
    exit 1
}


# ------------------------------------------------------------
# DOWNLOAD LATEST TAILSCALE
# ------------------------------------------------------------

$Installer = Join-Path $env:TEMP "tailscale-setup-latest.exe"

Write-Host ""
Write-Host "Downloading the latest Tailscale installer..." -ForegroundColor Cyan

try {

    Invoke-WebRequest `
        -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" `
        -OutFile $Installer `
        -UseBasicParsing

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to download Tailscale." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "Download complete." -ForegroundColor Green


# ------------------------------------------------------------
# INSTALL TAILSCALE
# ------------------------------------------------------------

Write-Host ""
Write-Host "Installing Tailscale..." -ForegroundColor Cyan

$InstallProcess = Start-Process `
    -FilePath $Installer `
    -ArgumentList "/quiet" `
    -Wait `
    -PassThru

if ($InstallProcess.ExitCode -ne 0) {

    Write-Host ""
    Write-Host "ERROR: Tailscale installation failed." -ForegroundColor Red
    Write-Host "Exit code: $($InstallProcess.ExitCode)" -ForegroundColor Red
    exit 1
}

Write-Host "Tailscale installation completed." -ForegroundColor Green


# ------------------------------------------------------------
# LOCATE TAILSCALE CLI
# ------------------------------------------------------------

$Tailscale = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $Tailscale)) {

    Write-Host ""
    Write-Host "ERROR: Could not find tailscale.exe." -ForegroundColor Red
    exit 1
}

# Give the Tailscale service a moment to start.
Start-Sleep -Seconds 3


# ------------------------------------------------------------
# DISPLAY INSTALLED VERSION
# ------------------------------------------------------------

Write-Host ""
Write-Host "Installed Tailscale version:" -ForegroundColor Cyan

& $Tailscale version

Write-Host ""


# ------------------------------------------------------------
# AUTHENTICATE
# ------------------------------------------------------------

Write-Host "Joining the Tailscale network..." -ForegroundColor Cyan
Write-Host ""

# Use an environment variable rather than putting the auth key
# directly on the command line.
#
# This also follows Tailscale's recommendation for protecting
# reusable auth keys.

$env:TS_AUTH_KEY = $AuthKey

try {

    & $Tailscale up `
        --auth-key=$env:TS_AUTH_KEY `
        --hostname=$ComputerName `
        --unattended

    $TailscaleExitCode = $LASTEXITCODE

}
finally {

    # Remove the auth key from the environment immediately.
    Remove-Item Env:\TS_AUTH_KEY -ErrorAction SilentlyContinue
    $AuthKey = $null

}


if ($TailscaleExitCode -ne 0) {

    Write-Host ""
    Write-Host "ERROR: Tailscale authentication failed." -ForegroundColor Red
    Write-Host ""
    Write-Host "The machine may not have joined your tailnet." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Tailscale authentication successful." -ForegroundColor Green


# ------------------------------------------------------------
# VERIFY TAILSCALE STATUS
# ------------------------------------------------------------

Write-Host ""
Write-Host "Verifying Tailscale connection..." -ForegroundColor Cyan
Write-Host ""

$Status = & $Tailscale status 2>&1

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "ERROR: Unable to obtain Tailscale status." -ForegroundColor Red
    Write-Host $Status
    exit 1
}

Write-Host $Status


# ------------------------------------------------------------
# GET TAILSCALE IP ADDRESS
# ------------------------------------------------------------

$TailscaleIP = & $Tailscale ip -4 2>$null

if ([string]::IsNullOrWhiteSpace($TailscaleIP)) {

    Write-Host ""
    Write-Host "WARNING: No Tailscale IPv4 address was returned." -ForegroundColor Yellow
    Write-Host "The device may still be waiting for approval in the admin console."
    
}
else {

    Write-Host ""
    Write-Host "Tailscale IPv4 address: $TailscaleIP" -ForegroundColor Green
}


# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " Tailscale Installation Complete" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Windows computer name : $ComputerName" -ForegroundColor White
Write-Host "Tailscale hostname    : $ComputerName" -ForegroundColor White

if (-not [string]::IsNullOrWhiteSpace($TailscaleIP)) {
    Write-Host "Tailscale IPv4        : $TailscaleIP" -ForegroundColor White
}

Write-Host ""
Write-Host "Unattended mode        : ENABLED" -ForegroundColor Green
Write-Host ""
Write-Host "The machine should now appear in your Tailscale admin console." -ForegroundColor Cyan
Write-Host "If device approval is enabled, approve the machine there." -ForegroundColor Yellow
Write-Host ""
Write-Host "After approving the machine, you can optionally disable" -ForegroundColor White
Write-Host "key expiry for this device in the Tailscale admin console." -ForegroundColor White
Write-Host ""

# Clean up installer
Remove-Item $Installer -Force -ErrorAction SilentlyContinue

Write-Host "Done." -ForegroundColor Green
Write-Host ""
