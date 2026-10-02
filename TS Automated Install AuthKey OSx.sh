#!/bin/bash

set -euo pipefail

# ============================================================
# Tailscale Automated Installation - macOS
#
# - Installs latest stable Tailscale standalone client
# - Uses embedded auth key OR prompts for one
# - Uses macOS computer name as Tailscale hostname
# - Authenticates automatically
# - Verifies Tailscale connection
#
# NOTE:
# Tailscale unattended/server mode is currently Windows-only.
# The standard macOS client runs in the user login session.
#
# - chmod +x TS Automated Install AuthKey OSx.sh
# - sudo ./TS Automated Install AuthKey OSx.sh
# ============================================================

# ============================================================
# Tailscale Automated Installation - macOS
#
# Official Tailscale Standalone client ONLY
#
# Supports:
#   - Intel Macs
#   - Apple Silicon Macs (M1/M2/M3/M4)
#
# Requires:
#   - macOS Monterey 12.0 or later
#
# Features:
#   - Downloads latest stable Tailscale Standalone client
#   - Uses embedded auth key OR prompts for one
#   - Uses macOS ComputerName as Tailscale hostname
#   - Authenticates without username/password
#   - Verifies Tailscale connection
#
# Does NOT:
#   - Use Homebrew
#   - Use the Mac App Store
#   - Install the open-source tailscaled variant
#   - Configure tags
#
# IMPORTANT:
#   The official Standalone macOS client does NOT support
#   unattended operation before a user logs in.
# ============================================================


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

# Put your auth key between the quotes if desired.
#
# Example:
# AUTH_KEY="tskey-auth-xxxxxxxxxxxxxxxx"
#
# Leave blank to be prompted securely when the script runs.

AUTH_KEY=""


# ------------------------------------------------------------
# REQUIRE ROOT
# ------------------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
    echo
    echo "ERROR: This script must be run with sudo."
    echo
    echo "Example:"
    echo "  sudo ./install-tailscale-macos.sh"
    echo
    exit 1
fi


# ------------------------------------------------------------
# macOS VERSION CHECK
# ------------------------------------------------------------

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="$(echo "${MACOS_VERSION}" | cut -d. -f1)"
MACOS_MINOR="$(echo "${MACOS_VERSION}" | cut -d. -f2)"

echo
echo "=============================================="
echo " Tailscale Installation - macOS"
echo " Official Standalone Client"
echo "=============================================="
echo

echo "macOS version: ${MACOS_VERSION}"


# Tailscale currently requires macOS 12 Monterey or later.

if [[ "${MACOS_MAJOR}" -lt 12 ]]; then
    echo
    echo "ERROR: Tailscale currently requires macOS Monterey 12.0 or later."
    echo "This Mac is running macOS ${MACOS_VERSION}."
    echo
    exit 1
fi


# ------------------------------------------------------------
# DETECT CPU ARCHITECTURE
# ------------------------------------------------------------

ARCH="$(uname -m)"

case "${ARCH}" in

    arm64)
        CPU_TYPE="Apple Silicon"
        ;;

    x86_64)
        CPU_TYPE="Intel"
        ;;

    *)
        echo
        echo "ERROR: Unsupported CPU architecture: ${ARCH}"
        echo
        exit 1
        ;;

esac

echo "Processor: ${CPU_TYPE} (${ARCH})"
echo


# ------------------------------------------------------------
# GET COMPUTER NAME
# ------------------------------------------------------------

COMPUTER_NAME="$(scutil --get ComputerName 2>/dev/null || true)"

if [[ -z "${COMPUTER_NAME}" ]]; then
    COMPUTER_NAME="$(hostname)"
fi

echo "Mac computer name: ${COMPUTER_NAME}"
echo


# ------------------------------------------------------------
# GET AUTH KEY
# ------------------------------------------------------------

if [[ -z "${AUTH_KEY}" ]]; then

    echo "No auth key is configured in the script."
    echo
    echo "Enter your Tailscale auth key."
    echo "The key will not be displayed while you enter it."
    echo

    read -r -s -p "Tailscale Auth Key: " AUTH_KEY
    echo
fi

if [[ -z "${AUTH_KEY}" ]]; then
    echo
    echo "ERROR: No Tailscale auth key was supplied."
    echo
    exit 1
fi


# ------------------------------------------------------------
# DOWNLOAD OFFICIAL STANDALONE CLIENT
# ------------------------------------------------------------

PKG="/tmp/Tailscale-Standalone.pkg"

echo
echo "Downloading the latest stable Tailscale Standalone client..."
echo

curl \
    --fail \
    --location \
    --silent \
    --show-error \
    "https://pkgs.tailscale.com/stable/Tailscale-latest-macos.pkg" \
    --output "${PKG}"

if [[ ! -s "${PKG}" ]]; then
    echo
    echo "ERROR: Tailscale package download failed."
    echo
    rm -f "${PKG}"
    exit 1
fi

