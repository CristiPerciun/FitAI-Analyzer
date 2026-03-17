# Flussi Garmin e AI - Riepilogo

> **Architettura dati completa**: vedi [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md) per scrittura/lettura di tutte le collezioni.

## Panoramica

| Flusso | Progetto | Comando Cursor | Stato |
|--------|----------|----------------|-------|
| Cattura biometrica | Sync Server | "Add get_sleep, get_hrv, get_stats to Garmin sync" | ✅ |
| Endpoint sync | Sync Server | "Create /sync-vitals endpoint for mobile trigger" | ✅ |
| Pull-to-refresh | FitAI App | "Implement RefreshIndicator calling /sync-vitals" | ✅ |
| Widget Home | FitAI App | "Add Garmin vitals block to Dashboard" | ✅ |
| AI Memory (2 mesi) | FitAI App | "Update AI context with 7 days detail + 8 weeks summary" | ✅ |

---

## 1. Cattura biometrica (garmin-sync-server)

- **API Garmin**: `get_stats`, `get_sleep_data`, `get_hrv_data`, `get_body_battery`, `get_max_metrics`, `get_fitnessage_data`
- **Destinazione**: `users/{uid}/daily_health/{date}`
- **Campi**: stats, sleep, hrv, body_battery, max_metrics (VO2Max), fitness_age
- **Indice**: il server aggiorna anche `daily_logs/{date}.health_ref`

## 1b. Cattura attivita unificate

- **API Garmin**: `get_activities(0, 20)`
- **Destinazione**: `users/{uid}/activities/{id}`
- **Merge**: lookup fuzzy su `startTime +/- 2 min` contro i documenti gia presenti per il giorno
- **Esito**: `source = garmin` se nuova attivita, `source = dual` se fusa con una attivita Strava gia salvata
- **Indice**: aggiornamento di `daily_logs/{date}.activity_ids`

---

## 2. Endpoint sync (`POST /garmin/sync-vitals`)

- **Scopo**: Refresh leggero per mobile (oggi + ieri)
- **Body**: `{ "uid": "..." }`
- **Chiamato da**: FitAI App al pull-to-refresh

---

## 3. Pull-to-refresh (FitAI App)

- **Dove**: HomeScreen, DashboardScreen
- **Azione**: `RefreshIndicator.onRefresh` → `GarminService.syncNow()` → `/garmin/sync-vitals`
- **Post-sync**: invalidazione `dailyHealthStreamProvider`, `activitiesStreamProvider`, `longevityHomePackageProvider`, ecc.

---

## 4. Widget Home (GarminDailyStats)

- **Posizione**: Home, sotto PillarGrid (obiettivi giornalieri)
- **Dati**: `dailyHealthStreamProvider` → Passi, Sonno, Body Battery da `daily_health`
- **Stile**: coerente con Longevity Path / Weekly Sprint

---

## 5. AI Memory – 2 mesi (LongevityEngine)

- **Struttura prompt Gemini**:
  1. Profilo utente (onboarding)
  2. Riassunto 2 mesi (medie settimanali: km, workouts, passi, sonno, VO2Max, Fitness Age)
  3. Dettaglio 7 giorni (`daily_logs` indice + `activities` + `daily_health`)
  4. Note e obiettivi (baseline)
- **Focus**: obiettivo principale utente (mainGoal)
- **File**: `lib/services/longevity_engine.dart` → `buildGeminiHomeContext`, `buildLongevityPlanPrompt`
