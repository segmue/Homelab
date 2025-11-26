#!/bin/bash

# Homelab Deployment Script
# Dieses Skript wird von GitHub Actions oder lokal ausgeführt

set -e  # Exit bei Fehler

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktionen
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parameter
SERVICE_NAME=${1:-"all"}
ACTION=${2:-"update"}

log_info "Starting deployment for: $SERVICE_NAME"

# Repository-Root finden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$REPO_ROOT/services"

cd "$REPO_ROOT"

# Git Pull (neueste Änderungen holen)
if [ -d ".git" ]; then
    log_info "Pulling latest changes from git..."
    git pull origin main || log_warn "Git pull failed, continuing anyway..."
fi

# Funktion: Service deployen
deploy_service() {
    local service=$1
    local service_path="$SERVICES_DIR/$service"

    if [ ! -d "$service_path" ]; then
        log_error "Service '$service' not found at $service_path"
        return 1
    fi

    if [ ! -f "$service_path/docker-compose.yml" ]; then
        log_error "No docker-compose.yml found for service '$service'"
        return 1
    fi

    log_info "Deploying service: $service"
    cd "$service_path"

    # Prüfen ob .env existiert
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            log_warn ".env not found, but .env.example exists. Please create .env file!"
            log_warn "Skipping $service"
            return 1
        fi
    fi

    # Docker Compose Befehle
    case $ACTION in
        "update")
            log_info "Pulling latest images..."
            docker compose pull
            log_info "Restarting containers..."
            docker compose up -d --remove-orphans
            ;;
        "restart")
            log_info "Restarting containers..."
            docker compose restart
            ;;
        "stop")
            log_info "Stopping containers..."
            docker compose down
            ;;
        "start")
            log_info "Starting containers..."
            docker compose up -d
            ;;
        *)
            log_error "Unknown action: $ACTION"
            return 1
            ;;
    esac

    log_info "✓ Service '$service' deployed successfully"
    cd "$REPO_ROOT"
}

# Alle Services oder nur einen deployen
if [ "$SERVICE_NAME" = "all" ]; then
    log_info "Deploying all services..."

    for service_dir in "$SERVICES_DIR"/*/ ; do
        if [ -d "$service_dir" ]; then
            service=$(basename "$service_dir")
            deploy_service "$service" || log_warn "Failed to deploy $service"
        fi
    done
else
    deploy_service "$SERVICE_NAME"
fi

log_info "Deployment completed!"

# Optional: Cleanup alter Images
log_info "Cleaning up unused Docker resources..."
docker system prune -f

log_info "✓ All done!"
