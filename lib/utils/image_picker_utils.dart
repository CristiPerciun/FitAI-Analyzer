import 'package:image_picker/image_picker.dart';

/// Determina il MIME type di un'immagine scelta da [ImagePicker], con fallback
/// sull'estensione del file e infine su `image/jpeg`.
String mimeTypeForPickedImage(XFile file) {
  final m = file.mimeType;
  if (m != null && m.isNotEmpty) return m;
  final p = file.path.toLowerCase();
  if (p.endsWith('.png')) return 'image/png';
  return 'image/jpeg';
}
