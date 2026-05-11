// Salva i prompt in locale solo su Windows. Su web usa stub (no-op).
export 'prompt_storage_io.dart' if (dart.library.html) 'prompt_storage_stub.dart';
