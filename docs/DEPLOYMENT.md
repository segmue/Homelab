# Automatisches Deployment

Verschiedene Möglichkeiten, um Änderungen aus diesem GitHub-Repo automatisch auf deine Proxmox VM zu deployen.

## Übersicht der Optionen

| Methode | Eleganz | Setup-Aufwand | Vorteile | Nachteile |
|---------|---------|---------------|----------|-----------|
| GitHub Actions + SSH | ⭐⭐⭐⭐⭐ | Mittel | Einfach, sicher, flexibel | Benötigt SSH-Zugang |
| GitHub Actions + Self-hosted Runner | ⭐⭐⭐⭐ | Hoch | Sehr schnell, keine SSH | Zusätzlicher Container |
| Webhook + Listener | ⭐⭐⭐⭐ | Mittel | Schnell, Event-basiert | Port muss offen sein |
| Watchtower | ⭐⭐⭐ | Niedrig | Automatische Updates | Nur für Images, nicht Config |
| Cronjob | ⭐⭐ | Niedrig | Einfach | Nicht elegant, Verzögerung |

## 🚀 Empfehlung: GitHub Actions + SSH

Die eleganteste Lösung für den Start. Jeder Push triggert automatisch ein Deployment.

### Vorteile
- ✅ Keine zusätzliche Software auf der VM
- ✅ Läuft auf GitHub-Infrastruktur
- ✅ Sicherer SSH-Zugang
- ✅ Volle Kontrolle über Deployment-Prozess
- ✅ Läuft nur bei Änderungen

### Setup

#### 1. SSH-Key auf der VM erstellen

```bash
# Auf der VM ausführen
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github-actions

# Public Key zu authorized_keys hinzufügen
cat ~/.ssh/github-actions.pub >> ~/.ssh/authorized_keys

# Private Key anzeigen (für GitHub Secret)
cat ~/.ssh/github-actions
```

#### 2. GitHub Secrets konfigurieren

Gehe zu deinem Repo: **Settings → Secrets and variables → Actions → New repository secret**

Erstelle folgende Secrets:

| Name | Wert | Beschreibung |
|------|------|--------------|
| `SSH_PRIVATE_KEY` | Inhalt von `~/.ssh/github-actions` | Private SSH Key |
| `SSH_HOST` | `192.168.x.x` | IP deiner VM |
| `SSH_USER` | `dein-username` | SSH Username |
| `SSH_PORT` | `22` | SSH Port (falls Standard) |

#### 3. GitHub Actions Workflow erstellen

Die Workflow-Datei ist bereits in `.github/workflows/deploy.yml` vorhanden (siehe unten).

#### 4. Testen

```bash
# Ändere etwas in diesem Repo
git add .
git commit -m "test: deployment trigger"
git push

# Gehe zu GitHub → Actions tab und beobachte den Workflow
```

### Workflow-Datei

Erstelle `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Homelab

on:
  push:
    branches:
      - main
    paths:
      - 'services/**'
      - 'scripts/**'
      - '.github/workflows/deploy.yml'

  workflow_dispatch:  # Manueller Trigger über GitHub UI

jobs:
  deploy:
    runs-on: ubuntu-latest
    name: Deploy to Proxmox VM

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan -H ${{ secrets.SSH_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy to VM
        env:
          SSH_HOST: ${{ secrets.SSH_HOST }}
          SSH_USER: ${{ secrets.SSH_USER }}
          SSH_PORT: ${{ secrets.SSH_PORT }}
        run: |
          ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} << 'EOF'
            set -e
            echo "📦 Deploying Homelab services..."

            # Zum Repo navigieren
            cd ~/homelab

            # Git pull
            echo "🔄 Pulling latest changes..."
            git pull origin main

            # Deployment-Skript ausführen
            echo "🚀 Running deployment script..."
            bash scripts/deploy.sh all update

            echo "✅ Deployment completed!"
          EOF

      - name: Notify on failure
        if: failure()
        run: echo "❌ Deployment failed!"
```

## 🏃 Alternative 1: Self-hosted Runner

Für noch mehr Kontrolle und Geschwindigkeit.

### Vorteile
- ✅ Direkter Zugriff auf VM (kein SSH nötig)
- ✅ Sehr schnell
- ✅ Volle Docker- und System-Integration

### Nachteile
- ⚠️ Zusätzlicher Container/Service auf VM
- ⚠️ Muss registriert und gewartet werden

### Setup

#### 1. Runner auf VM installieren

```bash
# Ordner erstellen
mkdir -p ~/actions-runner && cd ~/actions-runner

# Runner herunterladen (Linux x64)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Entpacken
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
```

#### 2. Runner registrieren

Gehe zu: **GitHub Repo → Settings → Actions → Runners → New self-hosted runner**

Folge den Anweisungen und führe auf der VM aus:

```bash
# Konfigurieren (Token von GitHub)
./config.sh --url https://github.com/DEIN_USERNAME/DEIN_REPO --token DEIN_TOKEN

# Als Service installieren
sudo ./svc.sh install
sudo ./svc.sh start
```

#### 3. Workflow anpassen

```yaml
name: Deploy with Self-hosted Runner

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: self-hosted  # Läuft auf deiner VM!

    steps:
      - uses: actions/checkout@v4

      - name: Deploy
        run: |
          cd $GITHUB_WORKSPACE
          bash scripts/deploy.sh all update
```

## 🪝 Alternative 2: Webhook Listener

Reagiert sofort auf GitHub Push-Events.

### Vorteile
- ✅ Sehr schnelle Reaktion (Sekunden)
- ✅ Event-basiert (kein Polling)
- ✅ Leichtgewichtig

