# Architettura dati – Scrittura e lettura

Riepilogo della gerarchia Firestore finale usata da FitAI Analyzer.

---

## 1. Collezioni Firestore (sotto `users/{uid}/`)

### 1.1 Strategia Tre Livelli

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Daily logs | `daily_logs/{date}` | `NutritionService`, `StravaService`, `garmin-sync-server` | `DailyLogModel`, `LongevityEngine`, `AggregationService`, `AiPromptService` |
| Meals | `daily_logs/{date}/meals/{mealId}` | `NutritionService` | `mealsForDayStream`, `NutritionService` |
| Rolling 10 days | `rolling_10days/current` | `AggregationService` | `Rolling10DaysModel`, `LongevityEngine`, `AiPromptService` |
| Baseline profile | `baseline_profile/main` | `AggregationService` | `BaselineProfileModel`, `LongevityEngine`, `AiPromptService` |

### 1.2 Collezioni operative aggiornate

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Daily health | `daily_health/{date}` | `garmin-sync-server` | `dailyHealthStreamProvider`, `LongevityEngine`, `GarminDailyStats`, `LongevityHeader`, `AggregationService` |
| Activities | `activities/{id}` | `garmin-sync-server`, `StravaService` | `activitiesStreamProvider`, `GarminService`, `DashboardScreen`, `LongevityEngine`, `AggregationService` |
| AI insights | `ai_insights/{date}` | FitAI | dedicato prompt/UI |

### 1.3 Profilo

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Profile | `profile/profile` | `UserProfileNotifier` | `userProfileStreamProvider`, `LongevityEngine` |

---

## 2. Struttura dei documenti chiave

### `daily_logs/{date}`

Documento indice giornaliero. Contiene:
- `date`, `timestamp`
- `activity_ids`: lista di document ID della collection `activities`
- `health_ref`: riferimento logico a `daily_health/{date}`
- `nutrition_summary`
- `nutrition_gemini` come fallback legacy
- `total_burned_kcal`
- `weight_kg`, `goal_today_ia`, `user_notes`

`daily_logs` non e piu la sorgente canonica delle attivita: serve come indice giornaliero per UI e AI.

### `activities/{id}`

Documento attivita unificato. Campi principali:
- `source`: `garmin`, `strava` o `dual`
- `date`, `startTime`, `dateKey`
- `activityType`, `activityName`
- `distanceKm`, `activeMinutes`, `elapsedMinutes`, `calories`
- `avgHeartrate`, `maxHeartrate`, `avgSpeedKmh`, `elevationGainM`
- `hasGarmin`, `hasStrava`
- `garminActivityId`, `stravaActivityId`
- `garmin_raw`, `strava_raw`

### `daily_health/{date}`

Biometrici Garmin del giorno:
- `stats`
- `sleep`
- `hrv`
- `body_battery`
- `max_metrics`
- `fitness_age`

---

## 3. Flussi di scrittura

### Nutrizione

```text
[Gemini analizza foto] -> NutritionService
    -> daily_logs/{date}/meals/{mealId}
    -> daily_logs/{date}.nutrition_summary
    -> AggregationService.updateRolling10DaysAndBaseline()
```

### Attivita Strava

```text
[Strava OAuth] -> StravaService
    -> users/{uid}/activities/{id}
    -> merge fuzzy con attivita Garmin compatibile (+/- 2 min)
    -> daily_logs/{date}.activity_ids
```

### Attivita Garmin + biometrici

```text
[garmin-sync-server]
    -> users/{uid}/daily_health/{date}
    -> users/{uid}/activities/{id}
    -> merge fuzzy con attivita Strava compatibile (+/- 2 min)
    -> daily_logs/{date}.activity_ids
    -> daily_logs/{date}.health_ref
```

---

## 4. Flussi di lettura

### UI Flutter

```text
activitiesStreamProvider -> users/{uid}/activities
dailyHealthStreamProvider -> users/{uid}/daily_health
activitiesByDateProvider -> grouping client-side di activities gia unificate
```

### Prompt AI

```text
LongevityEngine / AggregationService
    -> daily_logs per nutrizione, goal, note, peso
    -> activities per allenamenti
    -> daily_health per biometrici
    -> rolling_10days / baseline_profile per aggregati
```

---

## 5. File di riferimento

| File/Servizio | Legge | Scrive |
|---------------|-------|--------|
| `NutritionService` | meals, daily_logs | meals, nutrition_summary |
| `StravaService` | activities (match per slot) | activities, daily_logs.activity_ids |
| `garmin-sync-server/main.py` | activities (match per slot) | daily_health, activities, daily_logs.activity_ids, daily_logs.health_ref |
| `AggregationService` | daily_logs, activities, daily_health | rolling_10days, baseline_profile |
| `LongevityEngine` | daily_logs, activities, daily_health, rolling_10days, baseline_profile, profile | — |
| `GarminService` | activities | endpoint server |
| `data_sync_notifier` | activities, daily_health | — |

---

## 6. Regole Firestore

`firestore.rules` permette `read, write` su `users/{userId}/{document=**}` solo se `request.auth.uid == userId`.

Il `garmin-sync-server` usa Admin SDK e bypassa le regole utente.
