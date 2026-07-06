/// Stub: geolocalización del navegador (no disponible fuera de web).
Future<({double lat, double lng})> obtenerUbicacionNavegador() {
  return Future.error(
    UnsupportedError('Geolocalización del navegador solo en web.'),
  );
}
