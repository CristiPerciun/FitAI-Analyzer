# FitAI Analyzer - Istruzioni per gli agenti

**Ogni agente Cursor deve rispettare queste regole PRIMA di eseguire qualsiasi prompt.**

Consulta `.cursor/rules/project-conventions.mdc` per i dettagli completi.
Consulta `.cursor/rules/ios-build-ci.mdc` per requisiti build iOS e CI (.env, workflow).
Consulta `.cursor/rules/three-levels-memory-strategy.mdc` per la strategia a Tre Livelli di Memoria (architettura dati Firestore).
Consulta `.cursor/rules/firestore-collections-structure.mdc` per la struttura aggiornata: `daily_health`, `activities`, `ai_insights`.
Consulta `docs/FLUSSI_GARMIN_AI.md` per il riepilogo dei flussi Garmin e AI.
Consulta `docs/DATA_ARCHITECTURE.md` per scrittura/lettura dati Firestore.

## Riepilogo vincolante

- **Architettura Clean**: layer separati (UI, providers, services, models, utils), MVVM con Riverpod
- **State**: solo Riverpod, niente globali, DI via provider
- **DB**: Firebase (Firestore + Auth)
- **Strategia Tre Livelli**: Livello 1 (dettaglio daily_logs/meals), Livello 2 (rolling_10days), Livello 3 (baseline_profile). Non modificare; nuovi dati devono integrarsi seguendo questa logica
- **Collezioni aggiornate**: `daily_health` (Server), `activities` (Server+FitAI), `ai_insights` (FitAI) – vedi firestore-collections-structure.mdc
- **Indice daily_logs**: usare `activity_ids` e `health_ref`; non salvare nuove attività raw embedded in `daily_logs`
- **UI**: Material 3, responsive, fl_chart, go_router
- **Sicurezza**: secure storage per API keys, try-catch, debounce
- **Deploy**: Flutter build Android/iOS
- **Build iOS CI**: workflow deve creare `.env` prima di pub get; dotenv in try-catch; GeminiApiKeyService con fallback (vedi ios-build-ci.mdc)
