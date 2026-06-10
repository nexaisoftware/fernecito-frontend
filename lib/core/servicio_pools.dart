library;

import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

/// Datos del pool de un evento: quiénes van (individuos + squads).
class PoolData {
  /// Personas con reserva individual confirmada.
  final List<Map<String, dynamic>> personas;

  /// Squads con reserva confirmada (cada uno con sus miembros).
  final List<Map<String, dynamic>> squads;

  const PoolData({this.personas = const [], this.squads = const []});

  bool get vacio => personas.isEmpty && squads.isEmpty;
}

/// Servicio de Pools. Usa el RPC `evento_pool` (read-only) del backend.
class ServicioPools {
  static final ServicioPools _instancia = ServicioPools._interno();
  factory ServicioPools() => _instancia;
  ServicioPools._interno();

  /// Trae las personas y squads confirmados de un evento.
  Future<PoolData> pool(String idEvento) async {
    if (idEvento.isEmpty) return const PoolData();
    try {
      final res = await ServicioSupabase()
          .cliente
          .rpc('evento_pool', params: {'p_evento': idEvento});
      if (res is Map) {
        final personasRaw = res['personas'] as List? ?? const [];
        final squadsRaw = res['squads'] as List? ?? const [];
        return PoolData(
          personas: personasRaw
              .map((e) => _mapPersona(Map<String, dynamic>.from(e as Map)))
              .toList(),
          squads: squadsRaw
              .map((e) => _mapSquad(Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
      }
      return const PoolData();
    } catch (e) {
      debugPrint('⚠️ evento_pool: $e');
      return const PoolData();
    }
  }

  /// Convierte una persona del RPC al shape que consume la pantalla de Pools.
  Map<String, dynamic> _mapPersona(Map<String, dynamic> m, {String? squad}) {
    final username = (m['username'] as String?)?.trim() ?? '';
    return {
      'id_usuario': m['id_usuario'],
      'nombre': m['nombre'] ?? '',
      'username': username.isEmpty
          ? ''
          : (username.startsWith('@') ? username : '@$username'),
      'estado': m['mi_estado'] ?? '',
      'avatar': ServicioSupabase().urlAvatar(m['foto_perfil_url'] as String?) ?? '',
      'edad': m['edad'],
      'instagram_url': m['instagram_url'] ?? '',
      'tiktok_url': m['tiktok_url'] ?? '',
      'esDeSquad': squad != null,
      'squad': squad,
    };
  }

  /// Convierte un squad del RPC al shape que consume la pantalla de Pools.
  Map<String, dynamic> _mapSquad(Map<String, dynamic> m) {
    final nombre = m['nombre_grupo'] as String? ?? 'Squad';
    final miembrosRaw = m['miembros'] as List? ?? const [];
    return {
      'id_grupo': m['id_grupo'],
      'nombre': nombre,
      'estado': m['vibe_grupo'] ?? '',
      'miembros': miembrosRaw
          .map((e) =>
              _mapPersona(Map<String, dynamic>.from(e as Map), squad: nombre))
          .toList(),
    };
  }
}
