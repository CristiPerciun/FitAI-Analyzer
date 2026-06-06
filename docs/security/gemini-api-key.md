# Chiave API Gemini – Configurazione

La chiave Gemini è usata per analisi nutrizionale (foto piatto) e analisi AI fitness.

## Fonti (priorità)

1. **Secure Storage** (dispositivo) – chiave inserita nell'app, salvata in modo sicuro
2. **File `.env`** – per sviluppo locale (GEMINI_API_KEY)

## Su iOS / dispositivo fisico

Se non hai `.env` (es. build da CI o da un altro PC), puoi inserire la chiave nell'app:

- Quando provi ad **analizzare un pasto** (foto, galleria o descrizione manuale), se per il backend AI attivo non è configurata una chiave, l'app mostra **automaticamente** un dialog per inserirla (gate `ensureActiveAiBackendHasKey()` nel flusso di meal capture).
- In alternativa, preconfigurala in **Impostazioni**.
- Incolla la tua API key da [aistudio.google.com/apikey](https://aistudio.google.com/apikey).
- La chiave resta sul dispositivo in **Secure Storage** (per-account) ed è sincronizzata via Firebase se l'account è collegato.

## Sviluppo locale

- Crea un file `.env` nella root del progetto con `GEMINI_API_KEY=...` (il `.env` non è versionato; in CI è generato dal secret `GEMINI_API_KEY`)
- Oppure usa l'inserimento in-app come sopra

## CI/CD

- GitHub Actions: secret `GEMINI_API_KEY` → workflow crea `.env` prima di `flutter pub get`

## Rotazione

Se la chiave è stata esposta, rigenerala da [aistudio.google.com/apikey](https://aistudio.google.com/apikey) e reinseriscila nell'app.
