# FitAI Analyzer - Istruzioni per gli agenti

**Ogni agente Cursor deve rispettare queste regole PRIMA di eseguire qualsiasi prompt.**

Consulta `.cursor/rules/project-conventions.mdc` per i dettagli completi.

## Riepilogo vincolante

- **Architettura Clean**: layer separati (UI, providers, services, models, utils), MVVM con Riverpod
- **State**: solo Riverpod, niente globali, DI via provider
- **DB**: Firebase (Firestore + Auth)
- **UI**: Material 3, responsive, fl_chart, go_router
- **Sicurezza**: secure storage per API keys, try-catch, debounce
- **Deploy**: Flutter build Android/iOS
