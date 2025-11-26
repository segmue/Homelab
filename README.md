# Homelab Setup

Dieses Repository enthält alle Konfigurationen und Services für mein Homelab.

## Infrastruktur

```
┌─────────────────────────────────────────────┐
│              Proxmox Host                    │
│                                              │
│  ┌──────────────────┐  ┌─────────────────┐ │
│  │  Runner VM       │  │  Services VM     │ │
│  │  1 CPU / 2GB     │  │  4 CPU / 8GB     │ │
│  │                  │  │                  │ │
│  │  • GitHub Runner │──SSH─→ • Services  │ │
│  └──────────────────┘  └─────────────────┘ │
│           ↕                                  │
└───────────┼──────────────────────────────────┘
            │
      GitHub.com
```

- **Hypervisor**: Proxmox
- **Runner VM**: 1 CPU, 2GB RAM - GitHub Actions Runner
- **Services VM**: Debian mit Docker - Alle Services
- **Deployment**: Automatisiert via Self-hosted Runner

## Services

### Runner VM
| Service | Status | Beschreibung |
|---------|--------|--------------|
| [github-runner](./services/github-runner/) | 🔄 | GitHub Actions Runner für CI/CD |

### Services VM
| Service | Status | Port | Beschreibung |
|---------|--------|------|--------------|
| [code-server](./services/code-server/) | ✅ | 8080 | VS Code im Browser |

## Struktur

```
.
├── .github/workflows/ # GitHub Actions Workflows
├── services/          # Alle Services mit Docker Compose
│   ├── github-runner/ # GitHub Runner (läuft auf Runner-VM)
│   └── code-server/   # VS Code (läuft auf Services-VM)
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

### Erste Schritte
- 📖 [Quick Start Guide](./docs/QUICKSTART.md) - Erste Schritte

### CI/CD Setup
- 🤖 [GitHub Runner Setup](./services/github-runner/README.md) - Self-hosted Runner für separate VM ⭐
- 🚀 [Deployment Optionen](./docs/DEPLOYMENT.md) - Alle CI/CD-Optionen im Vergleich
- 📝 [Self-hosted Runner Guide](./docs/SELFHOSTED-RUNNER.md) - Alternative: Runner direkt auf Services-VM

### Services
- 🔧 [Code-Server Guide](./services/code-server/README.md) - VS Code im Browser
