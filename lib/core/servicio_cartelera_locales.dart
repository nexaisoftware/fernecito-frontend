/// Consulta cards semanales de locales para rellenar cartelera.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/local_cartelera_card.dart';
import 'supabase_client.dart';

class ServicioCarteleraLocales {
  ServicioCarteleraLocales._();
  static final ServicioCarteleraLocales instancia = ServicioCarteleraLocales._();

  static const int limiteDefault = 12;

  /// Expande aliases (Córdoba ↔ Córdoba capital) para que la RPC encuentre
  /// cards guardadas con cualquiera de las variantes.
  static List<String> expandirCiudadesQuery(Iterable<String> ciudades) {
    final out = <String>{};
    for (final raw in ciudades) {
      final c = raw.trim();
      if (c.isEmpty) continue;
      out.add(c);
      final n = _normCiudad(c);
      if (_esGrupoCordoba(n)) {
        out.addAll(const [
          'Córdoba',
          'Córdoba capital',
          'Cordoba',
          'Cordoba capital',
        ]);
      }
    }
    return out.toList();
  }

  static String _normCiudad(String c) => c
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'\s+'), ' ');

  static bool _esGrupoCordoba(String norm) =>
      norm == 'cordoba' || norm == 'cordoba capital' || norm == 'cba';

  /// Pool semanal de hasta [limite] locales para las ciudades activas del usuario.
  /// Toma el top global entre las cards de esas ciudades (máx 12 en total).
  Future<List<LocalCarteleraCard>> obtenerPorCiudades(
    Iterable<String> ciudades, {
    int limite = limiteDefault,
  }) async {
    final lista = expandirCiudadesQuery(ciudades);
    if (lista.isEmpty) return const [];

    try {
      final sb = ServicioSupabase().cliente;
      final data = await sb.rpc(
        'cartelera_local_cards_por_ubicacion',
        params: {
          'p_ciudades': lista,
          'p_limite': limite.clamp(1, limiteDefault),
        },
      );
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => LocalCarteleraCard.fromMap(Map<String, dynamic>.from(e)))
          .where((c) => c.localId.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      // Aditivo: si la RPC aún no está desplegada, no romper cartelera.
      debugPrint('⚠️ cartelera_local_cards_por_ubicacion: ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('⚠️ cartelera locales: $e');
      return const [];
    }
  }
}
