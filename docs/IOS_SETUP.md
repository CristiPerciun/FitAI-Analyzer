# FitAI Analyzer - Setup iOS / iPhone

Guida per far funzionare l'app su iPhone (oltre a Windows).

---

## ✅ Configurazione già presente

| Componente | Stato |
|------------|-------|
| Firebase (firebase_options.dart) | ✅ Configurato per iOS |
| GoogleService-Info.plist | ✅ Aggiunto in ios/Runner/ |
| Strava OAuth deep link (myhealthsync://) | ✅ Info.plist CFBundleURLTypes |
| Bundle ID (com.fitai.fitaiAnalyzer) | ✅ Allineato con Firebase |

---

## 📋 Checklist prima di installare su iPhone

### 1. Strava API – Redirect URI

Su [developers.strava.com](https://www.strava.com/settings/api) → **My API Application**:

- **Authorization Callback Domain**: aggiungi `myhealthsync://strava/callback`
- Oppure, se Strava accetta solo domini: verifica che l’app mobile sia registrata con il bundle ID `com.fitai.fitaiAnalyzer`

> **Nota**: Strava per app mobile con custom scheme richiede il redirect URI completo. Controlla la documentazione Strava aggiornata.

### 2. Firebase Console

- Progetto **fit-ai-analyzer** con app iOS registrata (bundle ID: `com.fitai.fitaiAnalyzer`)
- **Authentication** → Sign-in method → **Anonymous** abilitato
- **Firestore** creato e regole configurate

### 3. Build e installazione

Segui **GITHUB_IOS_BUILD.md** per:

1. Build tramite GitHub Actions
2. Download dell’IPA
3. Installazione con Sideloadly (Apple ID gratuito)

---

## 🔄 Differenze Windows vs iOS

| Aspetto | Windows | iOS |
|---------|---------|-----|
| Strava OAuth | Loopback HTTP locale | Deep link `myhealthsync://` |
| Firebase Auth | Workaround platform thread | Nessun workaround |
| FlutterWebAuth2 | Desktop flow | ASWebAuthenticationSession |

Su iOS il flusso Strava è:

1. Tap "Strava" → apertura Safari esterno (necessario per il redirect)
2. Login Strava e autorizzazione
3. Redirect a `myhealthsync://strava/callback?code=xxx`
4. iOS apre l’app → app_links riceve il code
5. Exchange code → token → salvataggio su Firestore

---

## ⚠️ Problemi comuni

### "Nessun code ricevuto da Strava"
- Verifica che `myhealthsync://strava/callback` sia in Strava API settings
- Controlla che Info.plist abbia `CFBundleURLTypes` con scheme `myhealthsync`

### Firebase non si connette
- Verifica che `GoogleService-Info.plist` sia in `ios/Runner/` e incluso nel target Runner
- Controlla che il bundle ID sia `com.fitai.fitaiAnalyzer`

### App scaduta dopo 7 giorni
- Con Apple ID gratuito l’app sideload scade dopo 7 giorni
- Reinstalla scaricando di nuovo l’IPA da GitHub Actions

---

## 📱 Test rapido su iPhone

1. Installa l’app (Sideloadly)
2. Apri l’app → schermata "Connetti i tuoi dati"
3. Tap **Strava** → si apre il browser per l’autorizzazione
4. Autorizza → ritorno all’app → "Dati Strava salvati!"
5. Vai alla Dashboard → verifica attività e grafici
6. Tap **Analisi AI** → verifica che Gemini risponda (serve API key configurata)
