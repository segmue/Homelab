# Code-Server

VS Code im Browser - programmiere von überall aus auf deinem Homelab.

## Features

- 🌐 VS Code im Browser
- 🔒 Passwortgeschützt
- 💾 Persistente Konfiguration und Projekte
- 🐳 Vollständig containerisiert
- 🔄 Auto-Restart bei Fehlern

## Voraussetzungen

- Docker und Docker Compose installiert
- Debian VM mit Docker (bereits vorhanden)
- Mindestens 2GB RAM empfohlen

## Installation

### 1. Environment-Variablen konfigurieren

```bash
# .env-Datei aus Vorlage erstellen
cp .env.example .env

# Datei bearbeiten und Passwort ändern
nano .env
```

**Wichtig:** Ändere unbedingt die Passwörter in der `.env`-Datei!

### 2. Service starten

```bash
# Im Vordergrund starten (zum Testen)
docker compose up

# Im Hintergrund starten (Produktiv)
docker compose up -d
```

### 3. Zugriff

Öffne im Browser: `http://<vm-ip>:8080`

Login mit dem Passwort aus der `.env`-Datei.

## Verwendung

### Logs anzeigen

```bash
# Alle Logs
docker compose logs

# Live-Logs verfolgen
docker compose logs -f

# Letzte 100 Zeilen
docker compose logs --tail=100
```

### Service neustarten

```bash
docker compose restart
```

### Service stoppen

```bash
docker compose down
```

### Service aktualisieren

```bash
# Neues Image herunterladen
docker compose pull

# Service mit neuem Image starten
docker compose up -d
```

## Konfiguration

### Persistente Daten

Die folgenden Verzeichnisse werden automatisch erstellt und bleiben bei Updates erhalten:

- `./config` - code-server Konfiguration, Extensions, Settings
- `./projects` - Deine Projekte und Code

### Docker-in-Docker (Optional)

Um Docker-Befehle innerhalb von code-server auszuführen:

1. Auskommentiere in `docker-compose.yml`:
   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   ```

2. Installiere Docker CLI im Container:
   ```bash
   # Im code-server Terminal:
   curl -fsSL https://get.docker.com | sh
   ```

### Reverse Proxy (Empfohlen für Produktion)

Für HTTPS und Domain-Namen empfehle ich einen Reverse Proxy wie:
- **Traefik** (Docker-native, Auto-SSL)
- **Nginx Proxy Manager** (GUI, einfach)
- **Caddy** (Automatisches HTTPS)

Beispiel-Konfiguration kommt in einem späteren Setup.

## Sicherheit

### Passwort-Hash verwenden (Empfohlen)

Statt Klartext-Passwort einen Hash verwenden:

```bash
# Hash generieren (auf deinem lokalen Rechner mit Node.js)
echo -n "dein-sicheres-passwort" | npx argon2-cli -e
```

Dann in `.env`:
```env
# PASSWORD auskommentieren und stattdessen:
HASHED_PASSWORD=<dein-hash>
```

### Firewall konfigurieren

```bash
# Nur von deinem Netzwerk erreichbar
sudo ufw allow from 192.168.1.0/24 to any port 8080
```

### Regelmäßige Updates

```bash
# Automatisch aktualisieren (Cronjob)
0 2 * * 0 cd /pfad/zu/homelab/services/code-server && docker compose pull && docker compose up -d
```

## Troubleshooting

### Port bereits belegt

```bash
# Prüfen welcher Prozess Port 8080 nutzt
sudo netstat -tlnp | grep 8080

# Anderen Port in .env konfigurieren
PORT=8081
```

### Container startet nicht

```bash
# Logs prüfen
docker compose logs

# Container und Volumes komplett neu erstellen
docker compose down -v
docker compose up -d
```

### Permission-Probleme

```bash
# Korrekte PUID/PGID setzen
id -u  # Deine User-ID
id -g  # Deine Group-ID

# In .env eintragen
PUID=1000
PGID=1000
```

### Extensions installieren funktioniert nicht

Code-server nutzt eine eigene Extension-Registry. Manche VS Code Extensions sind nicht verfügbar.

Lösung: Extensions manuell als `.vsix` installieren:
1. Extension von [Open VSX Registry](https://open-vsx.org/) herunterladen
2. In code-server: Extensions → "..." → "Install from VSIX"

## Nützliche Befehle

```bash
# Container Shell öffnen
docker compose exec code-server /bin/bash

# Ressourcen-Nutzung anzeigen
docker stats code-server

# Alle container-Prozesse anzeigen
docker compose ps

# Container komplett neu bauen
docker compose up -d --force-recreate
```

## Backup

### Wichtige Daten sichern

```bash
# Backup erstellen
tar -czf code-server-backup-$(date +%Y%m%d).tar.gz config/ projects/

# Backup wiederherstellen
tar -xzf code-server-backup-YYYYMMDD.tar.gz
```

### Automatisches Backup (Optional)

Siehe `/scripts/backup.sh` (wird in Zukunft hinzugefügt)

## Weitere Informationen

- [Offizielle Dokumentation](https://coder.com/docs/code-server)
- [GitHub Repository](https://github.com/coder/code-server)
- [Docker Hub](https://hub.docker.com/r/codercom/code-server)

## Support

Bei Problemen:
1. Logs prüfen: `docker compose logs`
2. GitHub Issues: https://github.com/coder/code-server/issues
3. Homelab Repo Issues: (dein Repo)
