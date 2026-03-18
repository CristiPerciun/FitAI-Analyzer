# Integrazione Garmin Sync Server

FitAI Analyzer legge i dati Garmin da Firestore scritti dal **garmin-sync-server** (Python, deploy su Render).

> **Architettura dati completa**: [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md)  
> **Flussi Garmin e AI**: [FLUSSI_GARMIN_AI.md](FLUSSI_GARMIN_AI.md)

---

## 1. Architettura

```
[Garmin Connect] → [garmin-sync-server su Render] → [Firestore]
                                                          ↓
                                              [FitAI Analyzer Flutter]
```

- **Server**: [github.com/CristiPerciun/garmin-sync-server](https://github.com/CristiPerciun/garmin-sync-server)
- **Deploy**: Render (vedi `RENDER_DEPLOY.md` nel repo garmin-sync-server)

---

## 2. Collezioni Firestore

| Collezione | Percorso | Scrittore | Contenuto |
|------------|----------|-----------|-----------|
| Attività | `users/{uid}/activities/{id}` | Server + StravaService | Attività unificate Garmin/Strava con merge fuzzy e `source: garmin/strava/dual` |
| Daily log | `users/{uid}/daily_logs/{date}` | Server + StravaService + NutritionService | Indice giornaliero con `activity_ids`, `health_ref`, nutrizione e metadati |
| Daily health | `users/{uid}/daily_health/{date}` | Server | Passi, sonno, HRV, Body Battery, VO2Max, Fitness Age |

---

## 3. Schema API Garmin → Firestore

### 3.1 Attività – `get_activities(0, 20)`

| Campo API | Tipo | Descrizione | Esempio |
|-----------|------|-------------|---------|
| `activityId` | int/string | ID univoco Garmin | `10472655210` |
| `activityName` | string | Nome attivita | `"Morning Run"` |
| `startTimeGMT` | string | Inizio UTC (ISO 8601) | `"2024-03-16T07:30:00.0"` |
| `activityType` | object | `{typeId, typeKey, parentTypeId}` | `{"typeKey": "running"}` |
| `distance` | float | Distanza in metri | `5000.0` |
| `duration` | float | Durata in secondi | `1800.0` |
| `averageHR` | int | Frequenza cardiaca media | `145` |
| `maxHR` | int | Frequenza cardiaca massima | `171` |
| `calories` | int | Calorie attive (kcal) | `320` |
| `elevationGain` | float | Dislivello positivo (m) | `45.0` |

### 3.2 Biometrici – API usate dal server

| Metodo | Contenuto | Destinazione Firestore |
|--------|-----------|------------------------|
| `get_stats(date)` | Passi, riepilogo giornaliero | `daily_health/{date}.stats` |
| `get_sleep_data(date)` | Sonno (sleepScore, durata, fasi) | `daily_health/{date}.sleep` |
| `get_hrv_data(date)` | HRV | `daily_health/{date}.hrv` |
| `get_body_battery(date, date)` | Body Battery | `daily_health/{date}.body_battery` |
| `get_max_metrics(date)` | VO2Max, metriche massime | `daily_health/{date}.max_metrics` |
| `get_fitnessage_data(date)` | Fitness Age Garmin | `daily_health/{date}.fitness_age` |

### 3.3 Struttura Firestore `activities/{id}`

| Campo | Tipo | Descrizione |
|-------|------|-------------|
| `source` | string | `garmin`, `strava`, `dual` |
| `date`, `startTime`, `dateKey` | — | Identificazione temporale |
| `activityType`, `activityName` | string | Tipo e nome |
| `distanceKm`, `activeMinutes`, `elapsedMinutes`, `calories` | num | Metriche |
| `avgHeartrate`, `maxHeartrate`, `elevationGainM` | num | HR e dislivello |
| `garmin_raw`, `strava_raw` | object | Dati raw |

**Merge**: lookup per `dateKey` + match fuzzy su `startTime +/- 2 min`; se esiste già → `source: "dual"`.

### 3.4 Struttura Firestore `daily_health/{date}`

| Campo | Fonte API | Descrizione |
|-------|-----------|-------------|
| `stats` | `get_stats` | totalSteps, userSteps, bodyBatteryMostRecentValue |
| `sleep` | `get_sleep_data` | sleepScore, overallSleepScore, sleepTimeSeconds |
| `hrv` | `get_hrv_data` | Dati HRV |
| `body_battery` | `get_body_battery` | Valori Body Battery |
| `max_metrics` | `get_max_metrics` | vo2Max, maxVo2 |
| `fitness_age` | `get_fitnessage_data` | fitnessAge, age |

### 3.5 Unità e compatibilità

- `distance` Garmin raw resta in metri → `distanceKm` in Firestore in chilometri
- `duration` Garmin raw in secondi → `activeMinutes`/`elapsedMinutes` in minuti
- `calories` in kcal

---

## 4. Endpoint server

| Endpoint | Body | Scopo |
|----------|------|-------|
| `POST /garmin/connect` | `{ uid, email, password }` | Login Garmin + sync iniziale |
| `POST /garmin/sync` | `{ uid }` | Sync completa (attività + 14 giorni biometrici) |
| `POST /garmin/sync-vitals` | `{ uid }` | Sync leggera: solo oggi e ieri (pull-to-refresh) |
| `POST /garmin/disconnect` | `{ uid }` | Scollega account: elimina token, imposta garmin_linked=false |

---

## 5. Lettura nell'app Flutter

| File | Collezione | Uso |
|------|------------|-----|
| `GarminService.activitiesStream` | `activities` | Dashboard allenamenti |
| `dailyHealthStreamProvider` | `daily_health` | LongevityHeader, GarminDailyStats |
| `LongevityEngine.buildGeminiHomeContext` | `daily_health` + `activities` + `daily_logs` | Prompt AI (7 giorni + 8 settimane) |

---

## 6. Setup garmin-sync-server

**IMPORTANTE**: Il server usa il `uid` passato nel body delle richieste (non `USER_ID` da env). L'UID deve corrispondere all'**UID Firebase** dell'utente.

1. L'app invia `uid` (Firebase Auth) al login e al sync
2. Il server scrive in `users/{uid}/activities`, `users/{uid}/daily_health` e aggiorna `daily_logs/{date}`
3. Le credenziali Firebase sono in `FIREBASE_CREDENTIALS` o `FIREBASE_CREDENTIALS_B64`
