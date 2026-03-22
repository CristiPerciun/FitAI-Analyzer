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

**Perché “non tutti” i dati dopo la sync dall’app:** `sync-vitals` è volutamente **leggera**: circa **2 giorni** di `daily_health` e fino a **50 attività** recenti (vedi `main.py` → `_sync_vitals_for_client`). Lo **scheduler** sul Pi (ogni ~45 min) chiama `sync_user` e allinea **14 giorni** di biometrici + fino a 50 attività in quel batch. L’app **non** chiama `POST /garmin/sync` (full) al tap: per storico lungo conta il job sul server o una chiamata manuale a quell’endpoint.

**Timeout:** il client Flutter usa **~180s** per `sync-vitals` (rete lenta o molte attività). Se scade prima, il Pi può comunque completare in background: controlla Firebase o `journalctl -u garmin-sync`.

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

---

## 6. Troubleshooting (Windows + Raspberry)

### Log Flutter: `firebase_auth_plugin/auth-state` o `id-token` su **non-platform thread**

**Non c’entra con la sync Garmin** (quella passa da HTTP al Pi + Firestore). Su **Windows desktop** è un limite noto del plugin `firebase_auth`: messaggi nativi sul canale da un thread sbagliato. In progetto: polling per `authStateChanges`, frame differito per login, `getIdToken(false)` dopo login su Windows. Può restare rumore se SDK/`cloud_firestore` aggiornano il token in background — [flutterfire#11933](https://github.com/firebase/flutterfire/issues/11933). Per log puliti usa **Android/iOS**.

### Server: `SSLCertVerificationError` / `self-signed certificate` verso `sso.garmin.com`

Il **garmin-sync-server** sul Pi chiama Garmin in HTTPS. Se nei log compare questo errore, il TLS è interrotto da una rete che presenta un certificato **non firmato da una CA di sistema** sul Pi (proxy aziendale, antivirus, captive portal, ecc.). **Non** è un problema delle credenziali Firebase (lo script `verify_firebase_credentials.py` può essere OK). Soluzioni: uscita Internet dal Pi senza SSL inspection (es. hotspot), oppure installare sul Pi il certificato root della CA della rete. Dettagli: `garmin-sync-server/RPI_DEPLOY.md` (sezione SSL Garmin).

### Server: storici `403` / `504` Firestore su `connect_garmin`

Se compaiono solo orari vecchi nel `garmin_comms.log` e poi `verify_firebase_credentials` è `[OK]`, erano problemi IAM/rete **prima** della correzione. Se persistono dopo `[OK]`, controlla IAM del service account e timeout rete Pi→Google.
