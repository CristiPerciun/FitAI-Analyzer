/// Costanti API per OAuth e servizi esterni.
/// Sostituisci INSERISCI_QUI_* con i valori reali da developer.garmin.com e developer.myfitnesspal.com
class ApiConstants {
  ApiConstants._();

  // Garmin OAuth - valori da configurare
  static const String garminClientId = 'INSERISCI_QUI_IL_TUO_CLIENT_ID'; // lo prendi da developer.garmin.com
  static const String garminRedirectUri = 'myapp://oauth/callback';

  // MyFitnessPal OAuth - valori da configurare
  static const String mfpClientId = 'INSERISCI_QUI_IL_TUO_MFP_CLIENT_ID'; // da developer.myfitnesspal.com
  static const String mfpRedirectUri = 'myapp://oauth/callback';

  // Garmin API URLs
  static const String garminAuthUrl = 'https://connect.garmin.com/oauth2Confirm';
  static const String garminTokenUrl = 'https://diauth.garmin.com/di-oauth2-service/oauth/token';
  static const String garminWellnessUrl = 'https://apis.garmin.com/wellness-api/rest';

  // MyFitnessPal API URLs
  static const String mfpAuthUrl = 'https://www.myfitnesspal.com/oauth/authorize';
  static const String mfpTokenUrl = 'https://api.myfitnesspal.com/oauth/token';

  // Chiavi Secure Storage
  static const String secureStorageGarminAccessToken = 'garmin_access_token';
  static const String secureStorageGarminRefreshToken = 'garmin_refresh_token';
  static const String secureStorageMfpAccessToken = 'mfp_access_token';
  static const String secureStorageMfpRefreshToken = 'mfp_refresh_token';
  static const String secureStorageGarminCodeVerifier = 'garmin_code_verifier';

  // Chiavi Secure Storage aggiuntive (usate dai servizi)
  static const String secureStorageMfpUserId = 'mfp_user_id';
  static const String secureStorageGarminClientSecret = 'garmin_client_secret';
  static const String secureStorageMfpClientSecret = 'mfp_client_secret';

  // AI API
  static const String aiApiKey = 'ai_api_key';
  static const String aiBaseUrl = 'ai_base_url';
}
