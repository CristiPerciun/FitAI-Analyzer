# Chiave API Gemini – Configurazione

La chiave Gemini è usata per analisi nutrizionale (foto piatto) e analisi AI fitness.

## Fonti (priorità)

1. **Secure Storage** (dispositivo) – chiave inserita nell'app, salvata in modo sicuro
2. **File `.env`** – per sviluppo locale (GEMINI_API_KEY)

## Su iOS / dispositivo fisico

Se non hai `.env` (es. build da CI o da un altro PC), puoi inserire la chiave nell'app:

1. Apri **Alimentazione**
2. Tocca l'icona **chiave** (🔑) in alto a destra
3. Incolla la tua API key da [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
4. Salva – la chiave resta sul dispositivo in Secure Storage

## Sviluppo locale

- Crea `.env` da `.env.example` e inserisci `GEMINI_API_KEY`
- Oppure usa l'inserimento in-app come sopra

## CI/CD

- GitHub Actions: secret `GEMINI_API_KEY` → workflow crea `.env` prima di `flutter pub get`

## Rotazione

Se la chiave è stata esposta, rigenerala da [aistudio.google.com/apikey](https://aistudio.google.com/apikey) e reinseriscila nell'app.
