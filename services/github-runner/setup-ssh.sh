#!/bin/bash

# Setup SSH Keys für GitHub Runner → Service VM Zugriff
# Dieses Skript wird auf der Runner-VM ausgeführt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_DIR="$SCRIPT_DIR/ssh"

echo "🔑 Setting up SSH keys for GitHub Runner..."

# SSH-Verzeichnis erstellen
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# SSH Key generieren (falls nicht vorhanden)
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    echo "Generating new SSH key pair..."
    ssh-keygen -t ed25519 -C "github-runner" -f "$SSH_DIR/id_ed25519" -N ""
    echo "✅ SSH key pair generated"
else
    echo "ℹ️  SSH key pair already exists"
fi

# Permissions setzen
chmod 600 "$SSH_DIR/id_ed25519"
chmod 644 "$SSH_DIR/id_ed25519.pub"

# known_hosts Datei erstellen (leer)
touch "$SSH_DIR/known_hosts"
chmod 644 "$SSH_DIR/known_hosts"

# SSH Config erstellen
cat > "$SSH_DIR/config" <<'EOF'
# SSH Config für GitHub Runner

Host services-vm
    HostName SERVICES_VM_IP
    User SERVICES_VM_USER
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
EOF

chmod 600 "$SSH_DIR/config"

echo ""
echo "✅ SSH setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Edit ssh/config and replace:"
echo "   - SERVICES_VM_IP with your service VM IP (e.g., 192.168.1.100)"
echo "   - SERVICES_VM_USER with your SSH user (e.g., debian)"
echo ""
echo "2. Copy the public key to your Services VM:"
echo "   cat $SSH_DIR/id_ed25519.pub"
echo ""
echo "3. On your Services VM, add the public key to authorized_keys:"
echo "   ssh SERVICES_VM_USER@SERVICES_VM_IP"
echo "   nano ~/.ssh/authorized_keys"
echo "   # Paste the public key and save"
echo ""
echo "4. Test SSH connection from Runner VM:"
echo "   docker compose run --rm github-runner ssh -F /root/.ssh/config services-vm 'echo Connection successful!'"
echo ""
