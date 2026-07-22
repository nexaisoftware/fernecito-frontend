/// Cliente de la edge `buscar_recomendaciones_ia` (Grok + Supabase).
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class RecomendacionIa {
  const RecomendacionIa({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.porQue,
    this.tags = const [],
    this.promoBadges = const [],
    this.imagenUrl,
    this.ciudad,
    this.tipoEvento,
    this.fechaInicio,
    this.idLocal,
    this.nombreLocal,
    this.rubro,
    this.avatarUrl,
    this.verificado = false,
    this.esPionero = false,
    this.calificacionPromedio,
    this.calificacionCantidad,
  });

  /// `evento` | `local`
  final String tipo;
  final String id;
  final String titulo;
  final String porQue;
  final List<String> tags;
  final List<String> promoBadges;
  final String? imagenUrl;
  final String? ciudad;
  final String? tipoEvento;
  final String? fechaInicio;
  final String? idLocal;
  final String? nombreLocal;
  final String? rubro;
  final String? avatarUrl;
  final bool verificado;
  final bool esPionero;
  final double? calificacionPromedio;
  final int? calificacionCantidad;

  bool get esEvento => tipo == 'evento';
  bool get esLocal => tipo == 'local';

  factory RecomendacionIa.fromJson(Map<String, dynamic> j) {
    final tagsRaw = j['tags'];
    final promoBadgesRaw = j['promo_badges'];
    double? cal;
    final calRaw = j['calificacion_promedio'];
    if (calRaw is num) {
      cal = calRaw.toDouble();
    } else if (calRaw != null) {
      cal = double.tryParse(calRaw.toString());
    }
    int? cant;
    final cantRaw = j['calificacion_cantidad'];
    if (cantRaw is num) {
      cant = cantRaw.toInt();
    } else if (cantRaw != null) {
      cant = int.tryParse(cantRaw.toString());
    }
    return RecomendacionIa(
      tipo: (j['tipo']?.toString() ?? 'evento').toLowerCase(),
      id: j['id']?.toString() ?? '',
      titulo: j['titulo']?.toString() ?? '',
      porQue: j['por_que']?.toString() ?? '',
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
          : const [],
      promoBadges: promoBadgesRaw is List
          ? promoBadgesRaw
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .take(3)
                .toList()
          : const [],
      imagenUrl: j['imagen_url']?.toString(),
      ciudad: j['ciudad']?.toString(),
      tipoEvento: j['tipo_evento']?.toString(),
      fechaInicio: j['fecha_inicio']?.toString(),
      idLocal: j['id_local']?.toString(),
      nombreLocal: j['nombre_local']?.toString(),
      rubro: j['rubro']?.toString(),
      avatarUrl: j['avatar_url']?.toString(),
      verificado: j['verificado'] == true,
      esPionero: j['es_pionero'] == true,
      calificacionPromedio: cal,
      calificacionCantidad: cant,
    );
  }
}

class ResultadoBusquedaIa {
  const ResultadoBusquedaIa({
    required this.ok,
    this.recomendados = const [],
    this.mensaje,
    this.nota,
    this.error,
    this.code,
    this.nombreUsuario,
  });

  final bool ok;
  final List<RecomendacionIa> recomendados;

  /// Mensaje amistoso de la IA (o error amable).
  final String? mensaje;
  final String? nota;
  final String? error;
  final String? code;
  final String? nombreUsuario;

  String get textoMostrar {
    final m = mensaje?.trim();
    if (m != null && m.isNotEmpty) return m;
    final e = error?.trim();
    if (e != null && e.isNotEmpty) return e;
    return 'Ups, no pude armar una respuesta ahora 😅';
  }

