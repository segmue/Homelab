# GitHub Actions Self-hosted Runner

GitHub Actions Runner als Docker Container für automatisches Deployment deiner Homelab-Services zu **mehreren VMs**.

## 🏗️ Multi-VM Architektur

```
┌──────────────────────────────────────────────────────────┐
│                    Proxmox Host                          │
│                                                           │
│  ┌──────────────────┐                                    │
│  │  Runner VM       │   SSH    ┌──────────────────┐     │
│  │  1 CPU / 2GB     │──────────→│ Services-VM-1    │     │
│  │                  │          │ • codeserver    │     │
│  │  • GitHub Runner │   SSH    │ • nginx-proxy    │     │
│  │  • Multi-VM      │──────────→┌──────────────────┐     │
│  │    Deployment    │          │ Services-VM-2    │     │
│  └────────┬─────────┘   SSH    │ • postgresql     │     │
│           │         ────────────→│ • redis          │     │
│           │                     └──────────────────┘     │
│           │                     ┌──────────────────┐     │
│           │             SSH     │ Monitoring-VM    │     │
│           └─────────────────────→│ • prometheus     │     │
│                                 │ • grafana        │     │
│                                 └──────────────────┘     │
│           ↕ HTTPS (443)                                  │
└───────────┼──────────────────────────────────────────────┘
            │
      GitHub.com
```

## ⭐ Multi-VM Features

- **Zentrales Deployment**: Ein Runner verwaltet mehrere VMs
- **Service Mapping**: Jeder Service wird automatisch zur richtigen VM deployed
- **Flexible Targets**: Deploy zu spezifischen VMs oder allen auf einmal
- **Inventory Management**: Einfache VM-Verwaltung via `vms.yml`
- **Skalierbar**: Füge neue VMs einfach hinzu

## 💡 Warum separate Runner-VM?

- ✅ **Isolation**: Runner isoliert von Services
- ✅ **Zentrale Steuerung**: Ein Punkt für alle Deployments
- ✅ **Skalierbar**: Verwaltet unbegrenzt viele Service-VMs
- ✅ **Ressourcen-effizient**: Runner braucht minimal Ressourcen
- ✅ **Wartung**: Service-VMs können neu aufgesetzt werden
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

### 5. Multi-VM SSH-Zugriff einrichten

**Setup-Skript ausführen:**
```bash
bash setup-ssh.sh
```

Dies erstellt:
- SSH Key-Pair (einmal für alle VMs)
- `vms.yml` Template
- SSH Config (wird aus vms.yml generiert)

**VMs konfigurieren:**
```bash
# vms.yml bearbeiten
nano vms.yml
```

Füge deine VMs hinzu:
```yaml
vms:
  - name: services-vm-1
    host: 192.168.1.100    # Deine VM IP
    user: debian           # SSH User
    port: 22
    description: "Hauptserver"
    enabled: true

  - name: services-vm-2    # Weitere VMs hinzufügen
    host: 192.168.1.101
    user: debian
    port: 22
    description: "Datenbank-Server"
    enabled: true

service_mapping:
  codeserver: services-vm-1   # Service → VM Zuordnung
  # plex: services-vm-1
  # postgresql: services-vm-2
```

**Public Key zu ALLEN VMs hinzufügen:**
```bash
# Public Key anzeigen
cat ssh/id_ed25519.pub
```

Auf **jeder VM**:
```bash
ssh user@vm-ip
nano ~/.ssh/authorized_keys
# → Public Key einfügen und speichern
```

**SSH Config neu generieren:**
```bash
# Nach Änderungen an vms.yml
bash setup-ssh.sh
```

**Verbindungen testen:**
```bash
# Liste alle VMs
cd ~/homelab/services/github-runner
bash deploy-to-vm.sh list

# Teste SSH zu jeder VM
docker compose run --rm github-runner ssh services-vm-1 'hostname'
docker compose run --rm github-runner ssh services-vm-2 'hostname'
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

## 🎯 Multi-VM Deployment Usage

### Alle VMs deployen

```bash
# Via GitHub Actions (empfohlen)
GitHub → Actions → Deploy to Homelab → Run workflow → Run workflow

# Oder manuell auf Runner-VM
cd ~/homelab/services/github-runner
bash deploy-to-vm.sh deploy-all
```

### Einzelne VM deployen

```bash
# Via GitHub Actions
GitHub → Actions → Deploy to Homelab → Run workflow
  → Target VM: services-vm-1
  → Run workflow

