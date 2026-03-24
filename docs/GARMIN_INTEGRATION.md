# Integrazione Garmin Sync Server

FitAI Analyzer legge i dati Garmin da Firestore scritti dal **garmin-sync-server** (Python). L’URL del server è in **`.env`**.

### LAN e remoto (auto-detect)

Se imposti **`GARMIN_SERVER_URL_LAN`** e **`GARMIN_SERVER_URL_REMOTE`**, l’app prova prima la LAN (timeout breve); se non risponde, usa l’URL remoto (es. HTTPS dietro Nginx / DuckDNS). Esempio:

```env
GARMIN_SERVER_URL_LAN=http://192.168.1.200:8080
GARMIN_SERVER_URL_REMOTE=https://esempio.duckdns.org
```

Per **forzare un solo URL** (disattiva il probe): usa solo **`GARMIN_SERVER_URL`**.

- **NAT loopback**: da una macchina in LAN spesso non raggiungi il tuo hostname pubblico; è normale.  
- Dopo il primo successo, l’URL può essere cachato per la sessione (vedi `GarminService`).

**Stessa rete (telefono a casa con il Pi):** in `.env.example` compare spesso un IP tipo `http://10.15.22.3:8080`. In alternativa **mDNS**: `http://raspberrypi.local:8080` (vedi `RPI_DEPLOY.md` sul repo server).

**Telefono fuori casa, server a casa:** `*.local` e gli IP LAN **non** sono raggiungibili da Internet. Serve uno di questi approcci:

| Approccio | Idea |
|-----------|------|
| **Tailscale** (spesso il più semplice) | VPN mesh: installi Tailscale su Pi e sul telefono; usi un hostname tipo `http://raspberrypi:8080` o l’IP Tailscale (100.x) in `GARMIN_SERVER_URL`. Funziona ovunque c’è rete. |
| **Cloudflare Tunnel** / **ngrok** | Espone il servizio sul Pi con un URL HTTPS pubblico (configurazione e policy da valutare). |
| **Port forwarding + DDNS** | Router apre la porta verso il Pi; nome dinamico tipo `casatua.duckdns.org`. Attenzione a sicurezza (HTTPS, firewall, token API). |
| **Server in cloud** | Sposti `garmin-sync-server` su una VM con IP/URL pubblico (niente Pi a casa per quella parte). |

In `.env` Flutter imposti **un solo** `GARMIN_SERVER_URL` coerente con come ti connetti di solito (es. Tailscale se vuoi sia casa che fuori con lo stesso URL). Se a volte sei solo in LAN senza VPN, puoi usare due build/profili `.env` diversi oppure cambiare manualmente l’URL quando cambi scenario.