  factory ResultadoBusquedaIa.fromJson(Map<String, dynamic> j) {
    final list = j['recomendados'];
    return ResultadoBusquedaIa(
      ok: j['ok'] == true,
      recomendados: list is List
          ? list
                .whereType<Map>()
                .map(
                  (e) => RecomendacionIa.fromJson(Map<String, dynamic>.from(e)),
                )
                .where((r) => r.id.isNotEmpty)
                .toList()
          : const [],
      mensaje: j['mensaje']?.toString(),
      nota: j['nota']?.toString(),
      error: j['error']?.toString(),
      code: j['code']?.toString(),
      nombreUsuario: j['nombre_usuario']?.toString(),
    );
  }
}

class ServicioBusquedaIa {
  ServicioBusquedaIa._();
  static final instancia = ServicioBusquedaIa._();

  static const maxPregunta = 900;

  SupabaseClient get _sb => ServicioSupabase().cliente;

  Future<ResultadoBusquedaIa> buscar({
    required String pregunta,
    required Set<String> ciudades,
    List<Map<String, dynamic>> historial = const [],
    bool seguirConversacion = false,
  }) async {
    final q = pregunta.trim();
    if (q.length < 3) {
      return const ResultadoBusquedaIa(
        ok: false,
        error: 'Escribí un poco más qué querés hacer ✍️',
        code: 'pregunta_corta',
      );
    }
    if (q.length > maxPregunta) {
      return const ResultadoBusquedaIa(
        ok: false,
        error: 'Máximo 900 caracteres ✂️',
        code: 'pregunta_larga',
      );
    }
    if (ciudades.isEmpty) {
      return const ResultadoBusquedaIa(
        ok: false,
        error: 'Elegí una ciudad en la cartelera primero 📍',
        code: 'sin_ciudades',
      );
    }

    final session = _sb.auth.currentSession;
    if (session == null) {
      return const ResultadoBusquedaIa(
        ok: false,
        error: 'Iniciá sesión para usar la búsqueda IA 🔐',
        code: 'auth_required',
      );
    }

    try {
      final res = await _sb.functions.invoke(
        'buscar_recomendaciones_ia',
        body: {
          'pregunta': q,
          'ciudades': ciudades.toList(),
          'seguir': seguirConversacion,
          'historial': historial,
        },
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      final data = res.data;
      if (data is Map) {
        return ResultadoBusquedaIa.fromJson(Map<String, dynamic>.from(data));
      }
      return const ResultadoBusquedaIa(
        ok: false,
        mensaje:
            'Lo siento! 😅 Parece que los servidores están saturados. ¿Probamos más tarde?',
        code: 'invalid_response',
      );
    } on FunctionException catch (e) {
      debugPrint('[BusquedaIA] ✗ ${e.status} ${e.details}');
      final details = e.details;
      if (details is Map) {
        return ResultadoBusquedaIa.fromJson(Map<String, dynamic>.from(details));
      }
      if (e.status == 429) {
        final code = details is Map ? details['code']?.toString() : null;
        if (code == 'rate_daily') {
          return const ResultadoBusquedaIa(
            ok: false,
            mensaje:
                'Por hoy llegaste al tope de consultas nuevas 🙌 Mañana seguimos armando planes — o usá «Seguir conversación» en la misma charla ✨',
            code: 'rate_daily',
          );
        }
        return const ResultadoBusquedaIa(
          ok: false,
          mensaje:
              'Ey! ⏳ Estamos con muchas consultas ahora. Dale un respiro de unos segundos y volvé a preguntar ✨',
          code: 'rate_limited',
        );
      }
      return const ResultadoBusquedaIa(
        ok: false,
        mensaje:
            'Lo siento! 😅 No pude resolver tu duda ahora. Parece que los servidores están saturados. ¿Querés intentarlo más tarde?',
        code: 'function_error',
      );
    } catch (e) {
      debugPrint('[BusquedaIA] error: $e');
      return const ResultadoBusquedaIa(
        ok: false,
        mensaje:
            'Lo siento! 😅 Hubo un problema de conexión. ¿Probamos de nuevo en un rato?',
        code: 'network',
      );
    }
  }
}
