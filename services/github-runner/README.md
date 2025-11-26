# GitHub Actions Self-hosted Runner

GitHub Actions Runner als Docker Container für automatisches Deployment deiner Homelab-Services.

## 🏗️ Architektur

```
┌─────────────────────────────────────────────┐
│              Proxmox Host                    │
│                                              │
│  ┌──────────────────┐  ┌─────────────────┐ │
│  │  Runner VM       │  │  Services VM     │ │
│  │  1 CPU / 1-2GB   │  │  4 CPU / 8GB     │ │
│  │                  │  │                  │ │
│  │  ┌────────────┐  │  │  ┌────────────┐ │ │
│  │  │ GitHub     │──SSH─→│ code-server│ │ │
│  │  │ Runner     │  │  │  │ plex       │ │ │
│  │  │ (Container)│  │  │  │ ...        │ │ │
│  │  └────────────┘  │  │  └────────────┘ │ │
│  └──────────────────┘  └─────────────────┘ │
│           ↕ HTTPS (443)                     │
└─────────────────────────────────────────────┘
              │
              ↓
        GitHub.com
```

## 💡 Warum separate VM?

- ✅ **Isolation**: Runner kann Services-VM nicht direkt kompromittieren
- ✅ **Skalierbar**: Ein Runner kann mehrere Service-VMs verwalten
- ✅ **Ressourcen**: Runner braucht minimal Ressourcen
- ✅ **Wartung**: Services-VM kann neu aufgesetzt werden ohne Runner zu beeinflussen
- ✅ **Sicherheit**: Kleinere Angriffsfläche

## 📋 Voraussetzungen

### Runner-VM (diese VM)
- **Betriebssystem**: Debian/Ubuntu
- **CPU**: 1 vCPU (minimum)
- **RAM**: 1-2 GB
- **Disk**: 8-10 GB
- **Software**: Docker & Docker Compose
- **Netzwerk**: Zugriff auf Services-VM via SSH
- **Internet**: Ausgehende HTTPS-Verbindung (Port 443) zu GitHub

### Services-VM (deine andere VM)
- Docker & Docker Compose installiert
- SSH-Server aktiv
- Homelab-Repository geklont nach `~/homelab`

## 🚀 Installation

### 1. Runner-VM aufsetzen

```bash
# In Proxmox: Neue VM erstellen
# - 1 vCPU
# - 1-2 GB RAM
# - 10 GB Disk
# - Debian/Ubuntu installieren

# Docker installieren
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Neu einloggen oder
newgrp docker
```

### 2. Repository klonen

```bash
# Auf der Runner-VM
cd ~
git clone https://github.com/DEIN_USERNAME/Homelab.git homelab
cd homelab/services/github-runner
```

### 3. GitHub Personal Access Token erstellen

1. Gehe zu: https://github.com/settings/tokens
2. Klicke: **Generate new token (classic)**
3. Name: `homelab-runner`
4. Expiration: `No expiration` oder `1 year`
5. Scopes auswählen:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
6. Klicke: **Generate token**
7. **Kopiere den Token** (wird nur einmal angezeigt!)

### 4. Environment-Variablen konfigurieren

```bash
# .env aus Vorlage erstellen
cp .env.example .env

# Datei bearbeiten
nano .env
```

Trage ein:
```env
REPO_URL=https://github.com/DEIN_USERNAME/Homelab
ACCESS_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx  # Dein Token von Schritt 3
RUNNER_NAME=homelab-runner
```

**Wichtig:** `.env` enthält Secrets und wird nicht committet!

### 5. SSH-Zugriff zur Services-VM einrichten

```bash
# Setup-Skript ausführen
bash setup-ssh.sh

# Public Key anzeigen
cat ssh/id_ed25519.pub
```

**Auf der Services-VM:**
```bash
# SSH in Services-VM
ssh user@services-vm-ip

# Public Key zu authorized_keys hinzufügen
nano ~/.ssh/authorized_keys
# → Public Key einfügen und speichern
```

**Zurück auf der Runner-VM:**

SSH Config bearbeiten:
```bash
nano ssh/config
```

Ersetze:
- `SERVICES_VM_IP` → IP der Services-VM (z.B. `192.168.1.100`)
- `SERVICES_VM_USER` → SSH-User (z.B. `debian`)

**SSH-Verbindung testen:**
```bash
# Test mit Docker
docker compose run --rm github-runner ssh -F /root/.ssh/config services-vm 'echo "✅ SSH works!"'
```

### 6. Runner starten

```bash
# Im Vordergrund (zum Testen)
docker compose up

# Logs beobachten - du solltest sehen:
# "Runner successfully added"
# "Runner successfully registered"
# "Listening for Jobs"

# Im Hintergrund starten
docker compose up -d
```

### 7. Runner in GitHub verifizieren

