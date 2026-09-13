/// Reserva / obtención de cupón de promo vía edge `reservar_promocion`.
///
/// Endurece el primer tap:
/// - refresca JWT vencido antes de invocar
/// - reintenta una vez en 401 / timeout de red
/// - si la edge ya creó el token (carrera / retry) lo recupera por SELECT
/// - mapea `code` de la edge a copy de UI
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'promos_hot.dart';
import 'supabase_client.dart';

class ResultadoReservarPromo {
  const ResultadoReservarPromo._({
    required this.ok,
    this.codigo,
    this.estadoToken,
    this.yaTenia = false,
    this.errorTitulo,
    this.errorMensaje,
    this.edgeCode,
  });

  final bool ok;
  final String? codigo;
  final String? estadoToken;
  final bool yaTenia;
  final String? errorTitulo;
  final String? errorMensaje;
  final String? edgeCode;

  factory ResultadoReservarPromo.exito({
    required String codigo,
    String estadoToken = 'activo',
    bool yaTenia = false,
  }) {
    return ResultadoReservarPromo._(
      ok: true,
      codigo: codigo,
      estadoToken: estadoToken,
      yaTenia: yaTenia,
    );
  }

  factory ResultadoReservarPromo.error({
    required String mensaje,
    String titulo = 'No se pudo obtener la promo',
    String? edgeCode,
  }) {
    return ResultadoReservarPromo._(
      ok: false,
      errorTitulo: titulo,
      errorMensaje: mensaje,
      edgeCode: edgeCode,
    );
  }
}

class ServicioReservarPromocion {
  ServicioReservarPromocion._();
  static final ServicioReservarPromocion instancia =
      ServicioReservarPromocion._();

  final Set<String> _enVuelo = <String>{};

  Future<Map<String, dynamic>?> fetchTokenPromo(String idPromo) async {
    final sb = ServicioSupabase().cliente;
    final userId = sb.auth.currentUser?.id;
    if (userId == null || idPromo.isEmpty) return null;
    const delays = [
      Duration(milliseconds: 180),
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
    ];
    for (var intento = 0; intento < delays.length; intento++) {
      try {
        final res = await sb
            .from('tokens_promociones')
            .select('id_promocion, token_codigo, estado_token')
            .eq('id_usuario', userId)
            .eq('id_promocion', idPromo)
            .inFilter('estado_token', kEstadosTokenPromoUsuario)
            .order('fecha_creacion', ascending: false)
            .limit(1);
        final lista = List<Map<String, dynamic>>.from(res as List);
        debugPrint(
          '[ReservarPromo] fetch token intento ${intento + 1}: ${lista.length} rows',
        );
        if (lista.isNotEmpty) return lista.first;
      } catch (e) {
        debugPrint('[ReservarPromo] fetch token error intento ${intento + 1}: $e');
      }
      if (intento < delays.length - 1) {
        await Future<void>.delayed(delays[intento]);
      }
    }
    return null;
  }

  Future<void> _asegurarSesion() async {
    final sb = ServicioSupabase().cliente;
    final session = sb.auth.currentSession;
    if (session == null) return;
    if (session.isExpired) {
      await sb.auth.refreshSession();
    }
  }

  Future<ResultadoReservarPromo> reservar({
    required String idPromocion,
    String? idEvento,
  }) async {
    if (idPromocion.isEmpty) {
      return ResultadoReservarPromo.error(
        mensaje: 'No se pudo identificar la promo.',
      );
    }
    if (_enVuelo.contains(idPromocion)) {
      return ResultadoReservarPromo.error(
        mensaje: 'Ya estamos obteniendo esta promo.',
      );
    }
    _enVuelo.add(idPromocion);
    try {
      return await _reservarInterno(
        idPromocion: idPromocion,
        idEvento: idEvento,
      );
    } finally {
      _enVuelo.remove(idPromocion);
    }
  }

