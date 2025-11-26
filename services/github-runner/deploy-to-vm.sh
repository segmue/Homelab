#!/bin/bash

# Multi-VM Deployment Script
# Deployed Services auf die richtige VM basierend auf vms.yml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VMS_CONFIG="$SCRIPT_DIR/vms.yml"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# VM für Service bestimmen
get_vm_for_service() {
    local service=$1
    local vm=""

    # Parse service_mapping aus vms.yml
    in_mapping=false
    while IFS= read -r line; do
        if [[ $line =~ ^service_mapping: ]]; then
            in_mapping=true
            continue
        fi

        if [[ $in_mapping == true ]]; then
            # Stop bei nächster Section
            if [[ $line =~ ^[a-z_]+: ]] && [[ ! $line =~ ^[[:space:]]+ ]]; then
                break
            fi

            # Parse "service: vm" mapping
            if [[ $line =~ ^[[:space:]]+${service}:[[:space:]]*(.+) ]]; then
                vm="${BASH_REMATCH[1]}"
                # Kommentare entfernen
                vm="${vm%%#*}"
                vm="${vm// /}"
                break
            fi
        fi
    done < "$VMS_CONFIG"

    echo "$vm"
}

# Alle VMs auflisten
list_vms() {
    echo -e "${BLUE}📋 Configured VMs:${NC}"
    echo ""

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
            vm_name="${BASH_REMATCH[1]}"
            vm_host=""
            vm_desc=""
            vm_enabled=""

            while IFS= read -r subline; do
                if [[ $subline =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ -z "$subline" && -n "$vm_host" ]]; then
                    break
                fi

                if [[ $subline =~ ^[[:space:]]*host:[[:space:]]*(.+) ]]; then
                    vm_host="${BASH_REMATCH[1]}"
                elif [[ $subline =~ ^[[:space:]]*description:[[:space:]]*\"(.+)\" ]]; then
                    vm_desc="${BASH_REMATCH[1]}"
                elif [[ $subline =~ ^[[:space:]]*enabled:[[:space:]]*(.+) ]]; then
                    vm_enabled="${BASH_REMATCH[1]}"
                fi
            done

            if [[ "$vm_enabled" == "true" ]]; then
                echo -e "  ${GREEN}✓${NC} ${BLUE}$vm_name${NC} ($vm_host) - $vm_desc"
            else
                echo -e "  ${YELLOW}○${NC} $vm_name ($vm_host) - DISABLED"
            fi
        fi
    done < "$VMS_CONFIG"

    echo ""
}

# Deploy zu einer spezifischen VM
deploy_to_vm() {
    local vm_name=$1
    local service=$2

    log_info "Deploying ${service:-all services} to VM: $vm_name"

    # SSH zur VM und deployen
    ssh -F ~/.ssh/config "$vm_name" bash << EOF
        set -e

        echo "📦 Connected to: \$(hostname)"

        # Homelab-Verzeichnis
        HOMELAB_DIR="\${HOMELAB_DIR:-\$HOME/homelab}"

        if [ ! -d "\$HOMELAB_DIR" ]; then
            echo "❌ Homelab directory not found at \$HOMELAB_DIR"
            echo "Cloning repository..."
            git clone https://github.com/\${GITHUB_REPOSITORY:-segmue/Homelab}.git "\$HOMELAB_DIR"
        fi

        cd "\$HOMELAB_DIR"

        # Git pull
        echo "🔄 Pulling latest changes..."
        git fetch origin
        git reset --hard origin/main

        # Deployment-Skript ausführen
        if [ -f "scripts/deploy.sh" ]; then
            bash scripts/deploy.sh ${service:-all} update
        else
            echo "⚠️  No deployment script found"
            exit 1
        fi

        echo "✅ Deployment completed on \$(hostname)!"
EOF

    if [ $? -eq 0 ]; then
        log_info "✅ Successfully deployed to $vm_name"
        return 0
    else
        log_error "❌ Deployment to $vm_name failed!"
        return 1
    fi
}

# Hilfe anzeigen
show_help() {
    cat << EOF
${BLUE}Multi-VM Deployment Script${NC}

Usage:
  $0 <command> [options]

Commands:
  list                    List all configured VMs
  deploy <vm> [service]   Deploy to specific VM
  deploy-all [service]    Deploy to all VMs
  service <service>       Deploy specific service to its configured VM

Examples:
  $0 list                           # List all VMs
  $0 deploy services-vm-1           # Deploy all services to services-vm-1
  $0 deploy services-vm-1 plex      # Deploy only plex to services-vm-1
  $0 deploy-all                     # Deploy to all VMs
  $0 service code-server            # Deploy code-server to its configured VM

Configuration:
  Edit vms.yml to configure VMs and service mappings
EOF
}

# Main
case "${1:-}" in
    list)
        if [ ! -f "$VMS_CONFIG" ]; then
            log_error "vms.yml not found! Run setup-ssh.sh first."
            exit 1
        fi
        list_vms
        ;;

    deploy)
        VM_NAME="${2:-}"
        SERVICE="${3:-all}"

        if [ -z "$VM_NAME" ]; then
            log_error "VM name required!"
            echo "Usage: $0 deploy <vm-name> [service]"
            exit 1
        fi

        deploy_to_vm "$VM_NAME" "$SERVICE"
        ;;

    deploy-all)
        SERVICE="${2:-all}"
        log_info "Deploying ${SERVICE} to all VMs..."

        # Alle enabled VMs deployen
        failed=0
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*(.+) ]]; then
                vm_name="${BASH_REMATCH[1]}"
                vm_enabled=""

                while IFS= read -r subline; do
                    if [[ $subline =~ ^[[:space:]]*-[[:space:]]*name: ]] || [[ -z "$subline" && -n "$vm_enabled" ]]; then
                        break
                    fi
                    if [[ $subline =~ ^[[:space:]]*enabled:[[:space:]]*(.+) ]]; then
                        vm_enabled="${BASH_REMATCH[1]}"
                    fi
                done

                if [[ "$vm_enabled" == "true" ]]; then
                    deploy_to_vm "$vm_name" "$SERVICE" || failed=$((failed + 1))
                fi
            fi
        done < "$VMS_CONFIG"

        if [ $failed -gt 0 ]; then
            log_error "$failed VM(s) failed to deploy"
            exit 1
        else
            log_info "✅ All VMs deployed successfully!"
        fi
        ;;

    service)
        SERVICE="${2:-}"

        if [ -z "$SERVICE" ]; then
            log_error "Service name required!"
            echo "Usage: $0 service <service-name>"
            exit 1
        fi

        # VM für Service finden
        VM_NAME=$(get_vm_for_service "$SERVICE")

        if [ -z "$VM_NAME" ]; then
            log_error "No VM configured for service '$SERVICE'"
            log_info "Add mapping to vms.yml under 'service_mapping:'"
            exit 1
        fi

        log_info "Service '$SERVICE' → VM '$VM_NAME'"
        deploy_to_vm "$VM_NAME" "$SERVICE"
        ;;

    help|--help|-h|"")
        show_help
        ;;

    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
