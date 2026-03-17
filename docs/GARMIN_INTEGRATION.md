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
| Attività | `users/{uid}/activities/{id}` | Server + StravaService | Attività unificate Garmin/Strava con merge fuzzy e `source: garmin/strava/dual` |
| Daily log | `users/{uid}/daily_logs/{date}` | Server + StravaService + NutritionService | Indice giornaliero con `activity_ids`, `health_ref`, nutrizione e metadati |
| Daily health | `users/{uid}/daily_health/{date}` | Server | Passi, sonno, HRV, Body Battery, VO2Max, Fitness Age |

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
| `GarminService.activitiesStream` | `activities` | Dashboard allenamenti |
| `dailyHealthStreamProvider` | `daily_health` | LongevityHeader, GarminDailyStats |
| `LongevityEngine.buildGeminiHomeContext` | `daily_health` + `activities` + `daily_logs` | Prompt AI (7 giorni + 8 settimane) |

## Setup garmin-sync-server

**IMPORTANTE**: Il server usa il `uid` passato nel body delle richieste (non `USER_ID` da env). L'UID deve corrispondere all'**UID Firebase** dell'utente.

1. L'app invia `uid` (Firebase Auth) al login e al sync
2. Il server scrive in `users/{uid}/activities`, `users/{uid}/daily_health` e aggiorna `daily_logs/{date}`
3. Le credenziali Firebase sono in `FIREBASE_CREDENTIALS` o `FIREBASE_CREDENTIALS_B64`
