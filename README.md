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
| [docs/GARMIN_INTEGRATION.md](docs/GARMIN_INTEGRATION.md) | Integrazione Garmin (server, schema API→Firestore) |
| [docs/FLUSSI_GARMIN_AI.md](docs/FLUSSI_GARMIN_AI.md) | Flussi Garmin e AI |
| [.cursor/rules/three-levels-memory-strategy.mdc](.cursor/rules/three-levels-memory-strategy.mdc) | Strategia Tre Livelli |
| [.cursor/rules/firestore-collections-structure.mdc](.cursor/rules/firestore-collections-structure.mdc) | Collezioni daily_health, activities, longevity_diary |

## Setup

1. **Firebase**: [docs/FIREBASE_AUTH_SETUP.md](docs/FIREBASE_AUTH_SETUP.md)
2. **Strava**: [docs/STRAVA_SETUP.md](docs/STRAVA_SETUP.md)
3. **Garmin**: [docs/GARMIN_INTEGRATION.md](docs/GARMIN_INTEGRATION.md)
4. **iOS**: [docs/IOS_SETUP.md](docs/IOS_SETUP.md)
5. **Deploy Firestore**: [docs/FIREBASE_DEPLOY.md](docs/FIREBASE_DEPLOY.md)

## Getting Started

```bash
flutter pub get
flutter run
```

Per la chiave Gemini: vedi [TODO-SECURE-API-KEY.md](TODO-SECURE-API-KEY.md).
