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
# - chmod +x TS Automated Config AuthKey OSx.sh
# - sudo ./TS Automated Config AuthKey OSx.sh
# ============================================================

# ============================================================
# Tailscale Configuration - macOS
#
# Requires:
#   Tailscale Standalone client already installed
#
# Supports:
#   macOS Monterey 12+
#   Intel
#   Apple Silicon
#
# Does:
#   - Finds Tailscale CLI inside the official app
#   - Prompts for auth key if not embedded
#   - Sets Tailscale hostname to Mac ComputerName
#   - Authenticates using auth key
#   - Verifies connection
#
# Does NOT:
#   - Install Tailscale
#   - Use Homebrew
#   - Use Mac App Store
#   - Use the open-source tailscaled version
# ============================================================


# ------------------------------------------------------------
# OPTIONAL AUTH KEY
# ------------------------------------------------------------

# Put your auth key here if desired.
#
# Example:
# AUTH_KEY="tskey-auth-xxxxxxxxxxxxxxxx"
#
# Leave blank to be prompted.

AUTH_KEY=""


# ------------------------------------------------------------
# REQUIRE ADMINISTRATOR
# ------------------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
    echo
    echo "ERROR: Run this script with sudo."
    echo
    echo "Example:"
    echo "  sudo ./configure-tailscale-macos.sh"
    echo
    exit 1
fi


# ------------------------------------------------------------
# CHECK TAILSCALE INSTALLATION
# ------------------------------------------------------------

TAILSCALE_APP="/Applications/Tailscale.app"

if [[ ! -d "${TAILSCALE_APP}" ]]; then

    echo
    echo "ERROR: Tailscale.app was not found."
    echo
    echo "Install the official Tailscale Standalone client first."
    echo
    exit 1

fi


# ------------------------------------------------------------
# LOCATE TAILSCALE CLI
# ------------------------------------------------------------

#
# For macOS 12, we deliberately use the CLI directly from
# inside the Tailscale Standalone application.
#
# This avoids requiring the CLI integration feature, which
# requires macOS Ventura 13+.
#

TAILSCALE="${TAILSCALE_APP}/Contents/MacOS/Tailscale"

if [[ ! -x "${TAILSCALE}" ]]; then

    echo
    echo "ERROR: Tailscale CLI was not found."
    echo
    exit 1

fi


# ------------------------------------------------------------
# FORCE CLI MODE
# ------------------------------------------------------------

export TAILSCALE_BE_CLI=1


# ------------------------------------------------------------
# GET MAC COMPUTER NAME
# ------------------------------------------------------------

COMPUTER_NAME="$(scutil --get ComputerName 2>/dev/null || true)"

if [[ -z "${COMPUTER_NAME}" ]]; then
    COMPUTER_NAME="$(hostname)"
fi


# ------------------------------------------------------------
# GET AUTH KEY
# ------------------------------------------------------------

if [[ -z "${AUTH_KEY}" ]]; then

    echo
    echo "No auth key is configured in the script."
    echo
    echo "Enter your Tailscale auth key."
    echo "The key will not be displayed."
    echo

    read -r -s -p "Tailscale Auth Key: " AUTH_KEY
    echo
fi

if [[ -z "${AUTH_KEY}" ]]; then
    echo
    echo "ERROR: No auth key supplied."
    echo
    exit 1
fi


# ------------------------------------------------------------
# DISPLAY INFORMATION
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Tailscale Configuration - macOS"
echo "=============================================="
echo

echo "Computer name: ${COMPUTER_NAME}"
echo
echo "Tailscale version:"
"${TAILSCALE}" version
echo


# ------------------------------------------------------------
# AUTHENTICATE
# ------------------------------------------------------------

echo "Joining the Tailscale network..."
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
# REMOVE AUTH KEY
# ------------------------------------------------------------

unset TS_AUTH_KEY
unset AUTH_KEY


# ------------------------------------------------------------
# VERIFY CONNECTION
# ------------------------------------------------------------

echo
echo "Verifying Tailscale connection..."
echo

if ! "${TAILSCALE}" status; then

    unset TAILSCALE_BE_CLI

    echo
    echo "ERROR: Tailscale status verification failed."
    echo
    exit 1

fi


# ------------------------------------------------------------
# GET TAILSCALE IP
# ------------------------------------------------------------

TAILSCALE_IP="$("${TAILSCALE}" ip -4 2>/dev/null || true)"


# ------------------------------------------------------------
# FINAL RESULT
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Tailscale Configuration Complete"
echo "=============================================="
echo

echo "Mac computer name : ${COMPUTER_NAME}"

if [[ -n "${TAILSCALE_IP}" ]]; then
    echo "Tailscale IPv4    : ${TAILSCALE_IP}"
fi

echo
echo "Authentication     : SUCCESS"
echo "Tailscale status   : CONNECTED"
echo

echo "The Mac should now appear in your Tailscale admin console."

echo
echo "If device approval is enabled, approve the Mac"
echo "in the Tailscale admin console."
echo

unset TAILSCALE_BE_CLI