# Oder manuell
bash deploy-to-vm.sh deploy services-vm-1
```

### Einzelnen Service deployen

```bash
# Via GitHub Actions
GitHub → Actions → Deploy to Homelab → Run workflow
  → Specific service: codeserver
  → Run workflow

# Oder manuell (deployed automatisch zur konfigurierten VM)
bash deploy-to-vm.sh service codeserver
```

### Service zu spezifischer VM deployen

```bash
# Nur dieser Service auf dieser VM
bash deploy-to-vm.sh deploy services-vm-1 codeserver
```

### VMs auflisten

```bash
cd ~/homelab/services/github-runner
bash deploy-to-vm.sh list
```

### Neue VM hinzufügen

1. In `vms.yml` neue VM eintragen
2. `bash setup-ssh.sh` ausführen (regeneriert SSH config)
3. Public Key auf neuer VM hinzufügen
4. SSH testen: `docker compose run --rm github-runner ssh neue-vm hostname`
5. Service-Mapping in `vms.yml` aktualisieren
6. Fertig! Deployments funktionieren automatisch

## ✅ Testen

### Test 1: VMs Liste anzeigen

```bash
cd ~/homelab/services/github-runner
bash deploy-to-vm.sh list
```

Du solltest alle konfigurierten VMs sehen.

### Test 2: Manueller Workflow-Trigger

1. Gehe zu: **GitHub → Actions → Deploy to Homelab (Multi-VM)**
2. Klicke: **Run workflow**
3. Optional: Spezifische VM oder Service wählen
4. Klicke: **Run workflow**
5. Beobachte den Workflow (sollte grün werden ✅)

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

### "Bad owner or permissions on /root/.ssh/config"

**Symptom:** SSH-Fehler beim Testen oder Workflow schlägt fehl

**Ursache:** SSH-Dateien gehören dem falschen User (nicht root)

**Lösung:**
```bash
cd ~/homelab/services/github-runner

# Permissions automatisch setzen
bash setup-ssh.sh

# Oder manuell:
sudo chown -R root:root ssh/
sudo chmod 700 ssh/
sudo chmod 600 ssh/config
sudo chmod 600 ssh/id_ed25519
sudo chmod 644 ssh/id_ed25519.pub
sudo chmod 644 ssh/known_hosts

# Testen
docker compose run --rm github-runner ssh your-vm 'hostname'
```

**Hinweis:** Das `setup-ssh.sh` Skript setzt die Permissions seit v2.0 automatisch korrekt.

### Service-Namen mit Minus funktionieren nicht

**Symptom:** Services wie `codeserver` werden nicht gefunden oder als Befehl interpretiert

**Ursache:** War ein Bug in alten Versionen (vor v2.0) - Service-Namen wurden nicht korrekt gequotet

**Lösung:** Update auf neueste Version oder:

In `vms.yml`:
```yaml
service_mapping:
  codeserver: services-vm-1  # ✅ Funktioniert ab v2.0
  nginx-proxy: services-vm-1   # ✅ Auch mit Minus
```

Falls weiterhin Probleme:
```bash
# Git pull für Updates
cd ~/homelab
git pull

# Alte Workaround (nicht mehr nötig):
# Services ohne Minus benennen: codeserver statt codeserver
```

### "Failed to add the host to the list of known_hosts"

**Symptom:** Warnung beim SSH-Test, aber Verbindung funktioniert

**Ursache:** Kosmetisches Problem - kann ignoriert werden

**Status:** Harmlos! SSH funktioniert trotzdem dank `StrictHostKeyChecking accept-new`

Optional beheben:
```bash
cd ~/homelab/services/github-runner
sudo touch ssh/known_hosts
sudo chmod 644 ssh/known_hosts
sudo chown root:root ssh/known_hosts
```

### "setlocale: LC_ALL: cannot change locale"

**Symptom:** Locale-Warnung in Logs

**Ursache:** War in alten Versionen (vor v2.0)

**Lösung:** Update docker-compose.yml oder Git pull:

```yaml
environment:
  - LC_ALL=C.UTF-8
  - LANG=C.UTF-8
```

Dann Container neu starten:
```bash
docker compose down
docker compose up -d
```

**Hinweis:** Ab v2.0 ist dies bereits in der docker-compose.yml enthalten.

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
