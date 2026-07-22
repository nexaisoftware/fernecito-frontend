/// Coordenadas aproximadas de ciudades soportadas (MVP Córdoba).
/// Sync con [UbicacionesData].
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'ubicaciones_data.dart';

class CoordenadasCiudades {
  CoordenadasCiudades._();

  static const _coords = <String, LatLng>{
    'Córdoba capital': LatLng(-31.4201, -64.1888),
    'Alta Gracia': LatLng(-31.6574, -64.4283),
    'Bell Ville': LatLng(-32.6259, -62.6887),
    'Bialet Massé': LatLng(-31.2847, -64.4644),
    'Capilla del Monte': LatLng(-30.8608, -64.5253),
    'Colonia Caroya': LatLng(-31.0156, -64.0603),
    'Cosquín': LatLng(-31.2456, -64.4656),
    'Embalse': LatLng(-32.1800, -64.4181),
    'Hernando': LatLng(-32.4269, -63.7333),
    'Jesús María': LatLng(-30.9815, -64.0942),
    'La Calera': LatLng(-31.3439, -64.3353),
    'La Falda': LatLng(-31.0884, -64.4899),
    'Malagueño': LatLng(-31.4675, -64.3584),
    'Marcos Juárez': LatLng(-32.6975, -62.1067),
    'Mendiolaza': LatLng(-31.2672, -64.3008),
    'Mina Clavero': LatLng(-31.7219, -65.0061),
    'Nono': LatLng(-31.7917, -65.0036),
    'Río Ceballos': LatLng(-31.1647, -64.3222),
    'Río Cuarto': LatLng(-33.1231, -64.3496),
    'Río Tercero': LatLng(-32.1730, -64.1144),
    'Saldán': LatLng(-31.3019, -64.3092),
    'San Francisco': LatLng(-31.4278, -62.0826),
    'Santa María de Punilla': LatLng(-31.2500, -64.4667),
    'Unquillo': LatLng(-31.2306, -64.3153),
    'Villa Allende': LatLng(-31.2944, -64.2953),
    'Villa Carlos Paz': LatLng(-31.4241, -64.4978),
    'Villa Cura Brochero': LatLng(-31.7061, -65.0186),
    'Villa María': LatLng(-32.4075, -63.2402),
    'Villa Nueva': LatLng(-32.4333, -63.2667),
  };

  static LatLng? deCiudad(String? ciudad) {
    final c = ciudad?.trim() ?? '';
    if (c.isEmpty) return null;
    return _coords[c];
  }

  /// Distancia en km (Haversine).
  static double distanciaKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * (math.pi / 180.0);

  /// Ciudades hardcodeadas ([UbicacionesData]) dentro de [radioKm] del punto GPS.
  /// Ordenadas por cercanía. Si ninguna entra en el radio, devuelve solo la más cercana.
  static List<String> ciudadesCercanas({
    required double latitud,
    required double longitud,
    double radioKm = 20,
    String? provincia,
  }) {
    final origen = LatLng(latitud, longitud);
    final candidatos = <({String ciudad, String provincia, double km})>[];

    for (final entry in UbicacionesData.ciudadesPorProvincia.entries) {
      if (provincia != null &&
          provincia.isNotEmpty &&
          entry.key != provincia) {
        continue;
      }
      for (final ciudad in entry.value) {
        final coord = _coords[ciudad];
        if (coord == null) continue;
        final km = distanciaKm(origen, coord);
        candidatos.add((ciudad: ciudad, provincia: entry.key, km: km));
      }
    }

    if (candidatos.isEmpty) return const [];

    candidatos.sort((a, b) => a.km.compareTo(b.km));
    final dentro = candidatos.where((c) => c.km <= radioKm).toList();
    if (dentro.isNotEmpty) {
      return dentro.map((c) => c.ciudad).toList(growable: false);
    }
    return <String>[candidatos.first.ciudad];
  }

  /// Provincia canónica de una ciudad hardcodeada (o null).
  static String? provinciaDeCiudad(String ciudad) {
    for (final entry in UbicacionesData.ciudadesPorProvincia.entries) {
      if (entry.value.contains(ciudad)) return entry.key;
    }
    return null;
  }

  static LatLng centroDeCiudades(Set<String> ciudades) {
    if (ciudades.isEmpty) {
      return deCiudad(UbicacionesData.ciudadPorDefecto) ??
          const LatLng(-31.4201, -64.1888);
    }
    final puntos = ciudades
        .map(deCiudad)
        .whereType<LatLng>()
        .toList(growable: false);
    if (puntos.isEmpty) {
      return deCiudad(ciudades.first) ?? const LatLng(-31.4201, -64.1888);
    }
    if (puntos.length == 1) return puntos.first;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in puntos) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / puntos.length, lng / puntos.length);
  }

  /// Zoom sugerido según cantidad de ciudades seleccionadas.
  static double zoomParaCiudades(Set<String> ciudades) {
    if (ciudades.length <= 1) return 12.5;
    if (ciudades.length <= 3) return 11.0;
    return 10.0;
  }

  /// Pequeño offset determinístico para separar pines superpuestos.
  static LatLng conJitter(LatLng base, String semilla, {double metros = 35}) {
    final h = semilla.hashCode;
    final angle = (h % 360) * (math.pi / 180);
    final factor = ((h % 7) + 1) / 7.0;
    const mPorGradoLat = 111320.0;
    final mPorGradoLng =
        111320.0 * (0.85 + 0.15 * (base.latitude.abs() / 90));
    final dLat = (metros * factor * math.sin(angle)) / mPorGradoLat;
    final dLng = (metros * factor * math.cos(angle)) / mPorGradoLng;
    return LatLng(base.latitude + dLat, base.longitude + dLng);
  }
}
