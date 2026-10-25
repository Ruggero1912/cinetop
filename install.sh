#!/bin/bash
set -e

export PATH="$HOME/.local/bin:$PATH"

if [ ! -f "config.env" ]; then
    echo "❌ File 'config.env' not found!"
    echo "   Run: cp config.env.example config.env && nano config.env"
    exit 1
fi

source config.env
CINECA_HOSTNAME="${CINECA_HOSTNAME:-login.leonardo.cineca.it}"
CINECA_PARTITION="${CINECA_PARTITION:-boost_usr_prod}"
CINECA_WORK_BASE="${CINECA_WORK_BASE:-/leonardo_work}"

echo "-> Saving local configuration to ~/.config/cinetop/config.env..."
mkdir -p ~/.config/cinetop ~/.local/bin ~/.ssh
cp config.env ~/.config/cinetop/config.env
chmod 600 ~/.config/cinetop/config.env

if ! grep -q "Host ${CINECA_SSH_HOST}" ~/.ssh/config 2>/dev/null; then
    echo "-> Adding '${CINECA_SSH_HOST}' host with SSH multiplexing to ~/.ssh/config..."
    cat << SSH_EOF >> ~/.ssh/config

Host ${CINECA_SSH_HOST} ${CINECA_HOSTNAME}
    HostName ${CINECA_HOSTNAME}
    User ${CINECA_USER}
    IdentityFile ~/.ssh/cineca_key
    CertificateFile ~/.ssh/cineca_key-cert.pub
    IdentitiesOnly yes
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
SSH_EOF
    chmod 600 ~/.ssh/config
fi

echo "-> Installing local wrapper to ~/.local/bin/cinetop..."
cp local/cinetop ~/.local/bin/cinetop
chmod +x ~/.local/bin/cinetop

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$CINECA_SSH_HOST" "true" 2>/dev/null; then
    echo "🔑 No active CINECA SSH session found. Generating certificate via step-cli..."
    rm -f ~/.ssh/cm-* 2>/dev/null
    step ssh certificate "$KEYCLOAK_EMAIL" ~/.ssh/cineca_key \
        --provisioner cineca-hpc \
        --no-password \
        --insecure \
        --no-agent \
        --force
fi

REMOTE_BIN="${CINECA_WORK_BASE}/${CINECA_ACCOUNT}/${CINECA_USER}/bin"
echo "-> Deploying remote scripts to ${CINECA_SSH_HOST}:${REMOTE_BIN}..."
ssh "$CINECA_SSH_HOST" "mkdir -p '$REMOTE_BIN' && printf 'export CINECA_ACCOUNT="%s"\nexport CINECA_PARTITION="%s"\n' '$CINECA_ACCOUNT' '$CINECA_PARTITION' > ~/.cineca_kit_rc"
scp remote/cinetop remote/_cinetop_worker "${CINECA_SSH_HOST}:${REMOTE_BIN}/"
ssh "$CINECA_SSH_HOST" "chmod +x '$REMOTE_BIN/cinetop' '$REMOTE_BIN/_cinetop_worker'"

echo "✅ Installation complete! Run 'cinetop' from your terminal."
