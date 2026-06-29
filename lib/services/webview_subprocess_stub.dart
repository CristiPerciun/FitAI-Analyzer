/// Stub per piattaforme senza `dart:io` (web): nessun sottoprocesso WebView.
///
/// Su web `desktop_webview_window` non esiste e non va importato (usa `dart:io`).
/// La versione reale è in `webview_subprocess_io.dart`, selezionata via
/// conditional import su `dart.library.io`.
bool handleWebViewTitleBarSubprocess(List<String> args) => false;
