# Sincronizzazione unificata FitAI (Garmin + Strava)

Documento unico che descrive **app Flutter** (`FitAI Analyzer`) e **server** (`garmin-sync-server`): endpoint HTTP, Firestore, trigger in app e cosa è stato **deprecato/rimosso** rispetto alla vecchia logica solo-client.

**Repository**

| Progetto | Percorso tipico |
|----------|-----------------|
| App | `FitAI Analyzer` |
| Server | `garmin-sync-server` (clone locale o [GitHub](https://github.com/CristiPerciun/garmin-sync-server)) |

**Documenti correlati**: [GARMIN_INTEGRATION.md](GARMIN_INTEGRATION.md) (rete, `.env`, schema API, deploy Pi), [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md) (chi legge/scrive le collezioni), [FIREBASE_SETUP.md](FIREBASE_SETUP.md) (Firebase).

---

## 1. Principi (allineati al piano)

1. **Storico lungo (≈60 giorni)** non blocca l’HTTP: dopo `connect` Garmin o `register-tokens` Strava il server accoda un **backfill in thread** e aggiorna `users/{uid}/sync_status/backfill`.
2. **Pull-to-refresh** è leggero: **`POST /garmin/sync-today`** (equivalente a **`/garmin/sync-vitals`** sul server).
3. **Dopo login** (cambio `uid` Firebase) l’app chiama **`POST /sync/delta`** con `lastSuccessfulSync` letto da `users/{uid}` (non richiede Garmin collegato per la parte Strava).
4. **Token Strava** per il backfill stanno in **`strava_tokens/{uid}`** (solo Admin SDK); l’app invia token al server dopo OAuth, **non** fa più backfill massivo su Firestore dal client.
5. **Merge attività** (fuzzy ±2 min, stesso tipo sportivo): implementato sul **server** (Python) per Garmin e Strava; il client non deve più duplicare `saveToFirestore` Strava in bulk.

---

## 2. Firestore (contratti)

| Percorso | Scrittore tipico | Note |
|----------|------------------|------|
| `garmin_tokens/{uid}` | Server | Client: regole `deny` |
| `strava_tokens/{uid}` | Server | Client: regole `deny` |
| `users/{uid}/sync_status/backfill` | Server | Client: **solo lettura** (regole) |
| `users/{uid}.lastSuccessfulSync` | Server | Timestamp fine delta / sync-today / backfill ok |
| `users/{uid}.garmin_linked`, `garmin_initial_sync_done`, `strava_initial_sync_done` | Server / app dove previsto | |
| `users/{uid}/activities/{id}` | Server + (eventuali altri flussi) | Unificato Garmin / Strava / `dual` |
| `users/{uid}/daily_health/{date}` | Server | Biometrici Garmin |
| `users/{uid}/daily_logs/{date}` | Server (+ nutrizione app) | `activity_ids`, `health_ref`, … |

Campi diagnostici legacy **`garmin_last_sync_*`** sul documento utente: ancora aggiornati dal server (`_store_sync_status`) in parallelo al nuovo `sync_status/backfill`; utili per log e troubleshooting.

---

## 3. Server HTTP (`garmin-sync-server`)

File principali: **`main.py`**, **`strava_sync.py`** (solo HTTP Strava), **`firebase_credentials.py`**.

### 3.1 Garmin

| Metodo | Path | Body | Comportamento |
|--------|------|------|----------------|
| POST | `/garmin/connect` | `uid`, `email`, `password` | Login, token in `garmin_tokens`, `garmin_linked`, risposta rapida con **`backfillQueued`**, thread **`_garmin_backfill_worker`** (`BACKFILL_DAYS`, chunk `get_activities_by_date`) |
| POST | `/garmin/disconnect` | `uid` | Rimuove token Garmin, `garmin_linked: false` |
| POST | `/garmin/sync-today` | `uid` | Oggi/ieri + attività recenti; aggiorna **`lastSuccessfulSync`** se ok |
| POST | `/garmin/sync-vitals` | `uid` | **Stesso handler** di `sync-today` (compat app) |
| POST | `/garmin/sync` | `uid` | Sync “full” scheduler-style (14 gg health + attività) |
| POST | `/garmin/activity-detail` | `uid`, `garmin_activity_id` o `strava_activity_id` | Dettaglio on-demand |

### 3.2 Strava

| Metodo | Path | Body | Comportamento |
|--------|------|------|----------------|
| POST | `/strava/register-tokens` | `uid`, `access_token`, `refresh_token`, `expires_at?` | Salva in `strava_tokens`, thread **`_strava_backfill_worker`** |
| POST | `/strava/disconnect` | `uid` | Elimina `strava_tokens` |

Richiede env **`STRAVA_CLIENT_ID`** e **`STRAVA_CLIENT_SECRET`** (stessi dell’app OAuth per il refresh lato server).

### 3.3 Delta unificato

| Metodo | Path | Body |
|--------|------|------|
| POST | `/sync/delta` | `uid`, `lastSuccessfulSync?` (epoch ms consigliato), `sources?` (default `["garmin","strava"]`) |

- **Garmin**: se c’è token, health + attività per intervallo da ultimo sync.  
- **Strava**: lista con `after` + **dettaglio ultime 5 attività** (cattura modifiche).  
- Chiude aggiornando **`lastSuccessfulSync`**.

### 3.4 Sicurezza opzionale

Se **`GARMIN_SERVER_BEARER_TOKEN`** è impostato, le route (tranne **`/internal/*`**) richiedono header `Authorization: Bearer …` (allineato a `GARMIN_SERVER_BEARER_TOKEN` in `.env` Flutter).

---

## 4. App Flutter (`FitAI Analyzer`)

| Componente | Ruolo |
|------------|--------|
| `GarminService` | `connect`, `disconnect`, **`syncToday`** (alias `syncNow`), **`deltaSync`**, **`registerStravaOnServer`**, **`disconnectStravaOnServer`**, probe LAN/REMOTE, Bearer opzionale |
| `GarminSyncNotifier.syncNow` | `trigger == 'login'` → **`deltaSync`**; altrimenti **`syncToday`** (serve `garmin_linked` per refresh manuale) |
| `app.dart` | Al nuovo `uid` → `syncNow(..., trigger: 'login')` → delta |
| `auth_notifier` (Strava) | Dopo OAuth → **`registerStravaOnServer`** (niente più `getRecentActivities` + `saveToFirestore` client) |
| `sync_backfill_status_provider` | Stream su `users/{uid}/sync_status/backfill` |
| `MainShellScreen` | Banner + progress se `pending` / `processing` |
| `app.dart` listener | Da `processing`/`pending` → `completed` → `updateRolling10DaysAndBaseline` |
| Impostazioni | Strava disconnect: **`disconnectStravaOnServer`** poi `clearTokens` locale |

Timeout indicativi: **~60s** sync-today, **~120s** delta (vedi `garmin_service.dart`).

---

## 5. Cosa non si usa più (primo giro sync)

| Prima | Ora |
|-------|-----|
| App: dopo Strava OAuth, `getRecentActivities(30)` + `StravaService.saveToFirestore` | **Rimosso dal client**; backfill solo server |
| Connect server: solo thread “2 giorni vitals” | Thread **backfill ~60 giorni** + `sync_status/backfill` |
| Solo `sync-vitals` come nome “ufficiale” | **`sync-today`** + alias **`sync-vitals`** |

Il server mantiene **`_store_sync_status`** (`garmin_last_sync_*`) per compatibilità con log/monitoraggio; il piano UI si appoggia a **`sync_status/backfill`**.

---

## 6. Verifica allineamento (checklist)

- [ ] Server: `pip install -r requirements.txt` include **httpx**.  
- [ ] Server `.env`: `STRAVA_CLIENT_*` se usi Strava sul Pi; `BACKFILL_DAYS` / `GARMIN_BACKFILL_BATCH_DAYS` opzionali.  
- [ ] Firestore rules: `strava_tokens` deny client; `sync_status` write deny client.  
- [ ] App `.env`: `GARMIN_SERVER_URL` (o LAN/REMOTE) coerente; `GARMIN_SERVER_BEARER_TOKEN` se attivo sul server.  
- [ ] Test server: `pytest tests/test_api_smoke.py` (nel repo `garmin-sync-server`).  
- [ ] Test app: `flutter test test/garmin_service_test.dart`.

---

## 7. Sezioni rapide per ruolo

### 7.1 Solo Garmin (lettura veloce)

1. Utente: Connect → `POST /garmin/connect` → backfill thread.  
2. Refresh elenco oggi: `POST /garmin/sync-today`.  
3. Login app: `POST /sync/delta` con ultimo timestamp.

### 7.2 Solo Strava (lettura veloce)

1. OAuth in app → token locali (prefs) + `POST /strava/register-tokens` → backfill server.  
2. Disconnect: `POST /strava/disconnect` + clear prefs in app.  
3. Delta: incluso in `POST /sync/delta` se `strava` in `sources` e env server configurato.

---

## 8. Strava OAuth (app)

### Errore "redirect uri invalid" o "bad request"

1. **https://www.strava.com/settings/api** → la tua applicazione API  
2. Campo **Authorization Callback Domain**: prova **`strava`** (host di `myhealthsync://strava/callback`) oppure `myhealthsync` se il primo non funziona  
3. Salva e riprova dalla app  

### Redirect URI usati dall’app

- **Mobile (iOS/Android):** `myhealthsync://strava/callback`  
- **Callback Domain** su Strava: `strava` o `myhealthsync` (Strava può interpretarli in modo diverso)

### Client ID

L’app può usare un Client ID di progetto. Se registri **la tua** app Strava, configura il Callback Domain su **quella** app; stesso Client ID che usi in `strava_service.dart` e sul server (`STRAVA_CLIENT_ID` / `STRAVA_CLIENT_SECRET` devono combaciare con OAuth refresh lato server).

### Server

Dopo OAuth, l’app invia i token a **`POST /strava/register-tokens`**. Sul Pi servono **`STRAVA_CLIENT_ID`** e **`STRAVA_CLIENT_SECRET`** uguali a quelli dell’app.

---

*Ultimo aggiornamento: allineato a `main.py` + `strava_sync.py` in `garmin-sync-server` e a `GarminService` / `auth_notifier` / `garmin_sync_notifier` in FitAI Analyzer.*