  Future<ResultadoReservarPromo> _reservarInterno({
    required String idPromocion,
    String? idEvento,
  }) async {
    final sb = ServicioSupabase().cliente;
    if (sb.auth.currentUser?.id == null) {
      return ResultadoReservarPromo.error(
        mensaje: 'Tu sesión expiró. Cerrá sesión y volvé a entrar.',
        edgeCode: 'invalid_jwt',
      );
    }

    try {
      await _asegurarSesion();
    } catch (e) {
      debugPrint('[ReservarPromo] refresh sesión: $e');
    }

    final ya = await fetchTokenPromo(idPromocion);
    if (ya != null) {
      final codigo = ya['token_codigo']?.toString() ?? '';
      if (codigo.isNotEmpty) {
        return ResultadoReservarPromo.exito(
          codigo: codigo,
          estadoToken: ya['estado_token']?.toString().toLowerCase() ?? 'activo',
          yaTenia: true,
        );
      }
    }

    final body = <String, dynamic>{
      'id_promocion': idPromocion,
      if (idEvento != null && idEvento.isNotEmpty) 'id_evento': idEvento,
    };

    Object? ultimoError;
    int? ultimoStatus;

    for (var intento = 0; intento < 2; intento++) {
      try {
        if (intento == 1) {
          try {
            await sb.auth.refreshSession();
          } catch (e) {
            debugPrint('[ReservarPromo] refresh en retry: $e');
          }
        }
        final edgeResponse = await sb.functions.invoke(
          'reservar_promocion',
          body: body,
        );
        debugPrint(
          '[ReservarPromo] status=${edgeResponse.status} data=${edgeResponse.data}',
        );
        ultimoStatus = edgeResponse.status;
        final data = edgeResponse.data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final okBody = map['ok'];
          final okTruthy =
              okBody == true ||
              okBody == 1 ||
              (okBody is String && okBody.toLowerCase() == 'true');
          final code = (map['code'] ?? '').toString();
          if (edgeResponse.status >= 400 || (okBody != null && !okTruthy)) {
            ultimoError = map;
            if (_esAuth(edgeResponse.status, code) && intento == 0) {
              continue;
            }
            if (errorPromoDuplicada(map)) {
              final token = await fetchTokenPromo(idPromocion);
              if (token != null) {
                return ResultadoReservarPromo.exito(
                  codigo: token['token_codigo']?.toString() ?? '',
                  estadoToken:
                      token['estado_token']?.toString().toLowerCase() ??
                      'activo',
                  yaTenia: true,
                );
              }
            }
            break;
          }
        }
        final token = await fetchTokenPromo(idPromocion);
        if (token != null) {
          return ResultadoReservarPromo.exito(
            codigo: token['token_codigo']?.toString() ?? '',
            estadoToken:
                token['estado_token']?.toString().toLowerCase() ?? 'activo',
          );
        }
        // Edge 2xx pero el SELECT todavía no ve el token: un retry corto.
        final tarde = await fetchTokenPromo(idPromocion);
        if (tarde != null) {
          return ResultadoReservarPromo.exito(
            codigo: tarde['token_codigo']?.toString() ?? '',
            estadoToken:
                tarde['estado_token']?.toString().toLowerCase() ?? 'activo',
          );
        }
        return ResultadoReservarPromo.exito(
          codigo: '',
          estadoToken: 'activo',
        );
      } on FunctionException catch (fe) {
        debugPrint(
          '[ReservarPromo] FunctionException status=${fe.status} details=${fe.details}',
        );
        ultimoError = fe.details ?? fe;
        ultimoStatus = fe.status;
        if (errorPromoDuplicada(fe.details)) {
          final token = await fetchTokenPromo(idPromocion);
          if (token != null) {
            return ResultadoReservarPromo.exito(
              codigo: token['token_codigo']?.toString() ?? '',
              estadoToken:
                  token['estado_token']?.toString().toLowerCase() ?? 'activo',
              yaTenia: true,
            );
          }
        }
        final code = codigoEdgePromo(fe.details);
        if (_esAuth(fe.status, code) && intento == 0) continue;
        if (_esTransitorio(fe.status, fe.details) && intento == 0) continue;
        // Recuperación: la edge pudo haber insertado igual.
        final recovered = await fetchTokenPromo(idPromocion);
        if (recovered != null) {
          return ResultadoReservarPromo.exito(
            codigo: recovered['token_codigo']?.toString() ?? '',
            estadoToken:
                recovered['estado_token']?.toString().toLowerCase() ??
                'activo',
            yaTenia: true,
          );
        }
        break;
      } catch (e, st) {
        debugPrint('[ReservarPromo] invoke error: $e\n$st');
        ultimoError = e;
        if (_esTransitorio(null, e) && intento == 0) continue;
        final recovered = await fetchTokenPromo(idPromocion);
        if (recovered != null) {
          return ResultadoReservarPromo.exito(
            codigo: recovered['token_codigo']?.toString() ?? '',
            estadoToken:
                recovered['estado_token']?.toString().toLowerCase() ??
                'activo',
            yaTenia: true,
          );
        }
        break;
      }
    }

    return ResultadoReservarPromo.error(
      mensaje: mensajePromoAmigable(ultimoError, ultimoStatus),
      edgeCode: codigoEdgePromo(ultimoError),
    );
  }

  bool _esAuth(int? status, String code) {
    final c = code.toLowerCase();
    return status == 401 ||
        c == 'invalid_jwt' ||
        c == 'missing_authorization' ||
        c.contains('jwt');
  }

  bool _esTransitorio(int? status, Object? details) {
    if (status == 408 || status == 429 || status == 503 || status == 504) {
      return true;
    }
    final s = details?.toString().toLowerCase() ?? '';
    return s.contains('timeout') ||
        s.contains('socket') ||
        s.contains('network') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused');
  }
}
