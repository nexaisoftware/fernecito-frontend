import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Llama a navigator.geolocation directamente (más confiable que el plugin en PWA).
Future<({double lat, double lng})> obtenerUbicacionNavegador() {
  final completer = Completer<({double lat, double lng})>();
  final geo = web.window.navigator.geolocation;

  geo.getCurrentPosition(
    (web.GeolocationPosition position) {
      completer.complete((
        lat: position.coords.latitude,
        lng: position.coords.longitude,
      ));
    }.toJS,
    (web.GeolocationPositionError error) {
      switch (error.code) {
        case 1:
          completer.completeError(
            StateError('permission_denied:${error.message}'),
          );
        case 2:
          completer.completeError(
            StateError('position_unavailable:${error.message}'),
          );
        case 3:
          completer.completeError(
            TimeoutException(error.message),
          );
        default:
          completer.completeError(StateError(error.message));
      }
    }.toJS,
    web.PositionOptions(
      enableHighAccuracy: true,
      timeout: 25000,
      maximumAge: 300000,
    ),
  );

  return completer.future;
}
