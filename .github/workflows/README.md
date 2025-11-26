# GitHub Actions Workflows

Dieses Verzeichnis enthält verschiedene Workflows für automatisches Deployment.

## 📋 Verfügbare Workflows

### 1. `deploy-selfhosted.yml` ⭐ **EMPFOHLEN**

**Für:** Separate Runner-VM + Services-VM Setup

**Wie es funktioniert:**
```
GitHub → Self-hosted Runner (Runner-VM) → SSH → Services-VM → Deploy
```

**Voraussetzungen:**
- Runner-VM mit GitHub Runner Container läuft
- SSH-Verbindung von Runner-VM zu Services-VM konfiguriert
- Siehe: `services/github-runner/README.md`

**Trigger:**
- Push auf `main` branch
- Änderungen in `services/` oder `scripts/`
- Manuell über GitHub UI

**Verwendung:**
- Dieser Workflow ist **aktiv** wenn du eine separate Runner-VM hast
- Runner läuft auf: `runs-on: self-hosted`

---

### 2. `deploy.yml` 🔴 **DEAKTIVIERT** (für lokales Netzwerk)

**Für:** Single-VM Setup mit SSH von GitHub Actions

**Wie es funktioniert:**
```
GitHub (Cloud) → SSH → VM → Deploy
```

**Problem:** Funktioniert NICHT wenn deine VM nur im lokalen Netzwerk ist!

**Wann verwenden:**
- ❌ VM nur im lokalen Netzwerk → Geht NICHT
- ✅ VM hat öffentliche IP
- ✅ VM hinter VPN (z.B. Tailscale)
- ✅ Port-Forward auf Router konfiguriert

**Status:**
- Derzeit **nicht aktiv**
- Kann reaktiviert werden wenn VM von außen erreichbar ist

---

## 🔧 Welchen Workflow soll ich nutzen?

### Du hast: Separate Runner-VM + Services-VM
✅ Nutze: `deploy-selfhosted.yml`

**Setup:**
1. Folge: `services/github-runner/README.md`
2. Runner-VM aufsetzen
3. GitHub Runner Container starten
4. Workflow läuft automatisch

### Du hast: Nur eine VM, ist öffentlich erreichbar
⚠️ Nutze: `deploy.yml`

**Setup:**
1. SSH-Keys konfigurieren
2. GitHub Secrets erstellen (SSH_PRIVATE_KEY, SSH_HOST, SSH_USER)
3. Workflow läuft automatisch

**Achtung:** Weniger sicher, da SSH-Port offen sein muss!

### Du hast: Nur eine VM, nur lokales Netzwerk
❌ `deploy.yml` funktioniert NICHT

**Lösungen:**
1. ✅ Self-hosted Runner auf derselben VM installieren
2. ✅ VPN nutzen (z.B. Tailscale)
3. ⚠️ Port-Forward konfigurieren (unsicher)

---

## 🚀 Workflows aktivieren/deaktivieren

### Workflow deaktivieren

**Option 1: Umbenennen**
```bash
mv deploy.yml deploy.yml.disabled
git add .
git commit -m "Disable SSH-based deployment"
git push
```

**Option 2: Branch-Filter ändern**

In der Workflow-Datei:
```yaml
on:
  push:
    branches:
      - never  # Läuft nie
```

### Workflow aktivieren

**Option 1: Zurück umbenennen**
```bash
mv deploy.yml.disabled deploy.yml
git add .
git commit -m "Enable SSH-based deployment"
git push
```

**Option 2: Branch-Filter zurücksetzen**
```yaml
on:
  push:
    branches:
      - main  # Läuft bei Push auf main
```

---

## 📊 Workflows überwachen

### Alle Workflow-Runs anzeigen
**GitHub Repo → Actions**

### Bestimmten Workflow anzeigen
**Actions → Workflow auswählen (z.B. "Deploy to Homelab")**

### Manuell triggern
**Actions → Workflow → Run workflow → Run workflow**

### Status Badge im README

Für `deploy-selfhosted.yml`:
```markdown
![Deploy Status](https://github.com/DEIN_USERNAME/Homelab/actions/workflows/deploy-selfhosted.yml/badge.svg)
```

---

## 🐛 Troubleshooting

### Workflow läuft nicht

**Symptom:** Push auf main, aber kein Workflow läuft

**Lösungen:**
1. Prüfe: Workflow-Datei auf `main` branch?
2. Prüfe: `paths` Filter passt zu geänderten Dateien?
3. Prüfe: Workflow nicht disabled?
4. GitHub Actions Tab → Workflows → Ist Workflow gelistet?

### "Waiting for a runner to pick up this job"

**Symptom:** Workflow hängt gelb bei "Waiting for runner"

**Ursachen:**
- Self-hosted Runner läuft nicht
- Runner ist offline
- Workflow nutzt `runs-on: self-hosted` aber kein Runner verfügbar

**Lösungen:**
```bash
# Auf Runner-VM prüfen
docker compose ps
docker compose logs

# In GitHub prüfen
# Settings → Actions → Runners → Status sollte "Idle" sein
```

### SSH-Fehler im Workflow

**Symptom:** Workflow schlägt fehl mit "Permission denied" oder "Host key verification failed"

**Lösungen:**
```bash
# Auf Runner-VM: SSH-Verbindung testen
cd ~/homelab/services/github-runner
docker compose run --rm github-runner ssh -F ~/.ssh/config services-vm 'echo OK'

# Siehe: services/github-runner/README.md → Troubleshooting
```

### Beide Workflows laufen gleichzeitig

**Problem:** `deploy.yml` und `deploy-selfhosted.yml` laufen beide

**Lösung:** Einen deaktivieren (siehe oben)

---

## 📚 Weitere Informationen

- [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
- [Self-hosted Runner Setup](../../services/github-runner/README.md)
- [Deployment Dokumentation](../../docs/DEPLOYMENT.md)
