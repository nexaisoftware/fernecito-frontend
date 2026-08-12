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

  /// Pool semanal de hasta [limite] locales para las ciudades activas del usuario.
  Future<List<LocalCarteleraCard>> obtenerPorCiudades(
    Iterable<String> ciudades, {
    int limite = limiteDefault,
  }) async {
    final lista = ciudades
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
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
