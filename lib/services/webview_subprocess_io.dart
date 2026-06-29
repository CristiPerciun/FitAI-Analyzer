import 'package:desktop_webview_window/desktop_webview_window.dart';

/// Su Windows/Linux `flutter_web_auth_2` mostra l'OAuth (Garmin/Strava) in una
/// WebView2 ospitata da `desktop_webview_window`, che lancia un **sottoprocesso
/// dello stesso eseguibile** per renderizzare la title bar/webview. Quel
/// sottoprocesso ri-esegue `main()`.
///
/// Va intercettato e terminato **prima** di `Firebase.initializeApp()`:
/// altrimenti il sottoprocesso prova a inizializzare Firebase, il canale pigeon
/// `FirebaseCoreHostApi.initializeCore` non si connette (channel-error) e l'auth
/// crasha ("apre l'auth di Windows e poi crasha").
///
/// Ritorna `true` se il processo corrente È il sottoprocesso webview
/// (`runWebViewTitleBarWidget` ha riconosciuto i suoi args): in tal caso il
/// chiamante deve fare `return` immediato senza inizializzare l'app. Negli altri
/// processi (principale, mobile) ritorna `false` ed è un no-op.
bool handleWebViewTitleBarSubprocess(List<String> args) =>
    runWebViewTitleBarWidget(args);
