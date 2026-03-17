# Integrazione Garmin Sync Server

FitAI Analyzer legge i dati Garmin da Firestore scritti dal **garmin-sync-server** (Python, deploy su fly.io).

> **Schema dati**: vedi [GARMIN_DATA_SCHEMA.md](GARMIN_DATA_SCHEMA.md) per tipi di dati API e struttura Firebase.  
> **Flussi**: vedi [FLUSSI_GARMIN_AI.md](FLUSSI_GARMIN_AI.md) per il riepilogo completo.

## Architettura

```
[Garmin Connect] → [garmin-sync-server su fly.io] → [Firestore]
                                                          ↓
                                              [FitAI Analyzer Flutter]
```

- **Server**: [github.com/CristiPerciun/garmin-sync-server](https://github.com/CristiPerciun/garmin-sync-server)
- **Deploy**: [fly.io/apps/garmin-sync-server](https://fly.io/apps/garmin-sync-server/activity)

## Collezioni Firestore (scrittura/lettura)

| Collezione | Percorso | Scrittore | Contenuto |
|------------|----------|-----------|-----------|
| Attività | `users/{uid}/garmin_activities/{activityId}` | Server | Ultime attività (activityId, startTime, distance, duration, HR, calories) |
| Daily log | `users/{uid}/daily_logs/{date}.garmin_activities` | Server | Lista attività Garmin per giorno (merge con Strava) |
| Daily health | `users/{uid}/daily_health/{date}` | Server | Passi, sonno, HRV, Body Battery, VO2Max, Fitness Age |
| Garmin daily | `users/{uid}/garmin_daily/{date}` | Server | Marker sync (date, syncedAt) |

## Endpoint server

| Endpoint | Body | Scopo |
|----------|------|-------|
| `POST /garmin/connect` | `{ uid, email, password }` | Login Garmin + sync iniziale |
| `POST /garmin/sync` | `{ uid }` | Sync completa (attività + 14 giorni biometrici) |
| `POST /garmin/sync-vitals` | `{ uid }` | Sync leggera: solo oggi e ieri (pull-to-refresh) |
| `POST /garmin/disconnect` | `{ uid }` | Scollega account: elimina token, imposta garmin_linked=false |

## Lettura nell'app Flutter

| File | Collezione | Uso |
|------|------------|-----|
| `GarminService.garminActivitiesStream` | `garmin_activities` | Dashboard allenamenti |
| `GarminService.getDailyGarminData` | `garmin_daily` | Dati giornalieri Garmin |
| `dailyHealthStreamProvider` | `daily_health` | LongevityHeader, GarminDailyStats |
| `LongevityEngine.buildGeminiHomeContext` | `daily_health` + `daily_logs` | Prompt AI (7 giorni + 8 settimane) |

## Setup garmin-sync-server

**IMPORTANTE**: Il server usa il `uid` passato nel body delle richieste (non `USER_ID` da env). L'UID deve corrispondere all'**UID Firebase** dell'utente.

1. L'app invia `uid` (Firebase Auth) al login e al sync
2. Il server scrive in `users/{uid}/garmin_activities`, `users/{uid}/daily_health`, ecc.
3. Le credenziali Firebase sono in `FIREBASE_CREDENTIALS` o `FIREBASE_CREDENTIALS_B64`
