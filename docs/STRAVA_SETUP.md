# Configurazione Strava OAuth per FitAI Analyzer

## Errore "redirect uri invalid" o "bad request"

Se l'app mostra un errore di redirect URI o la pagina Strava non si carica correttamente, configura l'app su Strava:

1. Vai su **https://www.strava.com/settings/api**
2. Accedi con il tuo account Strava
3. Nel campo **"Authorization Callback Domain"** inserisci:
   - **`strava`** (host di myhealthsync://strava/callback) – consigliato per iOS
   - oppure `myhealthsync` se il primo non funziona
4. Clicca **Save**
5. Riprova la connessione dall'app

## Redirect URI usato dall'app

- **Mobile (iOS/Android):** `myhealthsync://strava/callback`
- **Authorization Callback Domain:** `myhealthsync` oppure `strava` (Strava può interpretare diversamente)

## Importante: Client ID

L'app usa un Client ID fisso. Se hai creato una **tua** applicazione Strava (con il tuo Client ID), devi configurare il Callback Domain in **quella** app. Se usi un'app condivisa, il Callback Domain deve essere configurato dall’owner dell’app.

## Verifica

Dopo aver salvato, la pagina di autorizzazione Strava dovrebbe caricarsi correttamente. Se vedi ancora "bad request" o "redirect uri invalid":

- Prova **`strava`** invece di `myhealthsync` nel Callback Domain
- Verifica che l’app Strava sia configurata per lo stesso Client ID usato nel progetto
