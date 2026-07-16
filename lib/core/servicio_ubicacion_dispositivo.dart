/// Ubicación del dispositivo — flujo correcto en web/PWA, iOS y Android.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'ubicacion_navegador.dart';

class ResultadoUbicacionDispositivo {
  const ResultadoUbicacionDispositivo({
    required this.exito,
    this.latitud,
    this.longitud,
    this.mensajeUsuario,
    this.ofrecerAjustes = false,
  });

  final bool exito;
  final double? latitud;
  final double? longitud;
  final String? mensajeUsuario;
  final bool ofrecerAjustes;

  factory ResultadoUbicacionDispositivo.ok(double lat, double lng) {
    return ResultadoUbicacionDispositivo(
      exito: true,
      latitud: lat,
      longitud: lng,
    );
  }

  factory ResultadoUbicacionDispositivo.error(
    String mensaje, {
    bool ofrecerAjustes = false,
  }) {
    return ResultadoUbicacionDispositivo(
      exito: false,
      mensajeUsuario: mensaje,
      ofrecerAjustes: ofrecerAjustes,
    );
  }
}

class ServicioUbicacionDispositivo {
  ServicioUbicacionDispositivo._();
  static final instancia = ServicioUbicacionDispositivo._();

  /// Última posición conocida en la sesión (para "a X km de ti" sin re-pedir permiso).
  LatLng? _ultimaPos;
  LatLng? get ultimaPosicionConocida => _ultimaPos;

  /// Posición aproximada SIN prompt: cache de sesión o last-known nativo. null si no hay.
  Future<LatLng?> posicionAproximadaSinPrompt() async {
    if (_ultimaPos != null) return _ultimaPos;
    if (kIsWeb) return null;
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p != null) _ultimaPos = LatLng(p.latitude, p.longitude);
    } catch (_) {
      // sin permiso o sin fix previo → sin badge
    }
    return _ultimaPos;
  }

  /// Debe llamarse de forma **síncrona** desde un gesto del usuario (tap / botón
  /// de diálogo). No hagas `await` antes de invocar este método.
  Future<ResultadoUbicacionDispositivo> iniciarDesdeGestoUsuario() {
    final fut = kIsWeb
        ? _resolverFuturoWeb(_iniciarLecturaWeb())
        : _resolverFuturoNativo(_iniciarLecturaNativa());
    return fut.then((r) {
      if (r.exito && r.latitud != null && r.longitud != null) {
        _ultimaPos = LatLng(r.latitud!, r.longitud!);
      }
      return r;
    });
  }

  Future<({double lat, double lng})> _iniciarLecturaWeb() {
    return obtenerUbicacionNavegador();
  }

  Future<Position> _iniciarLecturaNativa() {
    return Geolocator.checkPermission().then((permiso) async {
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Permiso de ubicación denegado.',
        );
      }

      final gpsActivo = await Geolocator.isLocationServiceEnabled();
      if (!gpsActivo) {
        throw const LocationServiceDisabledException();
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    });
  }

  Future<ResultadoUbicacionDispositivo> _resolverFuturoWeb(
    Future<({double lat, double lng})> futuro,
  ) async {
    try {
      final coords = await futuro;
      return ResultadoUbicacionDispositivo.ok(coords.lat, coords.lng);
    } on TimeoutException {
      return ResultadoUbicacionDispositivo.error(
        'Tardó demasiado en obtener tu ubicación. Probá al aire libre o con el GPS activo.',
      );
    } catch (e, st) {
      debugPrint('[Ubicacion/web] $e\n$st');
      return _mapearError(e);
    }
  }

  Future<ResultadoUbicacionDispositivo> _resolverFuturoNativo(
    Future<Position> futuro,
  ) async {
    try {
      final pos = await futuro;
      return ResultadoUbicacionDispositivo.ok(pos.latitude, pos.longitude);
    } on PermissionDeniedException {
      return ResultadoUbicacionDispositivo.error(
        'Necesitamos permiso de ubicación para mostrarte en el mapa.',
        ofrecerAjustes: true,
      );
    } on LocationServiceDisabledException {
      return ResultadoUbicacionDispositivo.error(
        'Activá el GPS o los servicios de ubicación del dispositivo.',
        ofrecerAjustes: true,
      );
    } on TimeoutException {
      final ultima = await _ultimaPosicionSegura();
      if (ultima != null) {
        return ResultadoUbicacionDispositivo.ok(
          ultima.latitude,
          ultima.longitude,
        );
      }
      return ResultadoUbicacionDispositivo.error(
        'Tardó demasiado en obtener tu ubicación. Probá al aire libre o con el GPS activo.',
        ofrecerAjustes: true,
      );
    } on MissingPluginException catch (e, st) {
      debugPrint('[Ubicacion] plugin no registrado: $e\n$st');
      return ResultadoUbicacionDispositivo.error(
        kDebugMode && defaultTargetPlatform == TargetPlatform.iOS
            ? 'Ubicación no disponible. En simulador: Features → Location → Custom Location. Rebuild completo si persiste.'
            : 'La ubicación no está disponible en este dispositivo.',
      );
    } catch (e, st) {
      debugPrint('[Ubicacion/nativo] $e\n$st');
      final ultima = await _ultimaPosicionSegura();
      if (ultima != null) {
        return ResultadoUbicacionDispositivo.ok(
          ultima.latitude,
          ultima.longitude,
        );
      }
      return _mapearError(e);
    }
  }

  ResultadoUbicacionDispositivo _mapearError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission_denied') || msg.contains('denied')) {
      return ResultadoUbicacionDispositivo.error(
        kIsWeb
            ? 'Ubicación bloqueada. Permitila cuando el navegador lo pida, o en Ajustes del sitio (ícono del candado en Chrome).'
            : 'Necesitamos permiso de ubicación para mostrarte en el mapa.',
        ofrecerAjustes: !kIsWeb,
      );
    }
    if (msg.contains('unavailable')) {
      return ResultadoUbicacionDispositivo.error(
        'No hay señal de ubicación disponible. Revisá que el GPS esté activo.',
        ofrecerAjustes: !kIsWeb,
      );
    }
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
      return ResultadoUbicacionDispositivo.error(
        'No pudimos obtener tu ubicación. En simulador: Features → Location → Custom Location.',
      );
    }
    return ResultadoUbicacionDispositivo.error(
      'No pudimos obtener tu ubicación. Revisá que el GPS esté activo e intentá de nuevo.',
      ofrecerAjustes: !kIsWeb,
    );
  }

  Future<Position?> _ultimaPosicionSegura() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('[Ubicacion] getLastKnownPosition: $e');
      return null;
    }
  }

  Future<bool> abrirAjustes() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
