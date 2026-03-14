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
