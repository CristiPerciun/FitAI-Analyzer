# Documentazione FitAI Analyzer

Indice della documentazione tecnica.

---

## Architettura dati

| Documento | Contenuto |
|-----------|-----------|
| [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md) | **Fonte principale** – collezioni Firestore, chi scrive/legge |
| [.cursor/rules/three-levels-memory-strategy.mdc](../.cursor/rules/three-levels-memory-strategy.mdc) | Strategia Tre Livelli |
| [.cursor/rules/firestore-collections-structure.mdc](../.cursor/rules/firestore-collections-structure.mdc) | `daily_health`, `activities`, `longevity_diary`, … |

---

## Sync e integrazioni

| Documento | Contenuto |
|-----------|-----------|
| [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md) | Sync unificata app + **garmin-sync-server** (Garmin, Strava, endpoint, Firestore, OAuth Strava §8) |
| [GARMIN_INTEGRATION.md](GARMIN_INTEGRATION.md) | Connettività (LAN/remoto), schema API Garmin → Firestore, endpoint, setup server |
| [FLUSSI_GARMIN_AI.md](FLUSSI_GARMIN_AI.md) | Widget Home, contesto AI, troubleshooting |

---

## Firebase e deploy

| Documento | Contenuto |
|-----------|-----------|
| [FIREBASE_SETUP.md](FIREBASE_SETUP.md) | Auth Email/Password, allineamento chiavi app/server/Garmin, deploy regole Firestore |
| [firestore.rules.example](firestore.rules.example) | Esempio regole (riferimento) |

---

## Build e piattaforme

| Documento | Contenuto |
|-----------|-----------|
| [IOS_SETUP.md](IOS_SETUP.md) | iPhone: Strava deep link, Firebase, build/sideload |
| [../GITHUB_IOS_BUILD.md](../GITHUB_IOS_BUILD.md) | CI GitHub Actions per iOS |
