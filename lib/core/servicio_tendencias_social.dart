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
    int limite = 10,
  }) async {
    try {
      // Top N entre las ciudades activas del usuario (manual o inteligente).
      // Backend: top 5 por ciudad materializado cada 3h + merge por score.
      // Score = puntos_base (perfil fijo) + métricas últimos 7 días.
      final response = await rpcConReintento(
        () => ServicioSupabase().cliente.rpc(
        'social_locales_ranking_semanal',
        params: {
          'p_ciudades': ciudades.isEmpty ? null : ciudades.toList(),
          'p_provincia': provincia,
          'p_limite': limite.clamp(1, 10),
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
      if (lista.isNotEmpty) _ultimoBueno = lista;
      return lista;
    } catch (error) {
      // La UI degrada silenciosamente si el RPC todavía no fue desplegado.
      debugPrint('⚠️ social_locales_tendencia: $error');
      // No vaciamos la sección por un fallo puntual.
      return _ultimoBueno;
    }
  }
}
