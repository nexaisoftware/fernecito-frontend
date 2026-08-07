library;

import 'package:flutter/foundation.dart';

import '../models/tendencia_social.dart';
import 'supabase_client.dart';

class ServicioTendenciasSocial {
  Future<List<LocalTendenciaSocial>> listarLocales({
    Set<String> ciudades = const {},
    String? provincia,
    int dias = 7,
    int limite = 5,
  }) async {
    try {
      // Ranking semanal: puntaje base (completitud de perfil) + interacciones
      // de los últimos 7 días (vistas/clicks de flyers, visitas, likes,
      // reseñas y flyers activos).
      final response = await ServicioSupabase().cliente.rpc(
        'social_locales_ranking_semanal',
        params: {
          'p_ciudades': ciudades.isEmpty ? null : ciudades.toList(),
          'p_provincia': provincia,
          'p_limite': limite,
        },
      );
      if (response is! List) return const [];
      return response
          .map(
            (item) => LocalTendenciaSocial.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((item) => item.idLocal.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      // La UI degrada silenciosamente si el RPC todavía no fue desplegado.
      debugPrint('⚠️ social_locales_tendencia: $error');
      return const [];
    }
  }
}
