# Integrazione Garmin Sync Server

FitAI Analyzer legge i dati Garmin da Firestore scritti dal **garmin-sync-server** (Python, deploy su fly.io).

## Architettura

```
[Garmin Connect] → [garmin-sync-server su fly.io] → [Firestore]
                                                          ↓
                                              [FitAI Analyzer Flutter]
```

- **Server**: [github.com/CristiPerciun/garmin-sync-server](https://github.com/CristiPerciun/garmin-sync-server)
- **Deploy**: [fly.io/apps/garmin-sync-server](https://fly.io/apps/garmin-sync-server/activity)

## Collezioni Firestore

| Collezione | Percorso | Contenuto |
|------------|----------|-----------|
| Attività | `users/{uid}/garmin_activities` | Ultime 30 attività (activityId, startTime, activityType, distance, duration, HR, calories) |
| Dati giornalieri | `users/{uid}/garmin_daily/{YYYY-MM-DD}` | stats, heartRate, sleep del giorno |

## Setup garmin-sync-server

**IMPORTANTE**: `USER_ID` nel `.env` del server deve essere uguale all'**UID Firebase** dell'utente.

1. In Firebase Console → Authentication → utente → copia UID
2. Nel server (locale o fly.io secrets): `USER_ID=<uid_firebase>`
3. Il server scrive in `users/{USER_ID}/garmin_activities` e `users/{USER_ID}/garmin_daily`

## Uso nell'app Flutter

- **Dashboard Allenamenti**: le attività Garmin appaiono insieme a quelle Strava (icona blu vs arancione)
- **Provider**: `garminActivitiesStreamProvider`, `garminDailyProvider`
- **Service**: `GarminService` in `lib/services/garmin_service.dart`

## Esempio codice

```dart
// Stream attività real-time
ref.watch(garminActivitiesStreamProvider);

// Dati giornalieri per una data
ref.watch(garminDailyProvider('2025-03-16'));
```
