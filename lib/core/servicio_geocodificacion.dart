/// Geocodificación de direcciones de locales (Nominatim + cache en memoria).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'coordenadas_ciudades.dart';

class ServicioGeocodificacion {
  ServicioGeocodificacion._();
  static final instancia = ServicioGeocodificacion._();

  final _cache = <String, LatLng>{};
  DateTime? _ultimaPeticion;

  LatLng? parsearDesdeUrlMaps(String? url) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return null;
    final patrones = <RegExp>[
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'[?&]ll=(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
    ];
    for (final p in patrones) {
      final m = p.firstMatch(raw);
      if (m == null) continue;
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  Future<LatLng?> resolver({
    required String id,
    String? direccion,
    String? ciudad,
    String? provincia,
    String? urlMaps,
    String? nombreFallback,
  }) async {
    final key = [
      direccion ?? '',
      ciudad ?? '',
      provincia ?? '',
      urlMaps ?? '',
      id,
    ].join('|');
    final cached = _cache[key];
    if (cached != null) return cached;

    final desdeUrl = parsearDesdeUrlMaps(urlMaps);
    if (desdeUrl != null) {
      _cache[key] = desdeUrl;
      return desdeUrl;
    }

    final partes = <String>[
      if (direccion != null && direccion.trim().isNotEmpty) direccion.trim(),
      if (ciudad != null && ciudad.trim().isNotEmpty) ciudad.trim(),
      if (provincia != null && provincia.trim().isNotEmpty) provincia.trim(),
      'Argentina',
    ];
    if (partes.length <= 1 && (nombreFallback?.trim().isNotEmpty ?? false)) {
      partes.insert(0, nombreFallback!.trim());
    }
    if (partes.isEmpty) {
      final ciudadCoord = CoordenadasCiudades.deCiudad(ciudad);
      if (ciudadCoord != null) {
        final jitter = CoordenadasCiudades.conJitter(ciudadCoord, id);
        _cache[key] = jitter;
        return jitter;
      }
      return null;
    }

    final geo = await _geocodificarNominatim(partes.join(', '));
    if (geo != null) {
      _cache[key] = geo;
      return geo;
    }

    final ciudadCoord = CoordenadasCiudades.deCiudad(ciudad);
    if (ciudadCoord != null) {
      final jitter = CoordenadasCiudades.conJitter(ciudadCoord, id);
      _cache[key] = jitter;
      return jitter;
    }
    return null;
  }

  Future<LatLng?> _geocodificarNominatim(String consulta) async {
    try {
      final ahora = DateTime.now();
      if (_ultimaPeticion != null) {
        final diff = ahora.difference(_ultimaPeticion!);
        if (diff.inMilliseconds < 1100) {
          await Future<void>.delayed(
            Duration(milliseconds: 1100 - diff.inMilliseconds),
          );
        }
      }
      _ultimaPeticion = DateTime.now();

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(consulta)}&format=json&limit=1',
      );
      final resp = await http.get(
        uri,
        headers: const {'User-Agent': 'FernecitoApp/1.0 (mapa-explorar)'},
      );
      if (resp.statusCode != 200) return null;
      final lista = jsonDecode(resp.body);
      if (lista is! List || lista.isEmpty) return null;
      final row = lista.first;
      if (row is! Map) return null;
      final lat = double.tryParse(row['lat']?.toString() ?? '');
      final lon = double.tryParse(row['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (e) {
      debugPrint('[Geocodificacion] $e');
      return null;
    }
  }
}
