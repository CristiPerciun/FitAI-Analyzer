# FitAI Analyzer - Build iOS con GitHub Actions

Guida rapida per compilare e installare l'app sul tuo iPhone (Apple ID gratuito).

---

## Senza Apple ID? Usa la modalità demo

Se **non hai ancora Apple ID** o non puoi collegare Garmin/MyFitnessPal:

1. Avvia l'app (emulatore, web o dispositivo)
2. Nella schermata iniziale scegli **"Modalità demo"**
3. L'app usa dati simulati (passi, calorie) che imitano Health Connect / Garmin / Apple Health
4. Puoi sviluppare e testare la dashboard senza OAuth né iPhone

**Sviluppo su Windows**: la Modalità demo simula il flusso Apple Health (login + sync dati). Usala per sviluppare su Windows come se fossi su iPhone con Health.

Per disattivare i dati demo e usare dati reali, imposta `kUseDemoData = false` in `lib/utils/demo_fitness_data.dart`.

---

## ✅ Passo 1 – Carica il progetto su GitHub (FATTO)

Se devi rifarlo da zero:

```powershell
cd "c:\Users\c.perciun\Documents\Custom_WorkSpace\FitAI Analyzer"

# Inizializza Git (se non fatto)
git init

# Aggiungi tutti i file
git add .

# Primo commit
git commit -m "Initial commit - FitAI Analyzer"

# Collega al repository GitHub
git remote add origin https://github.com/CristiPerciun/FitAI-Analyzer.git

# Rinomina branch in main
git branch -M main

# Push su GitHub
git push -u origin main
```

---

## ✅ Passo 2 – GitHub Actions (GIÀ CONFIGURATO)

Il workflow `.github/workflows/build-ios.yml` è già presente. Si avvia automaticamente ad ogni push su `main`.

---

## Passo 3 – Esegui la build

1. Vai su **https://github.com/CristiPerciun/FitAI-Analyzer**
2. Clicca **Actions**
3. Seleziona **"Build iOS per iPhone"**
4. La build parte automaticamente dopo il push, oppure clicca **"Run workflow"** → **"Run workflow"**
5. Attendi 10–15 minuti
6. Quando è verde, clicca sulla run completata
7. In **Artifacts** scarica **FitAI-Analyzer-iOS**

---

## Passo 4 – Prepara l'iPhone (PRIMA di Sideloadly)

### 4.1 Abilita la Modalità Sviluppatore (iOS 16+)

1. **Impostazioni** → **Privacy e sicurezza** → scorri in basso
2. Trova **Modalità sviluppatore** → attivala
3. L'iPhone si riavvierà
4. Al riavvio conferma con **Attiva**

### 4.2 Autorizza il computer

1. Collega l'iPhone al PC con cavo USB
2. Sul telefono apparirà **"Autorizza questo computer?"** → tocca **Autorizza**
3. Inserisci il codice del telefono se richiesto

### 4.3 Dopo l'installazione con Sideloadly

1. **Impostazioni** → **Generali** → **VPN e gestione dispositivo**
2. Trova il profilo dello sviluppatore (il tuo Apple ID)
3. Tocca **Autorizza** → conferma

---

## Passo 5 – Installa con Sideloadly

1. Scarica l'artefatto **FitAI-Analyzer-iOS** da GitHub Actions (run completata → Artifacts)
2. Estrai lo zip e ottieni il file **Payload.ipa** (struttura: Payload/Runner.app/)
3. Apri **Sideloadly**
4. Trascina il file `.ipa` in Sideloadly (o clicca "IPA File" e selezionalo)
5. Inserisci il tuo **Apple ID** (email) e **password**
6. Clicca **Start**
7. Se richiesto, inserisci il codice **2FA** (autenticazione a due fattori)
8. Attendi la fine dell'installazione

---

## Aggiornamenti futuri

Dopo aver modificato il codice:

```powershell
git add .
git commit -m "Descrizione modifiche"
git push origin main
```

Poi scarica la nuova IPA da Actions e reinstalla con Sideloadly.

---

## Riepilogo step (checklist)

| # | Step | Stato |
|---|------|-------|
| 1 | Carica progetto su GitHub | ✅ |
| 2 | Workflow GitHub Actions configurato | ✅ |
| 3 | Esegui build → scarica IPA da Artifacts | ⏳ |
| 4 | Prepara iPhone: Modalità sviluppatore + autorizza PC | ⏳ |
| 5 | Installa con Sideloadly (Apple ID + 2FA) | ⏳ |
| 6 | Autorizza profilo: Impostazioni → VPN e gestione dispositivo | ⏳ |

---

## Note

- **Scadenza 7 giorni**: con Apple ID gratuito l'app scade dopo 7 giorni → reinstalla
- **Max 3 app**: puoi avere al massimo 3 app sideload contemporaneamente
