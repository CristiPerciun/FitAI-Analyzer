# Deploy Firestore Security Rules

Le regole di sicurezza sono in `firestore.rules` nella root del progetto.

Per distribuirle su Firebase:

```bash
firebase deploy --only firestore
```

Se il progetto non ha ancora la configurazione Firestore, esegui prima:

```bash
firebase init firestore
```

e seleziona `firestore.rules` come file delle regole.

## Collezioni coperte dalle regole

Le regole `match /users/{userId}/{document=**}` permettono read/write a un utente solo sui propri dati. Coprono:

- `daily_logs`, `meals` (sottocollezione)
- `health_data`, `profile`
- `rolling_10days`, `baseline_profile`
- `garmin_activities`, `garmin_daily`, `daily_health`
- `activities`, `ai_insights` (futuro)

Il garmin-sync-server usa Admin SDK (credenziali di servizio) e bypassa le regole utente.
