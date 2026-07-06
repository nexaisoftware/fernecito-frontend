/// Reseña post-visita: tokens_asistencia.calificado (null | si | no | ignorado).
///
/// Usa RPC `tokens_pendientes_resena` porque la RLS de `eventos` solo permite
/// leer filas con `now() < fecha_fin` (los vencidos no son visibles al cliente).
library;

import 'package:flutter/foundation.dart';

import 'supabase_client.dart';

class PendienteResenaPostVisita {
  const PendienteResenaPostVisita({
    required this.idToken,
    required this.idLocal,
    required this.nombreLocal,
    this.avatarUrl,
    this.esPionero = false,
    this.idEvento,
    this.tituloEvento,
  });

  final String idToken;
  final String idLocal;
  final String nombreLocal;
  final String? avatarUrl;
  final bool esPionero;
  final String? idEvento;
  final String? tituloEvento;
}

class ServicioResenaPostVisita {
  ServicioResenaPostVisita._();
  static final instancia = ServicioResenaPostVisita._();

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  /// Marca el token: si | no | ignorado.
  Future<void> marcarCalificado(String idToken, String valor) async {
    if (idToken.isEmpty) return;
    try {
      await ServicioSupabase().cliente.rpc(
        'marcar_token_calificado',
        params: {
          'p_id_token': idToken,
          'p_calificado': valor,
        },
      );
    } catch (e) {
      debugPrint('⚠️ marcar_token_calificado($valor): $e');
    }
  }

  /// Un solo token con calificado IS NULL y evento terminado.
  Future<PendienteResenaPostVisita?> siguientePendiente() async {
    if (_uid == null) {
      debugPrint('[ResenaPostVisita] sin uid');
      return null;
    }

    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('tokens_pendientes_resena');

      debugPrint('[ResenaPostVisita] rpc raw=$res');
      if (res == null) return null;
      if (res is! Map) return null;

      final m = Map<String, dynamic>.from(res);
      final idToken = m['id_token']?.toString() ?? '';
      final idLocal = m['id_local']?.toString() ?? '';
      if (idToken.isEmpty || idLocal.isEmpty) return null;

      final nombre = (m['nombre_local']?.toString() ?? '').trim();
      return PendienteResenaPostVisita(
        idToken: idToken,
        idLocal: idLocal,
        nombreLocal: nombre.isNotEmpty ? nombre : 'este local',
        avatarUrl: _resolverAvatar(m['foto_perfil_url']?.toString()),
        esPionero: m['es_pionero'] == true,
        idEvento: m['id_evento']?.toString(),
        tituloEvento: m['titulo_evento']?.toString(),
      );
    } catch (e, st) {
      debugPrint('⚠️ tokens_pendientes_resena: $e\n$st');
      return null;
    }
  }

  String? _resolverAvatar(String? path) {
    final p = path?.trim() ?? '';
    if (p.isEmpty) return null;
    if (p.startsWith('http') || p.startsWith('assets/')) return p;
    return ServicioSupabase()
        .cliente
        .storage
        .from('perfiles-locales')
        .getPublicUrl(p);
  }
}
