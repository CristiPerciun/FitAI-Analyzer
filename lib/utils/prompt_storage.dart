// Salva il prompt master in locale (cartella prompt/) per demo.
// Non crea file su iOS. Su web usa stub (no-op).
export 'prompt_storage_io.dart' if (dart.library.html) 'prompt_storage_stub.dart';
