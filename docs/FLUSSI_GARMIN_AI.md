# Flussi Garmin, sync e AI

> **Sincronizzazione (endpoint, Firestore, Flutter, deprecazioni)**: [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md)  
> **Server Garmin, rete, schema API → Firestore**: [GARMIN_INTEGRATION.md](GARMIN_INTEGRATION.md)  
> **Architettura dati**: [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md)

Questo file resta focalizzato su **UI**, **contesto AI (LongevityEngine)** e **troubleshooting** che non sono ripetuti altrove.

---

## Storico implementazioni (riferimento)

| Area | Progetto | Nota |
|------|----------|------|
| Biometrici → `daily_health` | garmin-sync-server | ✅ |
| Sync leggero / delta / Strava server | garmin-sync-server + app | ✅ vedi SYNC_ARCHITECTURE |
| Pull-to-refresh | FitAI | ✅ → `GarminService.syncToday` |
| Widget Home vitals | FitAI | ✅ `dailyHealthStreamProvider` |
| AI Memory (7 gg + 8 sett) | FitAI | ✅ `longevity_engine.dart` |

---

## Widget Home (GarminDailyStats)

- **Posizione**: Home, sotto PillarGrid  
- **Dati**: `dailyHealthStreamProvider` → passi, sonno, Body Battery da `daily_health`  
- **Stile**: coerente con Longevity Path / Weekly Sprint  

---

## AI Memory – contesto Gemini (LongevityEngine)

**Struttura tipica del prompt** (`buildGeminiHomeContext`, `buildLongevityPlanPrompt`):

1. Profilo utente (onboarding)  
2. Riassunto periodo lungo (medie settimanali: km, workout, passi, sonno, VO2Max, Fitness Age)  
3. Dettaglio **7 giorni** (`daily_logs` indice + `activities` + `daily_health`)  
4. Note e obiettivi (baseline)  

**File**: `lib/services/longevity_engine.dart`.

---

## Troubleshooting

### Log Flutter: `firebase_auth` / `id-token` su thread non-platform (Windows)

Non è la sync Garmin (HTTP → Pi + Firestore). Su **Windows desktop** è un limite noto del plugin; in progetto: workaround su auth state. Per log puliti usa **Android/iOS**. Riferimento: [flutterfire#11933](https://github.com/firebase/flutterfire/issues/11933).

### Server: `SSLCertVerificationError` verso `sso.garmin.com`

Il Pi chiama Garmin in HTTPS. Se compare l’errore, spesso c’è **SSL inspection** o proxy sulla rete. Soluzioni: uscita senza inspection (es. hotspot) o CA root installata sul Pi. Dettagli: `garmin-sync-server/RPI_DEPLOY.md` (sezione SSL Garmin).

### Server: storici `403` / `504` Firestore su `connect_garmin`

Se `verify_firebase_credentials` è `[OK]` ma prima falliva, erano problemi IAM/rete. Se persistono: IAM del service account e connettività Pi → Google.

### Sync “non carica tutto” dopo pull-to-refresh

`sync-today` è **volutamente leggera** (oggi/ieri + attività recenti). Lo **storico lungo** è nel **backfill** dopo connect / `register-tokens`; stato in `users/{uid}/sync_status/backfill`. Timeout client ~60s per `sync-today`; il backfill continua sul server.