Repository server: [garmin-sync-server](https://github.com/CristiPerciun/garmin-sync-server); deploy Pi: `RPI_DEPLOY.md` in quel repo.

Se proteggi l’API con un reverse proxy (Bearer), imposta opzionalmente **`GARMIN_SERVER_BEARER_TOKEN`** in `.env`: l’app invia `Authorization: Bearer …` su connect / disconnect / sync-vitals.

> **Stesso progetto Firebase** (app + server): [FIREBASE_SETUP.md](FIREBASE_SETUP.md)  
> **Architettura dati completa**: [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md)  
> **Sync unificata (endpoint, Firestore, Flutter)**: [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md)  
> **Flussi Garmin e AI**: [FLUSSI_GARMIN_AI.md](FLUSSI_GARMIN_AI.md)

---

## 1. Architettura

```
[Garmin Connect] → [garmin-sync-server (es. Raspberry Pi)] → [Firestore]
                                                          ↓
                                              [FitAI Analyzer Flutter]
```

- **Server**: [github.com/CristiPerciun/garmin-sync-server](https://github.com/CristiPerciun/garmin-sync-server)
- **Deploy consigliato**: Raspberry Pi (vedi `RPI_DEPLOY.md` nel repo garmin-sync-server)

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

Implementazione: repository **`garmin-sync-server`** (locale es. `Custom_WorkSpace/garmin-sync-server` o [GitHub](https://github.com/CristiPerciun/garmin-sync-server)), FastAPI in `main.py`.

| Endpoint | Body | Scopo |
|----------|------|-------|
| `POST /garmin/connect` | `{ uid, email, password }` | Login Garmin, salva token, **`backfillQueued: true`**: storico (es. 60 gg) in **background** (HTTP risponde subito) |
| `POST /garmin/sync` | `{ uid }` | (Legacy / scheduler) sync ampia se ancora esposta |
| `POST /garmin/sync-today` | `{ uid }` | Sync leggera: oggi + ieri `daily_health` + attività recenti |
| `POST /garmin/sync-vitals` | `{ uid }` | **Compat**: stesso comportamento di `sync-today` |
| `POST /sync/delta` | `{ uid, lastSuccessfulSync?, sources? }` | Delta all’avvio app: range da ultimo sync + Strava (lista `after` + dettaglio ultime 5 attività) |
| `POST /garmin/disconnect` | `{ uid }` | Scollega Garmin: elimina token, `garmin_linked=false` |
| `POST /strava/register-tokens` | `{ uid, access_token, refresh_token, expires_at? }` | Salva token in `strava_tokens/{uid}` (solo server), avvia backfill 60 gg paginato + merge fuzzy su `activities` |
| `POST /strava/disconnect` | `{ uid }` | Elimina `strava_tokens/{uid}` |
| `POST /garmin/activity-detail` | `{ uid, garmin_activity_id? \| strava_activity_id? }` | Dettaglio on-demand (FIT/API) e merge su Firestore |

**Risposte JSON (server)**: `sync-today`, `sync-vitals`, `sync/delta` e `activity-detail` possono includere **`no_changes: true`** se nessun documento Firestore è stato modificato (short-circuit dopo confronto). La sync leggera (`sync-today` / vitals) scrive **`garmin_raw`** ridotto (solo campi lista); il dettaglio completo resta su **`activity-detail`** e sul backfill.

**Firestore (server / Admin SDK)**

| Percorso | Scopo |
|----------|--------|
| `users/{uid}/sync_status/backfill` | `status`: `pending` \| `processing` \| `completed` \| `error`, `progress`, `message`, `source` (`garmin` / `strava`) |
| `users/{uid}.lastSuccessfulSync` | Timestamp aggiornato a fine delta / sync-today riuscita |
| `strava_tokens/{uid}` | Token Strava (stesse regole client di `garmin_tokens`: no accesso app) |

**Server Strava**: impostare `STRAVA_CLIENT_ID` e `STRAVA_CLIENT_SECRET` (stessi valori dell’app per refresh token) nell’ambiente del `garmin-sync-server`.

---

## 5. Lettura nell'app Flutter

| File | Collezione | Uso |
|------|------------|-----|
| `GarminService.activitiesStream` | `activities` | Dashboard allenamenti |
| `dailyHealthStreamProvider` | `daily_health` | LongevityHeader, GarminDailyStats |
| `LongevityEngine.buildGeminiHomeContext` | `daily_health` + `activities` + `daily_logs` | Prompt AI (7 giorni + 8 settimane) |

---

## 6. Setup garmin-sync-server

**Repository separato** (non è dentro FitAI Analyzer). Avvio locale dalla root del clone: `pip install -r requirements.txt`, `.env` da `.env.example`, poi ad esempio:

`python -m uvicorn main:app --host 0.0.0.0 --port 8080`

Su Raspberry vedi `RPI_DEPLOY.md` nel repo server.

**IMPORTANTE**: Il server usa il `uid` passato nel body delle richieste (non `USER_ID` da env). L'UID deve corrispondere all'**UID Firebase** dell'utente.

1. L'app invia `uid` (Firebase Auth) al login e al sync
2. Il server scrive in `users/{uid}/activities`, `users/{uid}/daily_health` e aggiorna `daily_logs/{date}`
3. Le credenziali Firebase sono in `FIREBASE_CREDENTIALS` o `FIREBASE_CREDENTIALS_B64`

---

## 7. Login fallito ma le credenziali sono corrette?

Il messaggio nell’app arriva dal server (corpo `detail` di FastAPI). **Non sempre è un errore di password**: la libreria [python-garminconnect](https://github.com/cyberjunky/python-garminconnect) + [Garth](https://github.com/matin/garth) può fallire per SSO/oauth temporaneo, rate limit, o **MFA attivo** sull’account (l’endpoint attuale non chiede il codice 2FA).

Sul Pi: aggiorna le dipendenze (`pip install -r requirements.txt`) e leggi il messaggio completo in SnackBar / risposta HTTP. Dettaglio: sezione **Login Garmin** nel `README.md` del repo **garmin-sync-server**.

### 7.1 HTTP 429 su `sso.garmin.com` (Too Many Requests)

Garmin limita gli accessi al widget SSO. **Non è un bug dell’app**: troppi tentativi di login ravvicinati (o più dispositivi/servizi sullo stesso account) possono far scattare il blocco per decine di minuti.

Il **garmin-sync-server** (≥ 1.0.3) mitiga così:

- **Backoff** su `users/{uid}.garmin_sso_rate_limited_until`: dopo un 429, il server rifiuta nuovi `POST /garmin/connect` fino alla scadenza (default **25 min**, env `GARMIN_SSO_BACKOFF_MINUTES`) per non peggiorare il blocco.
- **Un solo login password alla volta** sul processo (`threading.Lock`).
- **Ritardo avvio backfill** dopo login riuscito (default **90 s**, `GARMIN_BACKFILL_AFTER_CONNECT_DELAY_SEC`) per separare SSO e burst API.
- **Disconnect** azzera `garmin_sso_rate_limited_until` così un nuovo ciclo non parte già in backoff (Garmin può comunque rispondere 429 finché non scade il loro limite).

L’app, al **login Firebase**, chiama `sync/delta` solo **Strava** se `garmin_linked` è false, per evitare richieste Garmin inutili prima del collegamento.