echo "Download completed."


# ------------------------------------------------------------
# INSTALL
# ------------------------------------------------------------

echo
echo "Installing Tailscale Standalone client..."
echo

installer \
    -pkg "${PKG}" \
    -target /

rm -f "${PKG}"

echo "Installation completed."


# ------------------------------------------------------------
# LOCATE TAILSCALE APPLICATION
# ------------------------------------------------------------

TAILSCALE_APP="/Applications/Tailscale.app"

if [[ ! -d "${TAILSCALE_APP}" ]]; then

    echo
    echo "ERROR: Tailscale.app was not found."
    echo
    exit 1

fi


# ------------------------------------------------------------
# LOCATE CLI
# ------------------------------------------------------------

#
# The Standalone client contains the CLI inside the application.
#
# If CLI integration has already been enabled, Tailscale also
# installs:
#
#   /usr/local/bin/tailscale
#
# We prefer that if it exists.
#

if [[ -x "/usr/local/bin/tailscale" ]]; then

    TAILSCALE="/usr/local/bin/tailscale"

else

    TAILSCALE="${TAILSCALE_APP}/Contents/MacOS/Tailscale"

fi


if [[ ! -x "${TAILSCALE}" ]]; then

    echo
    echo "ERROR: Tailscale CLI could not be located."
    echo
    echo "The Standalone client was installed, but its CLI"
    echo "integration may need to be enabled."
    echo
    echo "Open Tailscale:"
    echo
    echo "  Settings → CLI integration → Install Now"
    echo
    exit 1

fi


# ------------------------------------------------------------
# FORCE CLI MODE
# ------------------------------------------------------------

#
# The Tailscale macOS executable can behave as either the
# graphical application or CLI depending on its environment.
#
# TAILSCALE_BE_CLI=1 explicitly tells it to operate as CLI.
#

export TAILSCALE_BE_CLI=1


# ------------------------------------------------------------
# DISPLAY VERSION
# ------------------------------------------------------------

echo
echo "Installed Tailscale version:"
echo

"${TAILSCALE}" version

echo


# ------------------------------------------------------------
# AUTHENTICATE
# ------------------------------------------------------------

echo "Connecting this Mac to your Tailscale network..."
echo

export TS_AUTH_KEY="${AUTH_KEY}"

if ! "${TAILSCALE}" up \
    --auth-key="${TS_AUTH_KEY}" \
    --hostname="${COMPUTER_NAME}"; then

    unset TS_AUTH_KEY
    unset AUTH_KEY
    unset TAILSCALE_BE_CLI

    echo
    echo "ERROR: Tailscale authentication failed."
    echo
    exit 1
fi


# ------------------------------------------------------------
# REMOVE AUTH KEY FROM MEMORY
# ------------------------------------------------------------

unset TS_AUTH_KEY
unset AUTH_KEY


# ------------------------------------------------------------
# VERIFY STATUS
# ------------------------------------------------------------

echo
echo "Verifying Tailscale connection..."
echo

if ! "${TAILSCALE}" status; then

    unset TAILSCALE_BE_CLI

    echo
    echo "ERROR: Unable to obtain Tailscale status."
    echo
    exit 1

fi


# ------------------------------------------------------------
# GET TAILSCALE IP
# ------------------------------------------------------------

TAILSCALE_IP="$("${TAILSCALE}" ip -4 2>/dev/null || true)"


# ------------------------------------------------------------
# GET TAILSCALE HOSTNAME
# ------------------------------------------------------------

TAILSCALE_HOSTNAME="$("${TAILSCALE}" status \
    --json 2>/dev/null \
    | /usr/bin/python3 -c '
import sys
import json

try:
    data=json.load(sys.stdin)
    self_node=data.get("Self", {})
    print(self_node.get("HostName", ""))
except Exception:
    pass
' 2>/dev/null || true)"


# ------------------------------------------------------------
# FINAL RESULTS
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Tailscale Installation Complete"
echo "=============================================="
echo

echo "Mac computer name : ${COMPUTER_NAME}"
echo "CPU architecture  : ${CPU_TYPE}"

if [[ -n "${TAILSCALE_HOSTNAME}" ]]; then
    echo "Tailscale hostname: ${TAILSCALE_HOSTNAME}"
fi

if [[ -n "${TAILSCALE_IP}" ]]; then
    echo "Tailscale IPv4    : ${TAILSCALE_IP}"
fi

echo
echo "Tailscale client   : INSTALLED"
echo "Authentication     : SUCCESSFUL"
echo "Tailscale status   : CONNECTED"
echo

echo "The Mac should now appear in the Tailscale admin console."
echo "If device approval is enabled, approve the machine there."
echo

echo "IMPORTANT:"
echo "The official Standalone macOS client requires a user"
echo "to be logged into macOS. It does not provide Windows-style"
echo "unattended operation before login."
echo

unset TAILSCALE_BE_CLI

echo "Installation complete."
echo
