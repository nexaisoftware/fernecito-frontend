/// Compresión universal para subidas a Supabase Storage (web + iOS + Android).
///
/// 🔁 SYNC: espejo en `frontend_locales/lib/core/comprimir_imagen_storage.dart`.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Tipo de imagen → tamaño máximo del lado largo y calidad JPEG.
enum PerfilImagenStorage {
  /// `avatars` — usuarios/<uid>/avatar.*
  avatarUsuario(maxLado: 512, calidadJpg: 78, webpEnMovil: true),

  /// Portadas de squads.
  portadaSquad(maxLado: 1080, calidadJpg: 76, webpEnMovil: true),

  /// `avatars_locales` — foto de perfil del local.
  avatarLocal(maxLado: 800, calidadJpg: 76, webpEnMovil: true),

  /// `banners_locales`.
  bannerLocal(maxLado: 1200, calidadJpg: 74, webpEnMovil: true),

  /// `fotos_locales` — carrusel (5 fotos).
  fotoLocal(maxLado: 1100, calidadJpg: 72, webpEnMovil: true),

  /// Comprobante de pago (solo imágenes; PDF sin tocar).
  comprobantePago(maxLado: 1400, calidadJpg: 58, webpEnMovil: false),

  /// `flyers_eventos`.
  flyerEvento(maxLado: 1080, calidadJpg: 75, webpEnMovil: true),

  /// Caché local de flyers (más chico).
  flyerCacheLocal(maxLado: 900, calidadJpg: 70, webpEnMovil: false);

  const PerfilImagenStorage({
    required this.maxLado,
    required this.calidadJpg,
    required this.webpEnMovil,
  });

  final int maxLado;
  final int calidadJpg;
  final bool webpEnMovil;
}

class ResultadoImagenComprimida {
  final Uint8List bytes;
  final String extension;
  final String contentType;

  const ResultadoImagenComprimida({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  String get pathSuffix => '.$extension';
}

/// Límite antes de decodificar en RAM (evita picos de memoria).
const int kMaxBytesEntradaCompresion = 22 * 1024 * 1024;

bool esArchivoPdf(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;

String contentTypeDesdeExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'webp':
      return 'image/webp';
    case 'png':
      return 'image/png';
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

/// Comprime bytes para Storage. En móvil intenta WebP si el perfil lo permite.
Future<ResultadoImagenComprimida> comprimirImagenStorage(
  Uint8List raw, {
  required PerfilImagenStorage perfil,
}) async {
  if (raw.isEmpty) {
    throw Exception('La imagen está vacía.');
  }
  if (raw.length > kMaxBytesEntradaCompresion) {
    throw Exception(
      'La imagen es demasiado grande (máx. ${kMaxBytesEntradaCompresion ~/ (1024 * 1024)} MB). '
      'Elegí otra más chica.',
    );
  }
  if (esArchivoPdf(raw)) {
    throw Exception('Los PDF no se comprimen como imagen.');
  }

  if (!kIsWeb && perfil.webpEnMovil) {
    final webp = await _intentarWebpMovil(raw, perfil);
    if (webp != null) return webp;
  }

  return _comprimirConImage(raw, perfil);
}

/// Lee del picker, comprime y devuelve resultado listo para subir.
Future<ResultadoImagenComprimida> comprimirDesdeXFile(
  XFile file, {
  required PerfilImagenStorage perfil,
}) async {
  final raw = await file.readAsBytes();
  return comprimirImagenStorage(raw, perfil: perfil);
}

/// Comprobante: imagen → JPEG comprimido; PDF → sin cambios.
Future<({
  Uint8List bytes,
  String mime,
  String nombre,
})> prepararComprobantePago({
  required Uint8List bytes,
  required String nombreOriginal,
  String? extension,
}) async {
  final ext = (extension ?? '').toLowerCase();
  if (ext == 'pdf' || esArchivoPdf(bytes)) {
    final nombre = nombreOriginal.trim().isEmpty ? 'comprobante.pdf' : nombreOriginal;
    return (bytes: bytes, mime: 'application/pdf', nombre: nombre);
  }

  final comprimida = await comprimirImagenStorage(
    bytes,
    perfil: PerfilImagenStorage.comprobantePago,
  );
  final nombre = _nombreConExtensionJpg(nombreOriginal);
  return (
    bytes: comprimida.bytes,
    mime: comprimida.contentType,
    nombre: nombre,
  );
}

String _nombreConExtensionJpg(String nombreOriginal) {
  final dot = nombreOriginal.lastIndexOf('.');
  final base = dot > 0 ? nombreOriginal.substring(0, dot) : nombreOriginal;
  final limpio = base.trim().isEmpty ? 'comprobante' : base.trim();
  return '$limpio.jpg';
}

Future<ResultadoImagenComprimida?> _intentarWebpMovil(
  Uint8List raw,
  PerfilImagenStorage perfil,
) async {
  try {
    final out = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: perfil.maxLado,
      minHeight: perfil.maxLado,
      quality: perfil.calidadJpg,
      format: CompressFormat.webp,
    );
    if (out.isEmpty) return null;
    if (out.length >= raw.length) return null;
    return ResultadoImagenComprimida(
      bytes: out,
      extension: 'webp',
      contentType: 'image/webp',
    );
  } catch (_) {
    return null;
  }
}

ResultadoImagenComprimida _comprimirConImage(
  Uint8List raw,
  PerfilImagenStorage perfil,
) {
  final original = img.decodeImage(raw);
  if (original == null) {
    if (kIsWeb) {
      throw Exception(
        'No se pudo procesar la imagen. Usá JPG o PNG (evitá HEIC en la web).',
      );
    }
    return ResultadoImagenComprimida(
      bytes: raw,
      extension: 'jpg',
      contentType: 'image/jpeg',
    );
  }

  var resized = original;
  final maxSide =
      original.width > original.height ? original.width : original.height;
  if (maxSide > perfil.maxLado) {
    final scale = perfil.maxLado / maxSide;
    resized = img.copyResize(
      original,
      width: (original.width * scale).round(),
      height: (original.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  final jpg = img.encodeJpg(resized, quality: perfil.calidadJpg);
  final out = Uint8List.fromList(jpg);

  if (out.length < raw.length) {
    return ResultadoImagenComprimida(
      bytes: out,
      extension: 'jpg',
      contentType: 'image/jpeg',
    );
  }

  return ResultadoImagenComprimida(
    bytes: out,
    extension: 'jpg',
    contentType: 'image/jpeg',
  );
}

/// Atajo: avatar de usuario (reemplaza `comprimir_imagen_avatar.dart`).
Future<ResultadoImagenComprimida?> comprimirBytesAvatar(Uint8List raw) async {
  try {
    return await comprimirImagenStorage(
      raw,
      perfil: PerfilImagenStorage.avatarUsuario,
    );
  } catch (_) {
    return null;
  }
}
