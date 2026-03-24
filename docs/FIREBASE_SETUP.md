# Firebase: auth, chiavi e deploy

Unico punto di riferimento per **Authentication**, **allineamento app ↔ server ↔ Garmin** e **deploy delle regole Firestore**.

**Vedi anche**: [DATA_ARCHITECTURE.md](DATA_ARCHITECTURE.md) (collezioni), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md) (sync), [firestore.rules.example](firestore.rules.example).

---

## 1. Authentication (Email / Password)

1. **Firebase Console** → il tuo progetto  
2. **Authentication** → **Sign-in method**  
3. Abilita **Email/Password**  
4. Salva  

L’app supporta accedi, registrati e “ricordami” (secure storage).

---

## 2. Allineare app, `firebase_options` e server Garmin

Se crei un **nuovo progetto Firebase** o rigeneri le chiavi, tutti i componenti devono usare lo **stesso `project_id`**.

### Service Account (Admin SDK) ≠ configurazione app

Il file **`…-firebase-adminsdk-….json`** (`type: service_account`, `private_key`) serve al **backend** (garmin-sync-server con Admin SDK). **Non** va nel repo Flutter e **non** sostituisce `google-services.json`.

**Sul server Garmin** (repo `garmin-sync-server`, vedi `RPI_DEPLOY.md`):

- path al JSON tramite variabile d’ambiente, oppure  
- Base64 dell’intero file → `FIREBASE_CREDENTIALS_B64`

Su Windows:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("percorso\al-tuo-adminsdk.json"))
```

**Sicurezza:** non committare il JSON Admin. Se esposto, revoca la chiave in Google Cloud → IAM → Service Accounts e creane una nuova.

Se rigeneri **solo** il service account e il `project_id` resta uguale, aggiorni **solo** la credenziale sul server, non necessariamente Flutter.

### Rotazione chiavi client (Android / iOS / Web)

Le chiavi in `google-services.json` e `GoogleService-Info.plist` sono **diverse** dalla chiave privata Admin. Per ruotarle: Google Cloud Console → **API e servizi** → **Credenziali**, poi da root del repo Flutter:

```powershell
cd "percorso\FitAI Analyzer"
& "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure -p fit-ai-analyzer -y `
  --platforms=android,ios,macos,web,windows `
  -a com.fitai.fitai_analyzer -i com.fitai.fitaiAnalyzer -m com.fitai.fitaiAnalyzer `
  --overwrite-firebase-options
```

Oppure: `dart pub global activate flutterfire_cli` → `flutterfire configure`.

### File da tenere allineati

1. **Android** — `android/app/google-services.json`  
2. **iOS / macOS** — `ios/Runner/GoogleService-Info.plist`  
3. **Dart** — `lib/firebase_options.dart` (preferibilmente via FlutterFire CLI)

### Backend e CI

- **garmin-sync-server**: stesso progetto Firebase (`FIREBASE_CREDENTIALS` / `FIREBASE_CREDENTIALS_B64`).  
- **GitHub Actions iOS**: lo workflow crea spesso solo `.env` con Gemini; `GoogleService-Info.plist` / `google-services.json` devono essere nel repo (o generati da secret) per la piattaforma che compili.

### Verifica rapida

- Login Firebase Auth ok.  
- Firestore: lettura `users/{uid}` senza errori di permesso.  
- Garmin: lo stesso **uid** Auth che il server riceve in `POST /garmin/connect` (vedi [GARMIN_INTEGRATION.md](GARMIN_INTEGRATION.md)).

---

## 3. Deploy regole Firestore

Le regole sono in `firestore.rules` (root del progetto Flutter).

```bash
firebase deploy --only firestore
```

Se manca la configurazione:

```bash
firebase init firestore
```

e indica `firestore.rules` come file delle regole.

Le regole `match /users/{userId}/{document=**}` limitano read/write ai propri dati (`daily_logs`, `meals`, `activities`, `daily_health`, `rolling_10days`, `baseline_profile`, ecc.). Il garmin-sync-server usa **Admin SDK** e bypassa le regole lato client.
