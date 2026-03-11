# Verifica integrazione Apple Health (iOS)

Questo documento riassume la conformità del bottone Health alle procedure ufficiali Apple per l'accesso ai dati HealthKit.

## Requisiti Apple HealthKit

### 1. Info.plist – Messaggi di autorizzazione
**Stato: OK**

- `NSHealthShareUsageDescription` – messaggio per lettura dati
- `NSHealthUpdateUsageDescription` – messaggio per scrittura dati

Entrambi sono configurati in `ios/Runner/Info.plist`.

### 2. Capability HealthKit
**Stato: OK**

- File `ios/Runner/Runner.entitlements` con `com.apple.developer.healthkit = true`
- `CODE_SIGN_ENTITLEMENTS` impostato nel progetto Xcode per Debug, Release e Profile

### 3. Flusso di autorizzazione
**Stato: OK**

1. `configure()` – inizializza il plugin prima dell’uso
2. `requestAuthorization(types, permissions: [HealthDataAccess.READ])` – richiesta permessi in sola lettura
3. `getHealthDataFromTypes()` – lettura dati solo dopo l’autorizzazione

### 4. Permessi espliciti READ
**Stato: OK**

Viene usato `HealthDataAccess.READ` per ogni tipo di dato, in linea con le best practice Apple per app che leggono senza scrivere.

### 5. Tipi di dati supportati
**Stato: OK**

| Tipo | HealthKit | Uso |
|------|-----------|-----|
| STEPS | HKQuantityType | Passi giornalieri |
| ACTIVE_ENERGY_BURNED | HKQuantityType | Calorie attive |
| SLEEP_ASLEEP | HKCategoryType | Sonno |
| HEART_RATE | HKQuantityType | Frequenza cardiaca |
| DISTANCE_WALKING_RUNNING | HKQuantityType | Distanza (metri → km) |
| FLIGHTS_CLIMBED | HKQuantityType | Piani |

### 6. Note operative

- **Dispositivo sbloccato**: su iOS i dati Health sono accessibili solo con dispositivo sbloccato. Se l’app è aperta a schermo bloccato, può comparire l’errore `Protected health data is inaccessible`.
- **requestAuthorization su iOS**: il valore di ritorno può essere `true` anche se l’utente nega i permessi; Apple non consente all’app di sapere se l’accesso è stato concesso o negato.
- **HealthKit non disponibile**: su iPad (senza app Salute) o in ambienti enterprise, HealthKit può non essere disponibile. In questi casi `configure()` o `requestAuthorization()` possono fallire.

## Package utilizzato

- **health** (pub.dev) v13.3.1 – wrapper per Apple HealthKit e Google Health Connect

## Riferimenti

- [Apple – Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing_access_to_health_data)
- [health package – pub.dev](https://pub.dev/packages/health)
