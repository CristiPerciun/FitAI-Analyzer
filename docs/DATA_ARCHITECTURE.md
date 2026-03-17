# Architettura dati – Scrittura e lettura

Riepilogo di dove vengono scritti e letti i dati in FitAI Analyzer.

---

## 1. Collezioni Firestore (sotto `users/{uid}/`)

### 1.1 Strategia Tre Livelli (nutrizione)

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Daily logs | `daily_logs/{date}` | StravaService, NutritionService, garmin-sync-server | `DailyLogModel`, `LongevityEngine`, `AggregationService` |
| Meals | `daily_logs/{date}/meals/{mealId}` | NutritionService | `mealsForDayStream`, `NutritionService` |
| Rolling 10 days | `rolling_10days/current` | AggregationService | `Rolling10DaysModel`, `LongevityEngine` |
| Baseline profile | `baseline_profile/main` | AggregationService | `BaselineProfileModel`, `LongevityEngine` |

### 1.2 Collezioni aggiornate (daily_health, activities, ai_insights)

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Daily health | `daily_health/{date}` | garmin-sync-server | `dailyHealthStreamProvider`, `LongevityEngine`, `GarminDailyStats`, `LongevityHeader` |
| Activities | `activities/{id}` | (futuro) Server + FitAI | — |
| AI insights | `ai_insights/{date}` | (futuro) FitAI | — |

### 1.3 Garmin

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Garmin activities | `garmin_activities/{activityId}` | garmin-sync-server | `garminActivitiesStreamProvider`, `GarminService` |
| Garmin daily | `garmin_daily/{date}` | garmin-sync-server | `garminDailyProvider` |

### 1.4 Strava / Health

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Health data | `health_data` | StravaService | `healthDataStreamProvider` |

### 1.5 Profilo

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Profile | `profile/profile` | UserProfileNotifier | `userProfileStreamProvider` |

---

## 2. Flusso scrittura per tipo di dato

### Nutrizione (foto piatto → Gemini)

```
[Gemini analizza foto] → NutritionService
    → meals/{mealId} (Livello 1)
    → daily_logs/{date}.nutrition_summary (sintesi)
    → AggregationService.updateRolling10DaysAndBaseline()
        → rolling_10days/current
        → baseline_profile/main (ogni 10 giorni)
```

### Attività Strava

```
[Strava OAuth] → StravaService
    → health_data
    → daily_logs/{date}.strava_activities
    → AggregationService
```

### Attività Garmin + biometrici

```
[garmin-sync-server]
    → garmin_activities/{id}
    → daily_logs/{date}.garmin_activities
    → garmin_daily/{date}
    → daily_health/{date} (stats, sleep, hrv, body_battery, max_metrics, fitness_age)
```

### Prompt AI (LongevityEngine)

```
[buildGeminiHomeContext]
    Lettura: profile, daily_logs (7 gg + 2 mesi), daily_health (7 gg + 2 mesi), baseline_profile
    → Costruzione prompt per Gemini
    → buildLongevityPlanPrompt
```

---

## 3. File di riferimento per lettura/scrittura

| Servizio | Lettura | Scrittura |
|----------|---------|-----------|
| `NutritionService` | meals, daily_logs | meals, nutrition_summary |
| `StravaService` | — | health_data, strava_activities |
| `AggregationService` | daily_logs | rolling_10days, baseline_profile |
| `LongevityEngine` | daily_logs, daily_health, rolling_10days, baseline_profile, profile | — |
| `GarminService` | garmin_activities, garmin_daily | — |
| `data_sync_notifier` | health_data, daily_health, garmin_activities | — |

---

## 4. Regole Firestore

Le regole in `firestore.rules` permettono: `read, write` su `users/{userId}/{document=**}` solo se `request.auth.uid == userId`.

Il garmin-sync-server usa **Admin SDK** (credenziali di servizio) e bypassa le regole utente.
