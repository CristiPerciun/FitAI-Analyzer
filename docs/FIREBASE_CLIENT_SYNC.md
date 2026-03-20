# Allineare l’app Flutter al nuovo progetto Firebase

Se in **Firebase Console** hai creato un nuovo progetto o rigenerato le chiavi, l’app deve usare **gli stessi identificativi** del backend (garmin-sync-server, regole Firestore, ecc.).

## Service Account (Admin SDK) ≠ configurazione app

Il file tipo **`fit-ai-analyzer-firebase-adminsdk-….json`** (con `type: service_account`, `private_key`, `client_email`) serve al **backend** (es. garmin-sync-server con Admin SDK), **non** va messo nel progetto Flutter e **non** sostituisce `google-services.json`.

**Sul server Garmin** (repo `garmin-sync-server`, vedi `RPI_DEPLOY.md`):

- opzione A: path al file → variabile d’ambiente che punta al JSON (es. `GOOGLE_APPLICATION_CREDENTIALS` se il server lo supporta);
- opzione B: Base64 del file intero → `FIREBASE_CREDENTIALS_B64` (come da doc deploy).

Su Windows, dalla cartella del JSON:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("percorso\al-tuo-adminsdk.json"))
```

**Sicurezza:** quel JSON è una chiave privilegiata. Non committarlo, non condividerlo in chat pubblica. Se è stato esposto, in **Google Cloud Console → IAM → Service Accounts → chiavi** revoca la vecchia chiave e creane una nuova.

Se il `project_id` nel JSON Admin coincide con quello dell’app (`fit-ai-analyzer` nel tuo caso), **Flutter non va aggiornato** solo perché hai rigenerato il service account: aggiorni solo la credenziale sul server.

### Se vuoi ruotare anche le API key **client** (Android / iOS / Web)

Quelle in `google-services.json` e `GoogleService-Info.plist` (`current_key` / `API_KEY`) sono **diverse** dalla chiave privata Admin SDK. Se anche quelle sono a rischio, ruotale in **Google Cloud Console** (progetto `fit-ai-analyzer`):

1. **API e servizi** → **Credenziali**.
2. Individua le chiavi create da Firebase (es. “Android key”, “Browser key”) collegate alle app.
3. Crea una nuova chiave con restrizioni appropriate **oppure** rigenera secondo la procedura Google; elimina quella compromessa.
4. In **Firebase Console** → **Impostazioni progetto** → app Android/iOS → **Scarica di nuovo** `google-services.json` / plist, **oppure** da root del repo Flutter:

```powershell
cd "percorso\FitAI Analyzer"
& "$env:LOCALAPPDATA\Pub\Cache\bin\flutterfire.bat" configure -p fit-ai-analyzer -y `
  --platforms=android,ios,macos,web,windows `
  -a com.fitai.fitai_analyzer -i com.fitai.fitaiAnalyzer -m com.fitai.fitaiAnalyzer `
  --overwrite-firebase-options
```

Dopo la rotazione lato Google, questo comando aggiorna `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` e `firebase.json` con i valori attuali del backend.

## File da aggiornare (tutti sulla stessa `project_id`)

1. **Android** — sostituisci con il file scaricato dalla console:
   - `android/app/google-services.json`
2. **iOS / macOS** — sostituisci:
   - `ios/Runner/GoogleService-Info.plist`
3. **Dart (Web, Windows, opzioni native)** — rigenera da CLI (consigliato):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Questo aggiorna `lib/firebase_options.dart` e il blocco `flutter` in `firebase.json` in modo coerente con i file nativi.
4. **Manuale** (solo se non usi FlutterFire): copia da console Firebase in `lib/firebase_options.dart` i campi `apiKey`, `appId`, `messagingSenderId`, `projectId`, `storageBucket` (e per web `authDomain`, `measurementId`) per ogni piattaforma — devono combaciare con `google-services.json` / plist.

## Backend Garmin e altri servizi

- Il **garmin-sync-server** deve usare un **service account** dello **stesso** progetto Firebase (`FIREBASE_CREDENTIALS` / `FIREBASE_CREDENTIALS_B64`).
- Se cambi progetto, ridistribuisci le **Firestore Security Rules** sul nuovo progetto e verifica `docs/firestore.rules.example`.

## CI (GitHub Actions)

La build iOS crea solo `.env` con `GEMINI_API_KEY`. Non include `google-services.json`: quel file deve essere **nel repository** (o generato in CI da secret) per la piattaforma che compili. Dopo un nuovo `GoogleService-Info.plist`, committa il file aggiornato.

## Verifica rapida

- Avvio app: login Firebase Auth funziona.
- Firestore: lettura `users/{uid}` senza errori di permesso.
- Garmin: stesso `uid` Auth che il server riceve in `POST /garmin/connect` (vedi `docs/GARMIN_INTEGRATION.md`).
