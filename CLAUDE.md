# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

FitAI Analyzer è un'app **Flutter** multipiattaforma (iOS, Android, Web/PWA, Windows, macOS) in lingua italiana per analisi fitness/nutrizione e "longevità". Trasforma dati di attività e biometrici (Garmin, Strava, Mi Fitness) e foto/testo dei pasti in obiettivi giornalieri generati da AI, organizzati attorno a 4 pilastri: **Cuore, Forza, Alimentazione, Recupero** (framework Peter Attia – *Outlive*: Zone 2, VO2Max, fitness age).

## Comandi di sviluppo

```bash
flutter pub get                 # installa dipendenze (richiede che .env esista, vedi sotto)
flutter run                     # avvia (aggiungi -d chrome | -d windows per la piattaforma)
flutter analyze                 # lint (flutter_lints, vedi analysis_options.yaml; **/*.g.dart esclusi)
dart format lib test            # formattazione
flutter test                    # tutti i test
flutter test test/garmin_service_test.dart                       # un singolo file di test
flutter test test/garmin_service_test.dart --plain-name "..."   # un singolo test per nome
```

**Code generation (json_serializable).** I file `*.g.dart` sono generati. Dopo aver modificato un modello con `@JsonSerializable`:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch     # rigenerazione automatica durante lo sviluppo
```

**Build (versione Flutter in CI: `3.41.4`, SDK Dart `^3.10.1`):**

```bash
flutter build ios --release --no-codesign                                       # IPA per sideload (Apple ID gratuito)
flutter build web --release --base-href "/FitAI-Analyzer/" --pwa-strategy=none  # PWA per GitHub Pages
flutter build apk                                                               # Android
dart run flutter_launcher_icons   # rigenera le icone da assets/branding/app_icon.png
```

CI in `.github/workflows/` (`build-ios.yml`, `build-web.yml`): push su `main` → build automatica; il deploy web pubblica su GitHub Pages.

## Il file `.env` (vincolo di build)

`.env` è dichiarato come **asset bundlato** in `pubspec.yaml`, quindi **deve esistere** al momento di `flutter pub get`/`flutter build`, altrimenti il bundling fallisce. È in `.gitignore` (non versionato); in CI viene creato da `secrets.GEMINI_API_KEY` **prima** di `pub get`. Variabili principali: `GEMINI_API_KEY`, `GARMIN_SERVER_URL_LAN` / `GARMIN_SERVER_URL_REMOTE`, `STRAVA_WEB_REDIRECT_URI`, `GARMIN_SERVER_BEARER_TOKEN` (opzionale), `FIREBASE_CREDENTIALS_B64`.

Regola correlata: `dotenv.load()` in `main.dart` deve stare in **try-catch**, e `GeminiApiKeyService` deve usare `dotenv.get('GEMINI_API_KEY', fallback: '')` per non crashare se `.env` manca (vedi `.cursor/rules/ios-build-ci.mdc`). Per `image_picker` servono `NSCameraUsageDescription` e `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist`.

## Architettura ad alto livello

### Clean Architecture / MVVM con Riverpod
Layer separati e vincolanti: `lib/ui/` (ConsumerWidget sottili) → `lib/providers/` (state: `Notifier`/`StateNotifier`/`StreamProvider`/`FutureProvider`) → `lib/services/` (logica di business) → `lib/models/` (modelli `@JsonSerializable` o factory `fromFirestore`). **Niente variabili globali**: tutta la DI passa da `lib/providers/providers.dart` (hub centrale). UI Material 3, grafici con `fl_chart`, navigazione con `go_router`.

### Avvio app e gating autenticazione
`main.dart` (init Firebase + dotenv + deep link OAuth) → `MyApp` (`app.dart`: lifecycle, resume OAuth web, listener errori/sync globali) → **`AuthGateway`** (`lib/ui/auth/auth_gateway.dart`), una macchina a stati con 4 "gate": sessione Firebase → verifica token → esistenza profilo → routing verso `LoginScreen`, `OnboardingScreen` o `MainShellScreen`. La shell è un `IndexedStack` a 4 tab: **Home, Dashboard/Allenamenti, Alimentazione, Impostazioni**.

### Sottosistema AI multi-backend
`UnifiedAiService` (`lib/services/unified_ai_service.dart`) instrada ogni chiamata con uno `switch` su `AiBackend` verso uno di tre backend intercambiabili: **Gemini** (SDK `google_generative_ai`, `gemini-2.5-flash`), **DeepSeek** (HTTP OpenAI-compatibile), **OpenRouter** (catena di modelli free con fallback). Il backend attivo è in `AiBackendPreferenceService` (secure storage, chiave `AI_ACTIVE_BACKEND`). Le chiavi Gemini sono **per-UID** (`GEMINI_API_KEY_UID::<uid>`) per evitare leak cross-account su dispositivi condivisi, sincronizzate su `users/{uid}/app_sync/ai_keys` da `UserAiSettingsSyncService`. `NutritionAiJsonParser` normalizza il JSON dell'AI (somma le macro dei singoli alimenti e **corregge il totale se diverge >10%**).

### Strategia "Tre Livelli di Memoria" (VINCOLANTE — non modificare)
È la spina dorsale dei dati, pensata per limitare il costo dei prompt AI. I livelli superiori leggono **solo i campi `*_summary`**, mai le sottocollezioni raw. Dettagli completi in `.cursor/rules/three-levels-memory-strategy.mdc` e `docs/DATA_ARCHITECTURE.md`.

- **Livello 1 — `users/{uid}/daily_logs/{YYYY-MM-DD}`**: documento indice giornaliero (`nutrition_summary`, `activity_ids`, `health_ref`, `total_burned_kcal`, completamento pilastri) + sottocollezione `meals/{mealId}`.
- **Livello 2 — `rolling_10days/current`**: ricalcolato **ogni giorno** (medie macro 10 gg, minuti Zone 2, VO2Max stimato).
- **Livello 3 — `profile/baseline`**: ricalcolato **ogni 10 giorni** (statistiche annuali, trend mensili, metriche Attia, `ai_ready_summary` di ~4000 caratteri).

`AggregationService.updateRolling10DaysAndBaseline()` calcola L2 e L3 da `daily_logs` + `activities` + `daily_health`. **Regola per nuovi dati**: aggiungi sempre un campo `*_summary` su `daily_logs` (e un getter unificato tipo `nutritionForAi`) così che L2/L3 non debbano mai leggere il dettaglio raw.

**Prompt AI unificato (`ai_current/`):** il bottone "Analisi" in Home attiva `LongevityEngine` (`lib/services/longevity_engine.dart`) che legge L1+L2+L3 + diary, costruisce un prompt unico (`buildUnifiedPromptFromContext`) e, dalla singola risposta Gemini, scrive in **una sola batch** (`saveUnifiedAiCurrent`): `ai_current/meal` (`NutritionMealPlanAi`), `ai_current/allenamenti` (`AiCurrentAllenamentiModel`), `ai_current/home_longevity_plan` (`HomeLongevityPlanDay`), più append su `profile/diary`.

### Sync fitness e server esterno
Il backend **garmin-sync-server** è un **repository separato** (Python/FastAPI su Raspberry Pi, branch di deploy `fork-sync`) — non è in questo repo. L'app comunica via HTTP e legge da Firestore. `GarminService` (URL con auto-detect LAN/REMOTE) e `StravaService` gestiscono gli OAuth (Garmin via ticket CAS; Strava via code exchange, con varianti web/desktop/mobile). `GarminSyncNotifier` orchestra i trigger di sync: **delta** al login, **sync-today** al pull-to-refresh.

**Confine di sicurezza chiave:** l'app **non tocca mai le credenziali delle sorgenti**. `garmin_tokens/{uid}` e `strava_tokens/{uid}` sono scritti **solo dal server** (Admin SDK) e negati al client in `firestore.rules`. L'app invia all'server i code/ticket OAuth e legge solo i dati unificati. Quando suggerisci deploy/debug Garmin, distingui sempre **client Flutter** (`.env`, `GarminService`) da **server Python** (repo `garmin-sync-server`, systemd sul Pi: `git push origin fork-sync` per aggiornarlo — un `git pull` locale non basta).

### Struttura Firestore — chi scrive dove
Tutto sotto `users/{uid}/`. Dettaglio in `.cursor/rules/firestore-collections-structure.mdc`.

| Collezione | Scrittore |
|-----------|-----------|
| `garmin_tokens`, `daily_health` | **Server** (Admin SDK) — client `read,write: if false` / path immutabile |
| `activities` | Server (Garmin) + FitAI (StravaService) — merge fuzzy ±2 min → `source: 'dual'` |
| `profile/profile` | `UserProfileNotifier` |
| `profile/baseline` | `AggregationService`, `NutritionCalculatorService` |
| `profile/diary`, `ai_current/*` | `LongevityEngine` |
| `rolling_10days/current` | `AggregationService` |
| `daily_logs` | FitAI (`NutritionService`) + Server |
| `daily_logs/.../meals` | `NutritionService` |
| `feedback/{messageId}` | `FeedbackService` (client) |

## Vincoli e insidie note

- **Workaround Firebase su Windows (pervasivo).** `AuthService` fa polling dell'auth ogni 5s invece di usare `authStateChanges` (bug flutterfire#11933, crash "non-platform-thread"); anche gli stream Firestore fanno polling su Windows; `clearPersistence()` **non** viene chiamato all'avvio (corromperebbe il client Windows). Diversi provider "optimistic" (es. `homeLongevityPlanOptimisticProvider`) esistono per mascherare la latenza del polling. È la principale fonte di complessità trasversale.
- **Serializzazione non uniforme.** `UserProfile`, `DailyLogModel`, `Rolling10DaysModel`, `BaselineProfileModel`, `FitnessData` usano `@JsonSerializable` (`.g.dart`); invece `MealModel`, `NutritionMealPlanAi`, `AiCurrentAllenamentiModel`, `HomeLongevityPlanDay`, `FeedbackMessage` usano factory `fromFirestore`/`fromUnifiedJson` scritte a mano (intenzionale per tollerare le varianti JSON dell'AI).
- **`NutritionGoal.proteinGPerKg`**: salvato come `int` ma interpretato "÷10 se ≥10", quindi sia `2` sia `20` significano 2.0 g/kg (artefatto di migrazione).
- **Nessun pinning di versione dei modelli AI**; il supporto vision di OpenRouter è segnalato come instabile nella catena di fallback.

## Checklist pre-flight (prima di modificare)

Questi controlli operazionalizzano le regole `.cursor/rules` (vincolanti, `alwaysApply: true`). Prima di un'azione che ricade in un trigger, verifica la voce corrispondente.

- **Scrivere/leggere su Firestore** → rispetta la matrice "chi scrive dove". Mai scrivere dal client su `daily_health`, `garmin_tokens`, `strava_tokens` (sono lato server, Admin SDK) né cambiarne i path. Mai far leggere a L2/L3 le sottocollezioni o i `daily_logs` raw: passa dai campi `*_summary`.
- **Aggiungere un nuovo tipo di dato** → (1) dettaglio in `daily_logs/{date}` (o `daily_health` se biometrico Garmin), (2) campo `*_summary` sul daily_log + getter unificato stile `nutritionForAi`, (3) aggrega in `_computeRolling10Days` (L2) e `_computeBaselineProfile` (L3).
- **Modificare un modello** → se `@JsonSerializable`, rigenera con `build_runner`; altrimenti mantieni il pattern `fromFirestore`/`fromUnifiedJson` esistente del modello (non mischiare i due approcci).
- **Aggiungere stato/logica** → stato in Riverpod (`Notifier`/`StreamProvider`) registrato in `providers.dart`; logica nei `services/`; UI sottile in `ui/`. Niente variabili globali.
- **Toccare `.env`, asset o CI** → `.env` creato prima di `pub get`, `dotenv.load()` in try-catch, `GeminiApiKeyService` con fallback (vedi `ios-build-ci.mdc`).
- **Chiamare l'AI** → sempre via `UnifiedAiService`; chiavi per-UID in secure storage; mai loggare le chiavi.
- **Garmin/sync** → distingui client Flutter (`.env`, `GarminService`) dal server Python (`garmin-sync-server`, repo separato; deploy via `git push origin fork-sync`).

## Documentazione e regole di progetto

Prima di modifiche rilevanti, consultare (regole `.cursor/rules/` con `alwaysApply: true`, vincolanti):
- `.cursor/rules/three-levels-memory-strategy.mdc` — strategia dati a tre livelli + prompt unificato `ai_current`.
- `.cursor/rules/firestore-collections-structure.mdc` — schema collezioni e matrice scrittori/lettori.
- `.cursor/rules/project-conventions.mdc` — Clean Architecture, Riverpod, Material 3, sicurezza.
- `.cursor/rules/ios-build-ci.mdc` — requisiti `.env`/CI per la build iOS.
- `.cursor/rules/garmin-server-pi-fork-sync.mdc` — separazione app vs server, branch `fork-sync`.
- `docs/DATA_ARCHITECTURE.md`, `docs/SYNC_ARCHITECTURE.md`, `docs/GARMIN_INTEGRATION.md`, `docs/FIREBASE_SETUP.md`, `docs/IOS_SETUP.md` — architettura dati, sync, integrazioni, setup.
- `AGENTS.md` impone la consultazione di queste regole prima di ogni prompt.

**File da cui orientarsi:** `lib/main.dart` (avvio), `lib/ui/auth/auth_gateway.dart` (gating), `lib/providers/providers.dart` (DI), `lib/services/longevity_engine.dart` (orchestrazione AI), `lib/services/aggregation_service.dart` (L2/L3), `lib/services/unified_ai_service.dart` (router AI), `lib/services/garmin_service.dart` (sync), `firestore.rules` (confine di sicurezza).
