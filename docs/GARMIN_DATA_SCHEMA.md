# Schema dati Garmin – API → Firebase

Studio dei dati che arrivano dalle chiamate Garmin al server e come salvarli in modo coerente su Firebase.

---

## 1. Dati in ingresso (API Garmin)

### 1.1 Attività – `get_activities(0, 20)`

L'endpoint restituisce una lista di attività in **camelCase**. Struttura tipica:

| Campo API | Tipo | Descrizione | Esempio |
|-----------|------|-------------|---------|
| `activityId` | int/string | ID univoco Garmin | `10472655210` |
| `activityName` | string | Nome attività | `"Morning Run"` |
| `startTimeGMT` | string | Inizio UTC (ISO 8601) | `"2024-03-16T07:30:00.0"` |
| `activityType` | object | `{typeId, typeKey, parentTypeId}` | `{"typeKey": "running"}` |
| `distance` | float | Distanza in **metri** | `5000.0` |
| `duration` | float | Durata in **secondi** | `1800.0` |
| `averageHR` | int | Frequenza cardiaca media | `145` |
| `calories` | int | Calorie attive (kcal) | `320` |
| `elevationGain` | float | Dislivello positivo (m) | `45.0` |

### 1.2 Biometrici – API usate dal server

| Metodo | Contenuto | Destinazione Firestore |
|--------|-----------|------------------------|
| `get_stats(date)` | Passi, calorie, riepilogo giornaliero | `daily_health/{date}.stats` |
| `get_sleep_data(date)` | Sonno (sleepScore, durata, fasi) | `daily_health/{date}.sleep` |
| `get_hrv_data(date)` | HRV | `daily_health/{date}.hrv` |
| `get_body_battery(date, date)` | Body Battery | `daily_health/{date}.body_battery` |
| `get_max_metrics(date)` | VO2Max, metriche massime | `daily_health/{date}.max_metrics` |
| `get_fitnessage_data(date)` | Fitness Age Garmin | `daily_health/{date}.fitness_age` |

---

## 2. Struttura Firebase

### 2.1 `users/{uid}/garmin_activities/{activityId}`

Attività raw con merge. Campi aggiunti dal server: `syncedAt`, `startTime`, `dateKey`, `activityTypeKey`, `source: "garmin"`.

### 2.2 `users/{uid}/daily_logs/{YYYY-MM-DD}` (campo `garmin_activities`)

Lista di attività Garmin in formato nativo + `source: "garmin"` per deduplicazione con Strava.

### 2.3 `users/{uid}/garmin_daily/{YYYY-MM-DD}`

`date`, `syncedAt`. Usato come marker di sync. I dati biometrici dettagliati sono in `daily_health`.

### 2.4 `users/{uid}/daily_health/{YYYY-MM-DD}`

**Scrittore**: garmin-sync-server. **Lettore**: FitAI App (LongevityHeader, GarminDailyStats, LongevityEngine).

| Campo | Tipo | Fonte API | Descrizione |
|-------|------|-----------|-------------|
| `date` | string | — | YYYY-MM-DD (anche come doc ID) |
| `syncedAt` | string | — | Timestamp sync |
| `stats` | object | get_stats | totalSteps, userSteps, bodyBatteryMostRecentValue, ecc. |
| `sleep` | object | get_sleep_data | sleepScore, overallSleepScore, sleepTimeSeconds, ecc. |
| `hrv` | object | get_hrv_data | Dati HRV |
| `body_battery` | array/object | get_body_battery | Valori Body Battery |
| `max_metrics` | object | get_max_metrics | vo2Max, maxVo2, ecc. |
| `fitness_age` | object | get_fitnessage_data | fitnessAge, age |

---

## 3. Flusso scrittura (garmin-sync-server)

```
[Garmin API]
    ↓
get_activities(0, 20)  →  garmin_activities/{id}, daily_logs/{date}.garmin_activities
get_stats(date)        →  daily_health/{date}.stats
get_sleep_data(date)   →  daily_health/{date}.sleep
get_hrv_data(date)    →  daily_health/{date}.hrv
get_body_battery(...)  →  daily_health/{date}.body_battery
get_max_metrics(date)  →  daily_health/{date}.max_metrics
get_fitnessage_data()  →  daily_health/{date}.fitness_age
    ↓
[Firestore] users/{uid}/...
```

**Endpoint**:
- `POST /garmin/sync` – sync completa (attività + 14 giorni daily_health)
- `POST /garmin/sync-vitals` – solo oggi e ieri (pull-to-refresh mobile)

---

## 4. Flusso lettura (FitAI App)

| Dato | Provider/Service | Collezione |
|------|------------------|------------|
| Attività Garmin | `garminActivitiesStreamProvider` | `garmin_activities` |
| Dati giornalieri | `garminDailyProvider(date)` | `garmin_daily` |
| Biometrici (passi, sonno, BB) | `dailyHealthStreamProvider` | `daily_health` |
| Per prompt AI (7 gg + 8 sett) | `LongevityEngine.buildGeminiHomeContext` | `daily_health` + `daily_logs` |

---

## 5. Compatibilità e unità

- **Distanza**: metri (API e Firestore)
- **Durata**: secondi
- **Calorie**: kcal
- **Timestamp**: stringa ISO o Firestore Timestamp