Gehe zu: **GitHub Repo → Settings → Actions → Runners**

Du solltest deinen Runner sehen:
- Name: `homelab-runner`
- Status: 🟢 **Idle**
- Labels: `self-hosted, linux, x64, homelab`

## ✅ Testen

### Test 1: Manueller Workflow-Trigger

1. Gehe zu: **GitHub → Actions → Deploy to Homelab**
2. Klicke: **Run workflow** → **Run workflow**
3. Beobachte den Workflow (sollte grün werden ✅)

### Test 2: Git Push

```bash
# Auf deinem lokalen Rechner
cd dein-homelab-repo
echo "# Test" >> README.md
git add README.md
git commit -m "test: runner deployment"
git push

# Gehe zu GitHub → Actions und beobachte den Workflow
```

### Test 3: Logs auf Runner-VM

```bash
# Auf Runner-VM
cd ~/homelab/services/github-runner

# Container Logs
docker compose logs -f
```

## 🔧 Verwaltung

### Logs anzeigen

```bash
# Alle Logs
docker compose logs

# Live-Logs
docker compose logs -f

# Letzte 100 Zeilen
docker compose logs --tail=100
```

### Runner neustarten

```bash
docker compose restart
```

### Runner stoppen

```bash
docker compose down
```

### Runner updaten

```bash
# Neues Image herunterladen
docker compose pull

# Mit neuem Image starten
docker compose up -d
```

### Runner Status in GitHub prüfen

**Repo → Settings → Actions → Runners**

Status-Bedeutung:
- 🟢 **Idle**: Wartet auf Jobs (gut!)
- 🔵 **Active**: Führt gerade einen Job aus
- 🔴 **Offline**: Container läuft nicht oder keine Verbindung

## 🐛 Troubleshooting

### Runner registriert sich nicht

**Symptom:** Container startet, aber Runner erscheint nicht in GitHub

```bash
# Logs prüfen
docker compose logs

# Häufige Ursachen:
# - Falscher ACCESS_TOKEN
# - Falsche REPO_URL
# - Token hat nicht die richtigen Permissions (repo, workflow)
```

**Lösung:**
```bash
# Neuen Token generieren (siehe Schritt 3)
# .env aktualisieren
nano .env

# Container neu starten
docker compose down
docker compose up -d
```

### SSH zur Services-VM funktioniert nicht

**Symptom:** Workflow schlägt fehl mit "Permission denied" oder "Connection refused"

```bash
# Test SSH von Runner aus
docker compose run --rm github-runner ssh -F /root/.ssh/config services-vm 'hostname'

# Häufige Ursachen:
# - Public Key nicht auf Services-VM authorized_keys
# - Falsche IP/User in ssh/config
# - SSH-Server auf Services-VM läuft nicht
# - Firewall blockiert Port 22
```

**Lösung:**
```bash
# Auf Services-VM: SSH-Server Status prüfen
sudo systemctl status ssh

# Public Key nochmal kopieren
# Auf Runner-VM:
cat ssh/id_ed25519.pub

# Auf Services-VM:
nano ~/.ssh/authorized_keys
# → Key einfügen

# SSH Config prüfen
nano ssh/config
# → IP/User korrekt?
```

### Runner offline nach VM-Neustart

**Symptom:** Nach Neustart der Runner-VM ist der Runner offline

```bash
# Docker Service Status prüfen
sudo systemctl status docker

# Container Status prüfen
docker compose ps

# Container neu starten
docker compose up -d
```

**Auto-Start aktivieren:**
```bash
# Docker beim Boot starten
sudo systemctl enable docker

# Container automatisch starten (bereits in docker-compose.yml: restart: unless-stopped)
```

### "Disk space" Fehler

**Symptom:** Runner schlägt fehl mit "No space left on device"

```bash
# Disk Space prüfen
df -h

# Docker aufräumen
docker system prune -a -f

# Alte Runner-Workdirs löschen (falls vorhanden)
docker compose down
rm -rf runner-data/*
docker compose up -d
```

### Workflow hängt bei "Waiting for runner"

**Symptom:** Workflow bleibt gelb und wartet auf Runner

**Ursachen:**
- Runner-VM ist offline
- Container läuft nicht
- Runner ist offline in GitHub
- Workflow nutzt falsche Labels

```bash
# Auf Runner-VM: Status prüfen
docker compose ps
docker compose logs --tail=50

# In GitHub: Runner Status prüfen
# Settings → Actions → Runners
# Status sollte "Idle" sein, nicht "Offline"
```

### Runner läuft, aber Deployment schlägt fehl

**Symptom:** Workflow läuft, aber Services werden nicht deployed

```bash
# Workflow Logs in GitHub prüfen
# Häufig: SSH-Befehle schlagen fehl

# Auf Services-VM: Homelab-Repo prüfen
cd ~/homelab
git status
ls -la

# Deployment-Skript manuell testen
bash scripts/deploy.sh all update
```

