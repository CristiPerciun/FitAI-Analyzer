# Documentazione FitAI Analyzer

Indice della documentazione tecnica, organizzata per tema.

---

## Architettura

| Documento | Contenuto |
|-----------|-----------|
| [architecture/data-architecture.md](architecture/data-architecture.md) | **Fonte principale** – collezioni Firestore, chi scrive/legge |
| [architecture/sync-architecture.md](architecture/sync-architecture.md) | Sync unificata app + **garmin-sync-server** (Garmin, Strava, endpoint, Firestore, OAuth Strava §8) |
| [../.cursor/rules/three-levels-memory-strategy.mdc](../.cursor/rules/three-levels-memory-strategy.mdc) | Strategia Tre Livelli (vincolante) |
| [../.cursor/rules/firestore-collections-structure.mdc](../.cursor/rules/firestore-collections-structure.mdc) | `daily_health`, `activities`, `ai_current`, … |

## Integrazioni

| Documento | Contenuto |
|-----------|-----------|
| [integrations/garmin.md](integrations/garmin.md) | Connettività (LAN/remoto), schema API Garmin → Firestore, endpoint, setup server |
| [integrations/garmin-ai-flows.md](integrations/garmin-ai-flows.md) | Widget Home, contesto AI, troubleshooting |

## Setup

| Documento | Contenuto |
|-----------|-----------|
| [setup/firebase.md](setup/firebase.md) | Auth Email/Password, allineamento chiavi app/server/Garmin, deploy regole Firestore |
| [setup/ios.md](setup/ios.md) | iPhone: Strava deep link, Firebase, build/sideload |
| [setup/ios-github-build.md](setup/ios-github-build.md) | CI GitHub Actions per iOS (build + Sideloadly) |

## Sicurezza

| Documento | Contenuto |
|-----------|-----------|
| [security/gemini-api-key.md](security/gemini-api-key.md) | Chiave API Gemini: fonti, inserimento in-app, CI, rotazione |

## Reference

| Documento | Contenuto |
|-----------|-----------|
| [reference/firestore.rules.example](reference/firestore.rules.example) | Esempio regole Firestore (riferimento) |
