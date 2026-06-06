# FitAI Analyzer

App Flutter per analisi fitness e longevità: integrazione Strava, Garmin, nutrizione (Gemini) e piano AI personalizzato.

## Architettura dati

- **Firebase**: Firestore + Auth
- **Strategia Tre Livelli**: daily_logs (dettaglio) → rolling_10days (trend) → baseline_profile (annuale)
- **Collezioni aggiornate**: `daily_health` (Garmin biometrici), `activities`, `ai_current`

## Documentazione

Vedi [docs/README.md](docs/README.md) per l'indice completo.

| Documento | Contenuto |
|-----------|-----------|
| [docs/architecture/data-architecture.md](docs/architecture/data-architecture.md) | Scrittura/lettura dati Firestore |
| [docs/architecture/sync-architecture.md](docs/architecture/sync-architecture.md) | Sync unificata (Garmin + Strava, app + server) |
| [docs/integrations/garmin.md](docs/integrations/garmin.md) | Garmin: rete, API, endpoint, Firestore |
| [docs/integrations/garmin-ai-flows.md](docs/integrations/garmin-ai-flows.md) | UI vitals, contesto AI, troubleshooting |

## Setup

1. **Firebase** (auth, chiavi, deploy regole): [docs/setup/firebase.md](docs/setup/firebase.md)
2. **Sync** (Garmin + Strava): [docs/architecture/sync-architecture.md](docs/architecture/sync-architecture.md) e [docs/integrations/garmin.md](docs/integrations/garmin.md)
3. **iOS**: [docs/setup/ios.md](docs/setup/ios.md)

## Getting Started

```bash
flutter pub get
flutter run
```

Per la chiave Gemini: vedi [docs/security/gemini-api-key.md](docs/security/gemini-api-key.md).
