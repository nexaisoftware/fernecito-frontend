library;

import 'package:flutter/foundation.dart';

import '../models/tendencia_social.dart';
import 'rpc_resiliente.dart';
import 'supabase_client.dart';

class ServicioTendenciasSocial {
  /// Último ranking bueno: si una llamada falla (red, sesión), la sección
  /// conserva lo anterior en vez de quedar vacía.
  static List<LocalTendenciaSocial> _ultimoBueno = const [];
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
      final response = await rpcConReintento(
        () => ServicioSupabase().cliente.rpc(
        'social_locales_ranking_semanal',
        params: {
          'p_ciudades': ciudades.isEmpty ? null : ciudades.toList(),
          'p_provincia': provincia,
          'p_limite': limite,
        },
      ),
        etiqueta: 'tendencias_locales',
      );
      if (response is! List) return _ultimoBueno;
      final lista = response
          .map(
            (item) => LocalTendenciaSocial.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((item) => item.idLocal.isNotEmpty)
          .toList(growable: false);
      // Si el backend devolvió vacío (cache en refresh, glitch puntual),
      // conservamos el último ranking bueno para no vaciar Social.
      if (lista.isEmpty) return _ultimoBueno;
      _ultimoBueno = lista;
      return lista;
    } catch (error) {
      // La UI degrada silenciosamente si el RPC todavía no fue desplegado.
      debugPrint('⚠️ social_locales_tendencia: $error');
      // No vaciamos la sección por un fallo puntual.
      return _ultimoBueno;
    }
  }
}