### Nachteile
- ⚠️ Port muss nach außen offen sein (oder Reverse Proxy)
- ⚠️ Zusätzlicher Service

### Setup mit webhook

#### 1. Webhook-Tool installieren

```bash
# Binary herunterladen
wget https://github.com/adnanh/webhook/releases/download/2.8.1/webhook-linux-amd64.tar.gz
tar -xzf webhook-linux-amd64.tar.gz
sudo mv webhook-linux-amd64/webhook /usr/local/bin/
```

#### 2. Webhook-Konfiguration erstellen

`~/homelab-webhook/hooks.json`:

```json
[
  {
    "id": "homelab-deploy",
    "execute-command": "/home/DEIN_USER/homelab/scripts/deploy.sh",
    "command-working-directory": "/home/DEIN_USER/homelab",
    "pass-arguments-to-command": [
      {
        "source": "string",
        "name": "all"
      }
    ],
    "trigger-rule": {
      "match": {
        "type": "payload-hmac-sha256",
        "secret": "DEIN_GEHEIMER_WEBHOOK_SECRET",
        "parameter": {
          "source": "header",
          "name": "X-Hub-Signature-256"
        }
      }
    }
  }
]
```

#### 3. Webhook als Service starten

`/etc/systemd/system/homelab-webhook.service`:

```ini
[Unit]
Description=Homelab Webhook Listener
After=network.target

[Service]
Type=simple
User=DEIN_USER
ExecStart=/usr/local/bin/webhook -hooks /home/DEIN_USER/homelab-webhook/hooks.json -port 9000 -verbose
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable homelab-webhook
sudo systemctl start homelab-webhook
```

#### 4. GitHub Webhook konfigurieren

Gehe zu: **Repo → Settings → Webhooks → Add webhook**

- **Payload URL**: `http://DEINE_VM_IP:9000/hooks/homelab-deploy`
- **Content type**: `application/json`
- **Secret**: `DEIN_GEHEIMER_WEBHOOK_SECRET` (derselbe wie in hooks.json)
- **Events**: Just the push event

#### 5. Firewall öffnen (falls nötig)

```bash
sudo ufw allow 9000/tcp
```

## 🐋 Alternative 3: Watchtower (nur für Images)

Automatisches Update von Docker Images, aber **nicht** für Konfigurations-Änderungen.

### Setup

```bash
# Watchtower Container starten
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --interval 300  # Alle 5 Minuten prüfen
```

⚠️ **Limitation**: Watchtower aktualisiert nur Docker Images, **nicht** deine docker-compose.yml oder andere Configs!

## ⏰ Alternative 4: Cronjob (nicht empfohlen)

Falls du wirklich keine andere Möglichkeit hast.

```bash
# Crontab bearbeiten
crontab -e

# Alle 5 Minuten pullen und deployen
*/5 * * * * cd ~/homelab && git pull && bash scripts/deploy.sh all update >> /tmp/homelab-deploy.log 2>&1
```

**Nachteile**:
- ❌ Läuft auch wenn keine Änderungen da sind
- ❌ Verzögerung bis zu 5 Minuten
- ❌ Unnötige Ressourcen-Nutzung
- ❌ Nicht elegant

## 🎯 Meine Empfehlung für dich

**Start**: GitHub Actions + SSH (Option 1)
- Einfach einzurichten
- Keine zusätzliche Software auf VM
- Läuft nur bei Änderungen
- Gut für Learning

**Später**: Self-hosted Runner (Option 2)
- Wenn du mehr Services hast
- Wenn du schnellere Deployments willst
- Wenn du mehr Kontrolle brauchst

## Testing

Nach dem Setup:

```bash
# Kleine Änderung machen
echo "# Test" >> README.md
git add README.md
git commit -m "test: trigger deployment"
git push

# Bei GitHub Actions: Gehe zu Actions-Tab
# Bei Webhook: Prüfe Logs auf VM
journalctl -u homelab-webhook -f
```

## Monitoring

### GitHub Actions

- Gehe zu **Actions** tab in deinem Repo
- Siehe alle Deployments und deren Status
- Bei Fehlern werden Email-Benachrichtigungen verschickt

### Self-hosted Runner

```bash
# Runner Status
sudo ./svc.sh status

# Logs
journalctl -u actions.runner.* -f
```

### Webhook

```bash
# Webhook Logs
journalctl -u homelab-webhook -f

# Deployment Logs
tail -f /tmp/homelab-deploy.log
```

## Troubleshooting

### SSH Connection fehlschlägt

```bash
# Test SSH-Verbindung
ssh -i ~/.ssh/github-actions user@your-vm-ip

# SSH Debug
ssh -vvv -i ~/.ssh/github-actions user@your-vm-ip
```

### Docker Permissions

```bash
# User zu docker Gruppe hinzufügen
sudo usermod -aG docker $USER

# Neu einloggen oder
newgrp docker
```

### Git Pull fails

```bash
# Falls lokale Änderungen vorhanden
cd ~/homelab
git stash
git pull
```

## Security Best Practices

1. **SSH Keys**: Nie private Keys committen!
2. **Secrets**: Immer GitHub Secrets verwenden
3. **Webhook Secret**: Starkes Secret wählen
4. **Firewall**: Nur nötige Ports öffnen
5. **.env Files**: Nie ins Repo committen (bereits in .gitignore)
6. **SSH Port**: Überlege SSH auf nicht-Standard-Port zu ändern

## Nächste Schritte

1. Wähle eine der Deployment-Methoden
2. Teste mit einer kleinen Änderung
3. Füge Monitoring/Benachrichtigungen hinzu (z.B. Discord/Slack Webhook)
4. Erweitere um automatische Backups vor Deployment
