/// Messaggi di errore user-friendly per Strava OAuth.
/// Converte eccezioni tecniche in messaggi comprensibili per l'utente.
String stravaErrorToUserMessage(Object e) {
  final msg = e.toString();

  // PlatformException: User canceled login (quando l'utente chiude la web view)
  if (msg.contains('PlatformException') &&
      (msg.contains('CANCELED') ||
          msg.contains('User canceled login') ||
          msg.contains('User cancelled'))) {
    return 'Hai chiuso la pagina di autorizzazione Strava.\n\n'
        'Se la pagina di Strava non si caricava o mostrava un errore '
        '"redirect uri invalid" o "bad request", configura correttamente '
        'l\'app su Strava:\n\n'
        '1. Vai su https://www.strava.com/settings/api\n'
        '2. Nel campo "Authorization Callback Domain" inserisci: myhealthsync\n'
        '3. Salva e riprova la connessione.';
  }

  // Errore redirect URI da Strava (bad request)
  if (msg.contains('redirect') &&
      (msg.contains('invalid') ||
          msg.contains('bad request') ||
          msg.contains('application field'))) {
    return 'Strava ha rifiutato il redirect URI.\n\n'
        'Configura l\'app su https://www.strava.com/settings/api:\n'
        '• Authorization Callback Domain: myhealthsync\n\n'
        'Salva le impostazioni e riprova.';
  }

  // Web: token exchange solo lato server (CORS su Strava)
  if (msg.contains('exchange-oauth-code') ||
      msg.contains('non espone ancora POST')) {
    return 'Per Strava su Chrome / web il server di sync deve esporre '
        'POST /strava/exchange-oauth-code (scambio del codice OAuth lato server: '
        'il browser non può chiamare direttamente strava.com/oauth/token).\n\n'
        'Aggiorna garmin-sync-server, aggiungi l’endpoint e riavvia il servizio sul Pi.';
  }

  // Server sync (garmin-sync-server) senza credenziali API Strava
  if (msg.contains('STRAVA_CLIENT_ID') ||
      msg.contains('STRAVA_CLIENT_SECRET') ||
      msg.contains('Server senza STRAVA')) {
    return 'Il server di sync (Raspberry / DuckDNS) non ha configurato Strava.\n\n'
        'Sul Pi, nel file ambiente del servizio (es. /etc/default/garmin-sync-env) '
        'o in garmin-sync-server/.env, imposta:\n'
        '• STRAVA_CLIENT_ID\n'
        '• STRAVA_CLIENT_SECRET\n\n'
        'Devono essere gli stessi valori dell’app Strava su '
        'https://www.strava.com/settings/api\n'
        'Poi: sudo systemctl restart garmin-sync (o equivalente).';
  }

  // Timeout
  if (msg.contains('Timeout') || msg.contains('timeout')) {
    return 'Tempo scaduto durante la connessione a Strava. '
        'Verifica la connessione internet e riprova.';
  }

  // Permessi
  if (msg.contains('permessi') ||
      msg.contains('activity:read') ||
      msg.contains('permission')) {
    return msg; // già in italiano e chiaro
  }

  // Nessun code ricevuto
  if (msg.contains('Nessun code ricevuto')) {
    return 'Strava non ha restituito il codice di autorizzazione. '
        'Riprova o verifica la configurazione su strava.com/settings/api.';
  }

  // Sessione scaduta/revocata
  if (msg.contains('scaduta') || msg.contains('revocata')) {
    return msg; // già user-friendly
  }

  // Autorizzazione annullata (utente ha chiuso la pagina)
  if (msg.contains('annullata')) {
    return 'Autorizzazione Strava annullata. Tocca Strava per riprovare.';
  }

  // Errore generico - mantieni il messaggio ma semplifica se è troppo tecnico
  if (msg.contains('PlatformException') && msg.length > 200) {
    return 'Errore durante la connessione a Strava.\n\n'
        'Possibili cause:\n'
        '• Redirect URI non configurato: aggiungi "myhealthsync" in '
        'Authorization Callback Domain su strava.com/settings/api\n'
        '• Pagina Strava non caricata: verifica la connessione internet\n'
        '• Pagina chiusa prima del completamento\n\n'
        'Dettaglio tecnico: ${msg.substring(0, msg.length.clamp(0, 150))}...';
  }

  return msg;
}
