# Architettura dati – Scrittura e lettura

Riepilogo della gerarchia Firestore finale usata da FitAI Analyzer.

---

## 1. Struttura Firestore (sotto `users/{uid}/`)

```
users/{uid}/
  profile/
    profile          ← UserProfile (onboarding, obiettivi, nutrizione)
    baseline         ← BaselineProfileModel (statistiche annuali, metriche Attia)
    diary            ← Diario evoluzione utente (testo append)

  daily_logs/{date}  ← DailyLogModel (indice giornaliero)
    meals/{mealId}   ← MealModel (dettaglio pasto)

  activities/{id}    ← FitnessData (Garmin + Strava unificati)

  daily_health/{date}← Biometrici Garmin (server-written, path fisso)

  rolling_10days/
    current          ← Rolling10DaysModel (aggregato 10gg)

  ai_current/
    meal             ← NutritionMealPlanAi (obiettivi pasto giornalieri)
    allenamenti      ← AiCurrentAllenamentiModel (obiettivo allenamento del giorno)
    home_longevity_plan ← HomeLongevityPlanDay (4 pilastri + sprint + consiglio)
```

> **Nota**: `daily_health` è scritto dal `garmin-sync-server` (Python, repo separato). Il path rimane invariato perché richiederebbe modifiche server-side.

---

## 2. Collezioni principali

| Collezione | Percorso | Scrittore | Lettore |
|------------|----------|-----------|---------|
| Profile | `profile/profile` | `UserProfileNotifier` | `userProfileStreamProvider`, `LongevityEngine` |
| Baseline | `profile/baseline` | `AggregationService`, `NutritionCalculatorService` | `BaselineProfileModel`, `LongevityEngine`, `AiPromptService` |
| Diary | `profile/diary` | `LongevityEngine` | `LongevityEngine` (contesto AI) |
| Daily logs | `daily_logs/{date}` | `NutritionService`, garmin-sync-server | `DailyLogModel`, `LongevityEngine`, `AggregationService` |
| Meals | `daily_logs/{date}/meals/{id}` | `NutritionService` | `mealsForDayStream` |
| Activities | `activities/{id}` | garmin-sync-server, `StravaService` | `activitiesStreamProvider`, `LongevityEngine`, `AggregationService` |
| Daily health | `daily_health/{date}` | garmin-sync-server | `dailyHealthStreamProvider`, `LongevityEngine`, `AggregationService` |
| Rolling 10 days | `rolling_10days/current` | `AggregationService` | `Rolling10DaysModel`, `LongevityEngine` |
| AI meal | `ai_current/meal` | `LongevityEngine`, `NutritionMealPlanService` | `nutritionMealPlanAiStreamProvider` |
| AI allenamenti | `ai_current/allenamenti` | `LongevityEngine` | `aiCurrentAllenamentiStreamProvider` |
| AI home plan | `ai_current/home_longevity_plan` | `LongevityEngine` | `homeLongevityPlanDayStreamProvider` |

---

## 3. Flusso prompt AI unificato

Un singolo prompt giornaliero genera tutti e tre gli obiettivi:

```
INPUT:
  profile/profile       ← UserProfile (obiettivi, nutrizione, allenamento)
  profile/baseline      ← BaselineProfileModel (storico annuale)
  profile/diary         ← testo diario evoluzione
  daily_logs/{ieri}     ← aggregazione del giorno precedente
  activities/{ieri}     ← attività del giorno precedente
  daily_health/{ieri}   ← biometrici del giorno precedente
  rolling_10days/current← trend 10 giorni

GEMINI (prompt unico)
  ↓ JSON risposta

OUTPUT → scrittura batch:
  ai_current/meal             ← obiettivi colazione/pranzo/cena + macro target
  ai_current/allenamenti      ← tipo, descrizione, durata, intensità
  ai_current/home_longevity_plan ← cuore/forza/alimentazione/recupero + sprint + consiglio
  profile/diary               ← append evoluzione del giorno
```

**Trigger**: bottone "Analisi" in Home (o auto al primo avvio del giorno se i doc `ai_current` sono stale).

---

## 4. Struttura documenti chiave

### `daily_logs/{date}`

Indice giornaliero:
- `date`, `timestamp`
- `activity_ids`: lista ID della collection `activities`
- `health_ref`: riferimento logico a `daily_health/{date}`
- `nutrition_summary`, `nutrition_gemini` (fallback legacy)
- `total_burned_kcal`, `weight_kg`, `goal_today_ia`, `user_notes`

### `activities/{id}`

Attività unificata Garmin + Strava:
- `source`: `garmin`, `strava` o `dual`
- `date`, `startTime`, `dateKey`
- `activityType`, `distanceKm`, `activeMinutes`, `elapsedMinutes`, `calories`
- `avgHeartrate`, `maxHeartrate`, `hasGarmin`, `hasStrava`

### `profile/diary`

Diario evoluzione utente:
- `diary_text`: stringa lunga con storia evolutiva (statistiche reali, andamento, progressi)
- `last_updated`, `last_updated_date`
- Si aggiorna ad ogni analisi AI (append di `diary_update` dal JSON Gemini)
- Se manca: generato da `profile/baseline` + `rolling_10days/current`

### `daily_health/{date}`

Biometrici Garmin: `stats`, `sleep`, `hrv`, `body_battery`, `max_metrics`, `fitness_age`.

---

## 5. Flussi di scrittura

### Nutrizione

```text
[Gemini analizza foto] -> NutritionService
    -> daily_logs/{date}/meals/{mealId}
    -> daily_logs/{date}.nutrition_summary
    -> AggregationService.updateRolling10DaysAndBaseline()
```

### Attività Strava / Garmin

```text
[Strava OAuth] -> StravaService -> activities/{id} + daily_logs.activity_ids
[garmin-sync-server] -> daily_health/{date} + activities/{id} + daily_logs.activity_ids
```

### Obiettivi AI giornalieri

```text
[Tasto "Analisi" in Home] -> LongevityEngine.buildUnifiedDailyContext()
    -> LongevityEngine.buildUnifiedPromptFromContext()
    -> GeminiService.generateFromPrompt()
    -> LongevityEngine.saveUnifiedAiCurrent()
        -> ai_current/meal
        -> ai_current/allenamenti
        -> ai_current/home_longevity_plan
        -> profile/diary (append)
```

---

## 6. File di riferimento

| File/Servizio | Legge | Scrive |
|---------------|-------|--------|
| `NutritionService` | meals, daily_logs | meals, nutrition_summary |
| `StravaService` | activities | activities, daily_logs.activity_ids |
| `garmin-sync-server` | activities | daily_health, activities, daily_logs |
| `AggregationService` | daily_logs, activities, daily_health, profile | rolling_10days, profile/baseline |
| `NutritionCalculatorService` | profile | profile/baseline (campi nutrizione) |
| `LongevityEngine` | daily_logs, activities, daily_health, rolling_10days, profile, profile/diary | ai_current/*, profile/diary |
| `NutritionMealPlanService` | profile | ai_current/meal |
| `data_sync_notifier` | activities, daily_health | — |

---

## 7. Regole Firestore

`firestore.rules` permette `read, write` su `users/{userId}/{document=**}` solo se `request.auth.uid == userId`.

Il `garmin-sync-server` usa Admin SDK e bypassa le regole utente.
