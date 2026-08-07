/// Ranking semanal de usuarios (Explorar) — mismo motor que el de locales:
/// puntaje base por perfil completo + interacciones de los últimos 7 días,
/// servido desde un cache de ~6 horas en el backend.
library;

import 'package:flutter/foundation.dart';

import 'rpc_resiliente.dart';
import 'supabase_client.dart';

class UsuarioRanking {
  const UsuarioRanking({
    required this.idUsuario,
    required this.nombre,
    required this.score,
    this.username,
    this.fotoPath,
    this.estado,
    this.ciudad,
    this.puntosBase = 0,
    this.puntosSemana = 0,
  });

  final String idUsuario;
  final String nombre;
  final String? username;
  final String? fotoPath;

  /// Burbuja de estado ("nos conocemos?", "birrita??", …).
  final String? estado;
  final String? ciudad;
  final int score;
  final int puntosBase;
  final int puntosSemana;

  String? get fotoUrl => ServicioSupabase().urlAvatar(fotoPath);

  /// Primer nombre para las tarjetas del podio.
  String get nombreCorto {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return username ?? 'Usuario';
    return limpio.split(RegExp(r'\s+')).first;
  }

  factory UsuarioRanking.fromMap(Map<String, dynamic> m) {
    int n(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    final nombre = m['nombre']?.toString().trim();
    return UsuarioRanking(
      idUsuario: m['id_usuario']?.toString() ?? '',
      nombre: (nombre != null && nombre.isNotEmpty)
          ? nombre
          : (m['username']?.toString() ?? 'Usuario'),
      username: m['username']?.toString(),
      fotoPath: m['foto_perfil_url']?.toString(),
      estado: m['mi_estado']?.toString(),
      ciudad: m['ciudad']?.toString(),
      score: n(m['score']),
      puntosBase: n(m['puntos_base']),
      puntosSemana: n(m['puntos_semana']),
    );
  }
}

class ServicioRankingUsuarios {
  /// Último ranking bueno: ante un fallo puntual (red, sesión vencida) la
  /// sección conserva lo anterior en vez de desaparecer.
  static List<UsuarioRanking> _ultimoBueno = const [];

  Future<List<UsuarioRanking>> listar({
    Set<String> ciudades = const {},
    String? provincia,
    int limite = 6,
  }) async {
    try {
      final res = await rpcConReintento(
        () => ServicioSupabase().cliente.rpc(
        'social_usuarios_ranking_semanal',
        params: {
          'p_ciudades': ciudades.isEmpty ? null : ciudades.toList(),
          'p_provincia': provincia,
          'p_limite': limite,
        },
      ),
        etiqueta: 'ranking_usuarios',
      );
      if (res is! List) return _ultimoBueno;
      final lista = res
          .map((e) => UsuarioRanking.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((u) => u.idUsuario.isNotEmpty)
          .toList(growable: false);
      // Respuesta vacía puntual: no borramos el podio si ya teníamos datos.
      if (lista.isEmpty) return _ultimoBueno;
      _ultimoBueno = lista;
      return lista;
    } catch (e) {
      debugPrint('⚠️ social_usuarios_ranking_semanal: $e');
      // No vaciamos la sección por un fallo puntual.
      return _ultimoBueno;
    }
  }
}
