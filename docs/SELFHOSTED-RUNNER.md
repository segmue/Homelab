# Self-hosted Runner Setup für lokales Netzwerk

Da deine VM nur im lokalen Netzwerk erreichbar ist, ist ein Self-hosted Runner die beste Lösung.

## Warum Self-hosted Runner?

- ✅ Läuft direkt auf deiner VM (kein SSH von außen nötig)
- ✅ Runner kontaktiert GitHub (ausgehende Verbindung über Port 443)
- ✅ Keine Port-Forwards nötig
- ✅ Sehr schnell (direkter Zugriff auf Docker)

## Setup (5 Minuten)

### 1. Runner auf VM installieren

```bash
# SSH in deine VM
ssh user@deine-vm-ip

# Ordner erstellen
mkdir -p ~/actions-runner && cd ~/actions-runner

# Neueste Runner-Version herunterladen
# (Prüfe aktuelle Version auf GitHub)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Entpacken
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
```

### 2. Runner bei GitHub registrieren

**Auf GitHub:**
1. Gehe zu: **Dein Repo → Settings → Actions → Runners**
2. Klicke: **New self-hosted runner**
3. Wähle: **Linux** und **x64**
4. Kopiere den **Token** aus dem Konfigurations-Befehl

**Auf der VM:**
```bash
# Mit deinem Token von GitHub
./config.sh --url https://github.com/segmue/Homelab --token DEIN_TOKEN_VON_GITHUB

# Eingaben während der Konfiguration:
# - Runner group: Einfach Enter (default)
# - Runner name: homelab-runner (oder wie du willst)
# - Work folder: Einfach Enter (default: _work)
# - Labels: Einfach Enter (default: self-hosted,Linux,X64)
```

### 3. Runner als Service installieren

```bash
# Service installieren (läuft automatisch beim Boot)
sudo ./svc.sh install

# Service starten
sudo ./svc.sh start

# Status prüfen
sudo ./svc.sh status
```

### 4. Workflow-Datei anpassen

Erstelle `.github/workflows/deploy-selfhosted.yml`:

```yaml
name: Deploy to Homelab (Self-hosted)

on:
  push:
    branches:
      - main
    paths:
      - 'services/**'
      - 'scripts/**'

  workflow_dispatch:

jobs:
  deploy:
    runs-on: self-hosted  # ← Läuft auf deinem Runner!
    name: Deploy Services

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Deploy Services
        run: |
          echo "📦 Starting deployment..."
          cd $GITHUB_WORKSPACE
          bash scripts/deploy.sh all update
          echo "✅ Deployment completed!"
```

### 5. Alte SSH-Workflow deaktivieren

Umbenennen oder löschen:
```bash
# Entweder umbenennen (wird ignoriert)
mv .github/workflows/deploy.yml .github/workflows/deploy.yml.disabled

# Oder auskommentieren/löschen
```

### 6. Testen

```bash
# Kleine Änderung machen
echo "# Test" >> README.md
git add README.md
git commit -m "test: self-hosted runner"
git push

# Auf GitHub → Actions schauen
# Auf VM Logs anschauen
journalctl -u actions.runner.* -f
```

## Runner verwalten

### Status prüfen
```bash
sudo ./svc.sh status
```

### Logs anschauen
```bash
# Service Logs
journalctl -u actions.runner.* -f

# Runner Logs
cd ~/actions-runner
tail -f _diag/Runner_*.log
```

### Runner stoppen
```bash
sudo ./svc.sh stop
```

### Runner neustarten
```bash
sudo ./svc.sh stop
sudo ./svc.sh start
```

### Runner entfernen
```bash
# Service stoppen und entfernen
sudo ./svc.sh stop
sudo ./svc.sh uninstall

# Bei GitHub deregistrieren
./config.sh remove --token DEIN_TOKEN
```

## Sicherheit

Der Self-hosted Runner:
- ✅ Läuft als normaler User (nicht root)
- ✅ Nur ausgehende Verbindungen zu GitHub (HTTPS Port 443)
- ✅ Keine eingehenden Ports nötig
- ✅ Kann in Firewall komplett abgeschottet werden

**Optional: Runner-User ohne sudo:**
```bash
# Separaten User für Runner erstellen
sudo useradd -m -s /bin/bash github-runner
sudo usermod -aG docker github-runner

# Runner als dieser User installieren
sudo -u github-runner bash
# ... dann normale Installation
```

## Troubleshooting

### Runner startet nicht

```bash
# Logs prüfen
journalctl -u actions.runner.* -n 50

# Manuell testen
cd ~/actions-runner
./run.sh
```

### Docker Permission Denied

```bash
# User zu docker-Gruppe hinzufügen
sudo usermod -aG docker $USER

# Neu einloggen oder
newgrp docker

# Service neustarten
sudo ./svc.sh stop
sudo ./svc.sh start
```

### Runner offline in GitHub

```bash
# Status prüfen
sudo ./svc.sh status

# Neu starten
sudo ./svc.sh stop
sudo ./svc.sh start
```

### Updates

```bash
# Runner updaten (neue Version herunterladen)
cd ~/actions-runner
sudo ./svc.sh stop
curl -o actions-runner-linux-x64-NEW_VERSION.tar.gz -L <URL>
tar xzf ./actions-runner-linux-x64-NEW_VERSION.tar.gz
sudo ./svc.sh start
```

## Vorteile für dein Setup

1. ✅ **Keine Router-Konfiguration** - Keine Port-Forwards nötig
2. ✅ **Sehr sicher** - VM bleibt im lokalen Netzwerk
3. ✅ **Schneller** - Direkter Zugriff auf Docker (kein SSH-Overhead)
4. ✅ **Einfacher** - Weniger bewegliche Teile
5. ✅ **Zuverlässiger** - Läuft auch wenn VM neu startet (Service)

## VM offline?

Wenn die VM offline ist:
- Workflow wartet 5-10 Minuten
- Dann: Timeout → Job fehlgeschlagen
- Sobald VM wieder online: Workflow manuell neu starten oder beim nächsten Push

## Monitoring

### Workflow-Status per Email

GitHub schickt automatisch Emails bei fehlgeschlagenen Workflows.

### Optional: Status-Badge im README

```markdown
![Deploy Status](https://github.com/segmue/Homelab/actions/workflows/deploy-selfhosted.yml/badge.svg)
```

## Nächste Schritte

1. ✅ Self-hosted Runner installieren
2. ✅ Workflow-Datei anpassen
3. ✅ Testen mit kleiner Änderung
4. ⬜ Alte SSH-Workflow entfernen
5. ⬜ Optional: Monitoring/Notifications einrichten
