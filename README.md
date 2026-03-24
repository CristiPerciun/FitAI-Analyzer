# FitAI Analyzer

App Flutter per analisi fitness e longevità: integrazione Strava, Garmin, nutrizione (Gemini) e piano AI personalizzato.

## Architettura dati

- **Firebase**: Firestore + Auth
- **Strategia Tre Livelli**: daily_logs (dettaglio) → rolling_10days (trend) → baseline_profile (annuale)
- **Collezioni aggiornate**: `daily_health` (Garmin biometrici), `activities`, `ai_insights`

## Documentazione

Vedi [docs/README.md](docs/README.md) per l'indice completo.

| Documento | Contenuto |
|-----------|-----------|
| [docs/DATA_ARCHITECTURE.md](docs/DATA_ARCHITECTURE.md) | Scrittura/lettura dati Firestore |
| [docs/SYNC_ARCHITECTURE.md](docs/SYNC_ARCHITECTURE.md) | Sync unificata (Garmin + Strava, app + server) |
| [docs/GARMIN_INTEGRATION.md](docs/GARMIN_INTEGRATION.md) | Garmin: rete, API, endpoint, Firestore |
| [docs/FLUSSI_GARMIN_AI.md](docs/FLUSSI_GARMIN_AI.md) | UI vitals, contesto AI, troubleshooting |
| [.cursor/rules/three-levels-memory-strategy.mdc](.cursor/rules/three-levels-memory-strategy.mdc) | Strategia Tre Livelli |
| [.cursor/rules/firestore-collections-structure.mdc](.cursor/rules/firestore-collections-structure.mdc) | Collezioni daily_health, activities, longevity_diary |

## Setup

1. **Firebase** (auth, chiavi, deploy regole): [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)
2. **Sync** (Garmin + Strava): [docs/SYNC_ARCHITECTURE.md](docs/SYNC_ARCHITECTURE.md) e [docs/GARMIN_INTEGRATION.md](docs/GARMIN_INTEGRATION.md)
3. **iOS**: [docs/IOS_SETUP.md](docs/IOS_SETUP.md)

## Getting Started

```bash
flutter pub get
flutter run
```

Per la chiave Gemini: vedi [TODO-SECURE-API-KEY.md](TODO-SECURE-API-KEY.md).
