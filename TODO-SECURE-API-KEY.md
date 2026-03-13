# ⚠️ TODO: Mettere al sicuro la API key Gemini

**Promemoria**: La chiave Gemini Flash 2.5 è attualmente nel file `.env` (locale, non committato).

## Da fare

1. **Non committare mai** il file `.env` – è già in `.gitignore`
2. **Per CI/CD** (es. GitHub Actions): usare secrets (`GEMINI_API_KEY` in GitHub Secrets)
3. **Per produzione**: considerare
   - Firebase Remote Config
   - Backend proxy che chiama Gemini (la key resta server-side)
   - Flutter Secure Storage per chiavi sensibili su dispositivo
4. **Rotazione**: se la key è stata esposta, rigenerarla da [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

---
*Rimuovere questo file dopo aver completato la migrazione a storage sicuro.*
