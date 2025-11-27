#!/bin/bash

# Multi-VM SSH Setup für GitHub Runner
# Verwaltet SSH-Zugriff zu mehreren VMs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_DIR="$SCRIPT_DIR/ssh"
VMS_CONFIG="$SCRIPT_DIR/vms.yml"

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔑 GitHub Runner Multi-VM SSH Setup${NC}"
echo ""

# SSH-Verzeichnis erstellen
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# SSH Key generieren (EINMAL für alle VMs)
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    echo "Generating SSH key pair (shared across all VMs)..."
    ssh-keygen -t ed25519 -C "github-runner-multivm" -f "$SSH_DIR/id_ed25519" -N ""
    echo -e "${GREEN}✅ SSH key pair generated${NC}"
else
    echo -e "${YELLOW}ℹ️  SSH key pair already exists${NC}"
fi

chmod 600 "$SSH_DIR/id_ed25519"
chmod 644 "$SSH_DIR/id_ed25519.pub"

# known_hosts erstellen
touch "$SSH_DIR/known_hosts"
chmod 644 "$SSH_DIR/known_hosts"

# VMs Config erstellen falls nicht vorhanden
if [ ! -f "$VMS_CONFIG" ]; then
    cat > "$VMS_CONFIG" <<'EOF'
# VM Inventory für GitHub Runner
# Format: YAML

vms:
  # Beispiel-VM (bitte anpassen oder löschen)
  - name: services-vm-1
    host: 192.168.1.100
    user: debian
    port: 22
    description: "Hauptserver für Web-Services (code-server, etc.)"
    enabled: true

  # Weitere VMs hier hinzufügen:
  # - name: services-vm-2
  #   host: 192.168.1.101
  #   user: debian
  #   port: 22
  #   description: "Datenbank-Server"
  #   enabled: true

  # - name: monitoring-vm
  #   host: 192.168.1.102
  #   user: debian
  #   port: 22
  #   description: "Monitoring & Logs"
  #   enabled: true
EOF
    echo -e "${GREEN}✅ Created vms.yml template${NC}"
fi

# SSH Config generieren aus vms.yml
echo ""
echo "Generating SSH config from vms.yml..."

cat > "$SSH_DIR/config" <<'HEADER'
# SSH Config für GitHub Runner (Auto-generiert)
# Bearbeite vms.yml und führe setup-ssh.sh erneut aus

HEADER

# VMs aus vms.yml parsen (einfacher YAML-Parser)
while IFS= read -r line; do
    # Neue VM beginnt mit "- name:"
    if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
        vm_name="${BASH_REMATCH[1]}"
        vm_host=""
        vm_user=""
        vm_port="22"
        vm_enabled="true"

        # Nächste Zeilen lesen für diese VM
        while IFS= read -r subline; do
            # Stop bei nächster VM oder Ende
            if [[ $subline =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ -z "$subline" && -n "$vm_host" ]]; then
                break
            fi

            # Parse Felder
            if [[ $subline =~ ^[[:space:]]*host:[[:space:]]*(.+) ]]; then
                vm_host="${BASH_REMATCH[1]}"
            elif [[ $subline =~ ^[[:space:]]*user:[[:space:]]*(.+) ]]; then
                vm_user="${BASH_REMATCH[1]}"
            elif [[ $subline =~ ^[[:space:]]*port:[[:space:]]*(.+) ]]; then
                vm_port="${BASH_REMATCH[1]}"
            elif [[ $subline =~ ^[[:space:]]*enabled:[[:space:]]*(.+) ]]; then
                vm_enabled="${BASH_REMATCH[1]}"
            fi
        done

        # SSH Config Entry erstellen (nur wenn enabled)
        if [[ "$vm_enabled" == "true" && -n "$vm_host" && -n "$vm_user" ]]; then
            cat >> "$SSH_DIR/config" <<ENTRY

Host $vm_name
    HostName $vm_host
    User $vm_user
    Port $vm_port
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
ENTRY
            echo -e "  ${GREEN}✓${NC} Added: $vm_name ($vm_user@$vm_host:$vm_port)"
        fi
    fi
done < "$VMS_CONFIG"

chmod 600 "$SSH_DIR/config"

# Set correct ownership for Docker container (must be root)
echo ""
echo "Setting correct permissions for Docker container..."
if command -v sudo &> /dev/null; then
    sudo chown -R root:root "$SSH_DIR"
    sudo chmod 700 "$SSH_DIR"
    sudo chmod 600 "$SSH_DIR/config"
    sudo chmod 600 "$SSH_DIR/id_ed25519"
    sudo chmod 644 "$SSH_DIR/id_ed25519.pub"
    sudo chmod 644 "$SSH_DIR/known_hosts"
    echo -e "${GREEN}✅ Permissions set (owner: root)${NC}"
else
    echo -e "${YELLOW}⚠️  sudo not available - you may need to set permissions manually${NC}"
    echo "   Run: sudo chown -R root:root $SSH_DIR"
fi

echo ""
echo -e "${GREEN}✅ SSH config generated successfully!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Edit vms.yml and configure your VMs:"
echo "   nano $VMS_CONFIG"
echo ""
echo "2️⃣  Copy this public key to ALL your VMs:"
echo "   ${YELLOW}$(sudo cat "$SSH_DIR/id_ed25519.pub" 2>/dev/null || cat "$SSH_DIR/id_ed25519.pub")${NC}"
echo ""
echo "3️⃣  On each VM, create .ssh directory and add the public key:"
echo "   ssh user@vm-ip"
echo "   mkdir -p ~/.ssh && chmod 700 ~/.ssh"
echo "   nano ~/.ssh/authorized_keys"
echo "   # Paste the public key above and save"
echo "   chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "4️⃣  Re-run this script after editing vms.yml:"
echo "   bash setup-ssh.sh"
echo ""
echo "5️⃣  Test connection to each VM:"

# Liste alle VMs zum Testen
grep "^Host " "$SSH_DIR/config" 2>/dev/null | awk '{print $2}' | while read -r vm; do
    echo "   docker compose run --rm github-runner ssh $vm 'hostname'"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