## 🔒 Sicherheit

### Secrets Management

- ✅ `.env` ist in `.gitignore` (wird nicht committet)
- ✅ `ssh/` ist in `.gitignore` (Keys werden nicht committet)
- ✅ ACCESS_TOKEN wird nie in Logs angezeigt
- ✅ Runner hat nur Zugriff auf Services-VM, nicht umgekehrt

### Network Security

```bash
# Auf Runner-VM: Firewall aktivieren
sudo ufw enable

# Nur ausgehend HTTPS (für GitHub) und SSH zur Services-VM nötig
# Keine eingehenden Ports nötig!

# Services-VM IP erlauben (optional, ist outgoing)
sudo ufw allow out to SERVICES_VM_IP proto tcp port 22
```

### SSH Key Rotation

```bash
# Alle 6-12 Monate neue Keys generieren
cd ~/homelab/services/github-runner
rm -rf ssh/
bash setup-ssh.sh
# Dann neuen Public Key auf Services-VM eintragen
```

### GitHub Token Rotation

```bash
# Token regelmäßig erneuern (alle 6-12 Monate)
# 1. Neuen Token in GitHub generieren
# 2. .env aktualisieren
# 3. Container neu starten
nano .env
docker compose restart
```

## 📊 Monitoring

### Runner Status überwachen

**Option 1: GitHub UI**
- Repo → Settings → Actions → Runners
- Status: Idle/Active/Offline

**Option 2: Email-Benachrichtigungen**
- GitHub schickt Emails bei fehlgeschlagenen Workflows

**Option 3: Healthcheck (optional)**

Füge zu `docker-compose.yml` hinzu:
```yaml
healthcheck:
  test: ["CMD", "pgrep", "Runner.Listener"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Logs

```bash
# Live-Logs verfolgen
docker compose logs -f

# Logs durchsuchen
docker compose logs | grep ERROR
docker compose logs | grep "Successfully"
```

## 🔄 Backup & Recovery

### Was muss gesichert werden?

- ✅ `.env` - Environment Variables (TOKEN!)
- ✅ `ssh/` - SSH Keys
- ⚠️ `docker-compose.yml` - Ist im Git-Repo

### Backup erstellen

```bash
cd ~/homelab/services/github-runner

# Backup mit Verschlüsselung (empfohlen)
tar -czf - .env ssh/ | gpg -c > runner-backup-$(date +%Y%m%d).tar.gz.gpg

# Oder ohne Verschlüsselung (unsicher!)
tar -czf runner-backup-$(date +%Y%m%d).tar.gz .env ssh/
```

### Wiederherstellung

```bash
# Von Backup wiederherstellen
gpg -d runner-backup-YYYYMMDD.tar.gz.gpg | tar -xzf -

# Container neu starten
docker compose up -d
```

### Komplette Neu-Installation

Falls Runner-VM komplett neu aufgesetzt werden muss:

1. Neue VM aufsetzen (Schritt 1)
2. Docker installieren
3. Repo klonen
4. Backup wiederherstellen (`.env` + `ssh/`)
5. Container starten: `docker compose up -d`

Fertig! Runner registriert sich automatisch neu.

## 📈 Performance & Ressourcen

### Aktuelle Nutzung prüfen

```bash
# Container Ressourcen
docker stats github-runner

# VM Ressourcen
htop
free -h
df -h
```

### Resource Limits setzen (optional)

In `docker-compose.yml` auskommentieren:

```yaml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 1G
```

### Logs rotieren

Bereits konfiguriert in `docker-compose.yml`:
```yaml
logging:
  options:
    max-size: "10m"
    max-file: "3"
```

## 🎯 Nächste Schritte

- [ ] Runner läuft stabil
- [ ] Automatisches Deployment funktioniert
- [ ] Backup eingerichtet
- [ ] Monitoring eingerichtet
- [ ] Dokumentation gelesen

### Weitere Optimierungen

- **Ephemeral Runner**: Setze `EPHEMERAL=true` für einmalige Jobs
- **Multiple Runners**: Für parallele Workflows
- **Custom Labels**: Für spezifische Service-Deployments
- **Notifications**: Discord/Slack Webhook bei fehlgeschlagenen Deployments

## 📚 Weitere Ressourcen

- [GitHub Actions Self-hosted Runner Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner)
- [Docker Compose Docs](https://docs.docker.com/compose/)

## 🆘 Support

Bei Problemen:
1. Logs prüfen: `docker compose logs`
2. GitHub Runner Status prüfen: Settings → Actions → Runners
3. SSH-Verbindung testen: `docker compose run --rm github-runner ssh services-vm hostname`
4. Dieses README durchsuchen (Troubleshooting-Sektion)
