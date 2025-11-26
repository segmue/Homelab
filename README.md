# Homelab Setup

Dieses Repository enthält alle Konfigurationen und Services für mein Homelab.

## Infrastruktur

- **Hypervisor**: Proxmox
- **VM**: Debian mit Docker
- **Deployment**: Automatisiert via GitHub Actions

## Services

| Service | Status | Port | Beschreibung |
|---------|--------|------|--------------|
| [code-server](./services/code-server/) | ✅ | 8080 | VS Code im Browser |

## Struktur

```
.
├── services/          # Alle Services mit Docker Compose
│   └── code-server/   # VS Code im Browser
├── scripts/           # Deployment und Hilfsskripte
└── docs/              # Dokumentation
```

## Quick Start

**Neu hier?** → Siehe [docs/QUICKSTART.md](./docs/QUICKSTART.md) für eine ausführliche Anleitung!

### Schnellstart

1. Repository auf VM klonen: `git clone <repo-url> ~/homelab`
2. Service-Ordner öffnen: `cd services/code-server`
3. `.env`-Datei aus `.env.example` erstellen und anpassen
4. Service starten: `docker compose up -d`

## Dokumentation

- 📖 [Quick Start Guide](./docs/QUICKSTART.md) - Erste Schritte
- 🚀 [Deployment Setup](./docs/DEPLOYMENT.md) - Automatisches CI/CD
- 🔧 [Code-Server Guide](./services/code-server/README.md) - VS Code Setup
