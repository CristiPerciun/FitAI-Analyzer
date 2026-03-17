# Schema dati Garmin – API -> Firestore unificato

Mappa tra i dati ricevuti dalle API Garmin e la gerarchia Firestore finale usata dal progetto.

---

## 1. Dati in ingresso (API Garmin)

### 1.1 Attivita – `get_activities(0, 20)`

L'endpoint restituisce una lista di attivita in camelCase. Campi piu utili:

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

### 1.2 Biometrici – API usate dal server

| Metodo | Contenuto | Destinazione Firestore |
|--------|-----------|------------------------|
| `get_stats(date)` | Passi, riepilogo giornaliero | `daily_health/{date}.stats` |
| `get_sleep_data(date)` | Sonno (sleepScore, durata, fasi) | `daily_health/{date}.sleep` |
| `get_hrv_data(date)` | HRV | `daily_health/{date}.hrv` |
| `get_body_battery(date, date)` | Body Battery | `daily_health/{date}.body_battery` |
| `get_max_metrics(date)` | VO2Max, metriche massime | `daily_health/{date}.max_metrics` |
| `get_fitnessage_data(date)` | Fitness Age Garmin | `daily_health/{date}.fitness_age` |

---

## 2. Struttura Firestore finale

### 2.1 `users/{uid}/activities/{id}`

Collezione canonica per le attivita.

Campi scritti dal server Garmin:
- `source: "garmin"` oppure `source: "dual"` se viene trovato uno slot gia occupato da Strava
- `date`, `startTime`, `dateKey`
- `activityType`, `activityName`
- `distanceKm`, `activeMinutes`, `elapsedMinutes`, `calories`
- `avgHeartrate`, `maxHeartrate`, `elevationGainM`
- `hasGarmin`, `hasStrava`
- `garminActivityId`, `stravaActivityId`
- `garmin_raw`, `strava_raw`, `raw`

Regola di merge:
- lookup per `dateKey`
- match fuzzy su `startTime +/- 2 min`
- se il match esiste, il server mantiene il doc ID esistente e imposta `source: "dual"`

### 2.2 `users/{uid}/daily_logs/{YYYY-MM-DD}`

Documento indice giornaliero aggiornato dal server Garmin:
- `date`
- `activity_ids`
- `health_ref`
- `total_burned_kcal`
- `timestamp`

Il server non scrive piu `garmin_activities` o `garmin_daily`.

### 2.3 `users/{uid}/daily_health/{YYYY-MM-DD}`

Scrittore: `garmin-sync-server`.

| Campo | Tipo | Fonte API | Descrizione |
|-------|------|-----------|-------------|
| `date` | string | — | YYYY-MM-DD |
| `syncedAt` | string/timestamp | — | Timestamp sync |
| `stats` | object | `get_stats` | totalSteps, userSteps, bodyBatteryMostRecentValue, ecc. |
| `sleep` | object | `get_sleep_data` | sleepScore, overallSleepScore, sleepTimeSeconds, ecc. |
| `hrv` | object | `get_hrv_data` | Dati HRV |
| `body_battery` | array/object | `get_body_battery` | Valori Body Battery |
| `max_metrics` | object | `get_max_metrics` | vo2Max, maxVo2, ecc. |
| `fitness_age` | object | `get_fitnessage_data` | fitnessAge, age |

---

## 3. Flusso di scrittura del server

```text
[Garmin API]
    -> get_activities(0, 20)
        -> activities/{id}
        -> daily_logs/{date}.activity_ids
    -> get_stats / get_sleep_data / get_hrv_data / get_body_battery / get_max_metrics / get_fitnessage_data
        -> daily_health/{date}
        -> daily_logs/{date}.health_ref
```

Endpoint:
- `POST /garmin/connect` -> login Garmin + sync iniziale
- `POST /garmin/sync` -> sync completa (attivita + ultimi 14 giorni di `daily_health`)
- `POST /garmin/sync-vitals` -> sync leggera (oggi + ieri) solo biometrici

---

## 4. Flusso di lettura nell'app Flutter

| Dato | Provider/Service | Collezione |
|------|------------------|------------|
| Attivita unificate | `activitiesStreamProvider`, `GarminService.activitiesStream` | `activities` |
| Biometrici Garmin | `dailyHealthStreamProvider` | `daily_health` |
| Prompt AI e aggregazioni | `LongevityEngine`, `AggregationService` | `activities` + `daily_health` + `daily_logs` |

---

## 5. Unita e compatibilita

- `distance` Garmin raw resta in metri
- `distanceKm` nel documento unificato e in chilometri
- `duration` Garmin raw resta in secondi
- `activeMinutes` / `elapsedMinutes` nel documento unificato sono in minuti
- `calories` e in kcal
- `date` e `startTime` possono essere Firestore Timestamp
