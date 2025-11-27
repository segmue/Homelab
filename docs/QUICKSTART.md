# Quick Start Guide

Schnellstart-Anleitung für dein Homelab.

## 🚀 Erste Schritte

### 1. Repository auf VM klonen

```bash
# SSH in deine VM
ssh user@deine-vm-ip

# Repository klonen
cd ~
git clone https://github.com/DEIN_USERNAME/Homelab.git homelab
cd homelab
```

### 2. Code-Server starten (dein erster Service)

```bash
# Zum Service-Verzeichnis
cd services/codeserver

# Environment-Variablen konfigurieren
cp .env.example .env
nano .env  # Passwort ändern!

# Service starten
docker compose up -d

# Logs überprüfen
docker compose logs -f
```

### 3. Zugriff auf Code-Server

Öffne im Browser: `http://deine-vm-ip:8080`

Login mit dem Passwort aus der `.env`-Datei.

## 🔄 Automatisches Deployment einrichten

Damit Änderungen aus GitHub automatisch auf deiner VM ankommen:

### Option A: GitHub Actions + SSH (Empfohlen)

#### Auf der VM:

```bash
# SSH-Key erstellen
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github-actions

# Public Key hinzufügen
cat ~/.ssh/github-actions.pub >> ~/.ssh/authorized_keys

# Private Key anzeigen (für GitHub)
cat ~/.ssh/github-actions
# Kopiere die gesamte Ausgabe!
```

#### Auf GitHub:

1. Gehe zu: **Repo → Settings → Secrets and variables → Actions**
2. Erstelle folgende Secrets:
   - `SSH_PRIVATE_KEY`: Der komplette private Key (alles von `cat ~/.ssh/github-actions`)
   - `SSH_HOST`: IP deiner VM (z.B. `192.168.1.100`)
   - `SSH_USER`: Dein SSH-Username (z.B. `debian`)
   - `SSH_PORT`: `22` (Standard SSH-Port)

#### Testen:

```bash
# Auf deinem lokalen Rechner
cd dein-lokales-homelab-repo
echo "# Test" >> README.md
git add README.md
git commit -m "test: deployment trigger"
git push

# Gehe zu GitHub → Actions Tab und beobachte den Workflow
```

### Option B: Webhook (Alternativ)

Siehe [docs/DEPLOYMENT.md](./DEPLOYMENT.md) für detaillierte Anweisungen.

## 📋 Tägliche Operationen

### Neuen Service hinzufügen

```bash
# Ordnerstruktur erstellen
mkdir -p services/neuer-service
cd services/neuer-service

# docker-compose.yml erstellen
nano docker-compose.yml

# .env.example erstellen
nano .env.example

# README erstellen
nano README.md
```

### Service verwalten

```bash
# Service starten
docker compose up -d

# Logs anzeigen
docker compose logs -f

# Service neustarten
docker compose restart

# Service stoppen
docker compose down

# Service updaten
docker compose pull
docker compose up -d
```

### Alle Services verwalten

```bash
# Alle Services updaten
cd ~/homelab
bash scripts/deploy.sh all update

# Einzelnen Service updaten
bash scripts/deploy.sh codeserver update

# Service neustarten
bash scripts/deploy.sh codeserver restart
```

## 🔧 Nützliche Befehle

### Docker

```bash
# Alle laufenden Container
docker ps

# Alle Container (auch gestoppte)
docker ps -a

# Container-Logs
docker logs <container-name>

# Container-Shell öffnen
docker exec -it <container-name> /bin/bash

# Ressourcen-Nutzung
docker stats

# Alte Images/Container aufräumen
docker system prune -a
```

### Git

```bash
# Neueste Änderungen holen
git pull

# Status prüfen
git status

# Änderungen verwerfen
git reset --hard origin/main

# Branch wechseln
git checkout main
```

### System

```bash
# Disk Space
df -h

# Memory Usage
free -h

# Running Processes
htop

# Network Connections
sudo netstat -tulpn
```

## 🛟 Troubleshooting

### Container startet nicht

```bash
# Logs prüfen
docker compose logs

# Container Status
docker compose ps

# Komplett neu starten
docker compose down
docker compose up -d
```

### Port bereits belegt

```bash
# Prozess auf Port finden
sudo netstat -tlnp | grep :8080

# Port in .env ändern
nano .env
# PORT=8081

# Service neustarten
docker compose down
docker compose up -d
```

### Deployment schlägt fehl

```bash
# GitHub Actions Logs prüfen (auf GitHub.com)
# Repository → Actions → Workflow anklicken

# Auf VM manuell testen
cd ~/homelab
git pull
bash scripts/deploy.sh all update
```

### Speicherplatz voll

```bash
# Docker aufräumen
docker system prune -a

# Logs löschen
sudo journalctl --vacuum-time=7d

# Große Dateien finden
sudo du -h --max-depth=1 / | sort -hr | head -20
```

## 📚 Weitere Dokumentation

- [Deployment-Optionen](./DEPLOYMENT.md) - Detaillierte CI/CD-Setups
- [Code-Server README](../services/codeserver/README.md) - Code-Server Dokumentation
- [Repository README](../README.md) - Haupt-README

## 🎯 Nächste Schritte

1. ✅ Code-Server läuft
2. ✅ Automatisches Deployment eingerichtet
3. ⬜ Reverse Proxy hinzufügen (z.B. Traefik, Nginx Proxy Manager)
4. ⬜ SSL-Zertifikate einrichten (Let's Encrypt)
5. ⬜ Weitere Services hinzufügen (siehe Ideen unten)

## 💡 Service-Ideen

- **Reverse Proxy**: Traefik, Nginx Proxy Manager
- **Dashboard**: Heimdall, Homer, Homarr
- **Monitoring**: Prometheus, Grafana, Uptime Kuma
- **Media**: Plex, Jellyfin
- **Files**: Nextcloud, FileBrowser
- **Notes**: Joplin Server, Trilium
- **Git**: Gitea, Gogs
- **Databases**: PostgreSQL, MariaDB, Redis
- **Automation**: n8n, Home Assistant

## 🆘 Support

Bei Problemen:
1. Logs prüfen: `docker compose logs`
2. GitHub Actions prüfen (bei Deployment-Problemen)
3. Google/Stack Overflow
4. Service-spezifische Dokumentation

## 🎉 Viel Erfolg!

Happy Homelabbing! 🏠🔬
