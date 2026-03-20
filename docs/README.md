# Documentazione FitAI Analyzer

Indice della documentazione tecnica del progetto.

---

## Architettura dati

| Documento | Contenuto |
|-----------|-----------|
| [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md) | **Fonte principale** – Collezioni Firestore, scrittori/lettori, flussi di scrittura e lettura |
| [.cursor/rules/three-levels-memory-strategy.mdc](../.cursor/rules/three-levels-memory-strategy.mdc) | Strategia Tre Livelli (daily_logs, rolling_10days, baseline_profile) |
| [.cursor/rules/firestore-collections-structure.mdc](../.cursor/rules/firestore-collections-structure.mdc) | Struttura collezioni operative (daily_health, activities, longevity_diary) |

---

## Integrazioni

| Documento | Contenuto |
|-----------|-----------|
| [GARMIN_INTEGRATION.md](GARMIN_INTEGRATION.md) | Integrazione Garmin: server, endpoint, schema API→Firestore, setup |
| [FLUSSI_GARMIN_AI.md](FLUSSI_GARMIN_AI.md) | Flussi Garmin e AI: sync, pull-to-refresh, prompt Gemini |
| [STRAVA_SETUP.md](STRAVA_SETUP.md) | Setup OAuth Strava |

---

## Firebase e deploy

| Documento | Contenuto |
|-----------|-----------|
| [FIREBASE_CLIENT_SYNC.md](FIREBASE_CLIENT_SYNC.md) | Dopo un nuovo `google-services.json` / progetto: allineare app, `firebase_options`, server Garmin |
| [FIREBASE_AUTH_SETUP.md](FIREBASE_AUTH_SETUP.md) | Configurazione Firebase Auth (Email/Password) |
| [FIREBASE_DEPLOY.md](FIREBASE_DEPLOY.md) | Deploy regole Firestore |

---

## Build e setup

| Documento | Contenuto |
|-----------|-----------|
| [IOS_SETUP.md](IOS_SETUP.md) | Setup iOS, Strava, Firebase |
| [../GITHUB_IOS_BUILD.md](../GITHUB_IOS_BUILD.md) | Build iOS in CI (GitHub Actions) |
