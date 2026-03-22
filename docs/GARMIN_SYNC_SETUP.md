# Setup Garmin Sync - LAN e Remoto

## Configurazione completata

L'app FitAI Analyzer comunica con il garmin-sync-server in due modalità:

### A casa (stessa rete del Raspberry)
- **URL:** `http://192.168.1.200:8080`
- L'app prova prima questo indirizzo (timeout 3 sec)
- Se risponde → usa LAN (più veloce)

### Fuori casa (cellulare con dati, altro Wi-Fi)
- **URL:** `https://myrasberrysyncgar.duckdns.org`
- Se LAN non risponde → usa DuckDNS (HTTPS, Nginx proxy)

## Variabili .env

```env
GARMIN_SERVER_URL_LAN=http://192.168.1.200:8080
GARMIN_SERVER_URL_REMOTE=https://myrasberrysyncgar.duckdns.org
```

Per forzare un solo URL (disabilita auto-detect):
```env
GARMIN_SERVER_URL=http://192.168.1.200:8080
```

## Architettura

```
[App FitAI] --LAN--> http://192.168.1.200:8080  (direct)
[App FitAI] --REMOTE--> https://myrasberrysyncgar.duckdns.org --> Nginx:443 --> 127.0.0.1:8080
```

## Note

- NAT loopback: da PC a casa non puoi accedere a myrasberrysyncgar.duckdns.org (normale)
- L'app usa probe: prova LAN, se fallisce usa REMOTE
- Cache: dopo il primo successo, l'URL viene cachato per la sessione
