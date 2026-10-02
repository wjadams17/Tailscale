#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Tailscale Automated Installation - Linux
#
# - Installs latest stable Tailscale
# - Uses embedded auth key OR prompts for one
# - Uses system hostname as Tailscale hostname
# - Enables tailscaled at boot
# - Verifies Tailscale connection
#
# - chmod +x install-tailscale-linux.sh
# - sudo ./install-tailscale-linux.sh
# ============================================================

# Leave blank to be prompted.
AUTH_KEY=""

echo
echo "=============================================="
echo " Tailscale Installation - Linux"
echo "=============================================="
echo

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    echo "Example: sudo ./install-tailscale-linux.sh"
    exit 1
fi

# ------------------------------------------------------------
# Hostname
# ------------------------------------------------------------

HOSTNAME_VALUE="$(hostname)"

echo "Linux hostname: ${HOSTNAME_VALUE}"
echo

# ------------------------------------------------------------
# Auth key
# ------------------------------------------------------------

if [[ -z "${AUTH_KEY}" ]]; then

    echo "No auth key is configured in the script."
    echo "Enter the Tailscale auth key."
    echo

    read -r -s -p "Tailscale Auth Key: " AUTH_KEY
    echo
fi

if [[ -z "${AUTH_KEY}" ]]; then
    echo "ERROR: No auth key supplied."
    exit 1
fi

# ------------------------------------------------------------
# Install latest stable Tailscale
# ------------------------------------------------------------

echo
echo "Installing latest stable Tailscale..."

curl -fsSL https://tailscale.com/install.sh | sh

# ------------------------------------------------------------
# Start tailscaled
# ------------------------------------------------------------

echo
echo "Starting Tailscale service..."

systemctl enable --now tailscaled

sleep 3

# ------------------------------------------------------------
# Display version
# ------------------------------------------------------------

echo
echo "Installed Tailscale version:"
tailscale version

# ------------------------------------------------------------
# Authenticate
# ------------------------------------------------------------

echo
echo "Connecting to Tailscale..."

export TS_AUTH_KEY="${AUTH_KEY}"

tailscale up \
    --auth-key="${TS_AUTH_KEY}" \
    --hostname="${HOSTNAME_VALUE}"

unset TS_AUTH_KEY
unset AUTH_KEY

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "Verifying Tailscale connection..."

if ! tailscale status; then
    echo
    echo "ERROR: Tailscale status check failed."
    exit 1
fi

TAILSCALE_IP="$(tailscale ip -4 2>/dev/null || true)"

# ------------------------------------------------------------
# Results
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Tailscale Installation Complete"
echo "=============================================="
echo

echo "Linux hostname : ${HOSTNAME_VALUE}"

if [[ -n "${TAILSCALE_IP}" ]]; then
    echo "Tailscale IPv4 : ${TAILSCALE_IP}"
fi

echo "tailscaled      : ENABLED"
echo "Service         : RUNNING"

echo
echo "The device should now appear in the Tailscale admin console."
echo "Approve it there if device approval is enabled."
echo
