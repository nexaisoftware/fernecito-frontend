library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rompehielo.dart';
import 'chat_paginacion.dart';
import 'supabase_client.dart';

class ConversacionMensaje {
  const ConversacionMensaje({
    required this.id,
    required this.idAutor,
    required this.cuerpo,
    required this.creadoEn,
  });

  final int id;
  final String idAutor;
  final String cuerpo;
  final DateTime creadoEn;

  factory ConversacionMensaje.fromMap(Map<String, dynamic> m) =>
      ConversacionMensaje(
        id: m['id'] is num
            ? (m['id'] as num).toInt()
            : int.tryParse(m['id']?.toString() ?? '') ?? 0,
        idAutor: m['id_autor']?.toString() ?? '',
        cuerpo: m['cuerpo']?.toString() ?? '',
        creadoEn:
            DateTime.tryParse(m['creado_en']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class ServicioConversaciones {
  static final ServicioConversaciones _instancia =
      ServicioConversaciones._interno();
  factory ServicioConversaciones() => _instancia;
  ServicioConversaciones._interno();

  SupabaseClient get _c => ServicioSupabase().cliente;
  String? get miUid => ServicioSupabase().usuarioActual?.id;

  Future<({RompehieloEstado? estado, String? error})> solicitar(
    String otroId,
  ) async {
    if (otroId.isEmpty) return (estado: null, error: 'destino_invalido');
    try {
      final res = await _c.rpc(
        'conversacion_solicitar',
        params: {'p_otro_id': otroId},
      );
      if (res is Map) {
        return (
          estado: RompehieloEstado.fromMap(Map<String, dynamic>.from(res)),
          error: null,
        );
      }
      return (estado: null, error: 'respuesta_invalida');
    } catch (e) {
      debugPrint('⚠️ conversacion_solicitar: $e');
      return (estado: null, error: _codigo(e));
    }
  }

  Future<({RompehieloEstado? estado, String? error})> responder({
    required String idConversacion,
    required bool aceptar,
  }) async {
    if (idConversacion.isEmpty) {
      return (estado: null, error: 'id_invalido');
    }
    try {
      final res = await _c.rpc(
        'conversacion_responder',
        params: {'p_id': idConversacion, 'p_aceptar': aceptar},
      );
      if (res is Map) {
        return (
          estado: RompehieloEstado.fromMap(Map<String, dynamic>.from(res)),
          error: null,
        );
      }
      return (estado: null, error: 'respuesta_invalida');
    } catch (e) {
      debugPrint('⚠️ conversacion_responder: $e');
      return (estado: null, error: _codigo(e));
    }
  }

  Future<int?> enviarMensaje(String idConversacion, String cuerpo) async {
    final res = await _c.rpc(
      'conversacion_enviar_mensaje',
      params: {'p_id': idConversacion, 'p_cuerpo': cuerpo},
    );
    if (res is Map && res['id'] != null) {
      final id = res['id'];
      return id is num ? id.toInt() : int.tryParse(id.toString());
    }
    return null;
  }

  Future<void> marcarLeido(String idConversacion) async {
    try {
      await _c.rpc(
        'conversacion_marcar_leido',
        params: {'p_id': idConversacion},
      );
    } catch (e) {
      debugPrint('⚠️ conversacion_marcar_leido: $e');
    }
  }

  Future<PaginaChatMensajes<ConversacionMensaje>> historial(
    String idConversacion,
  ) async {
    final limite = kChatMensajesPorPagina;
    final rows = await _c
        .from('conversacion_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_conversacion', idConversacion)
        .order('id', ascending: false)
        .limit(limite + 1);
    final parsed = (rows as List)
        .map(
          (e) =>
              ConversacionMensaje.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return armarPaginaAsc(parsed, limite);
  }

  Future<PaginaChatMensajes<ConversacionMensaje>> historialAntesDe(
    String idConversacion,
    int antesDeId,
  ) async {
    final limite = kChatMensajesPorPagina;
    final rows = await _c
        .from('conversacion_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_conversacion', idConversacion)
        .lt('id', antesDeId)
        .order('id', ascending: false)
        .limit(limite + 1);
    final parsed = (rows as List)
        .map(
          (e) =>
              ConversacionMensaje.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return armarPaginaAsc(parsed, limite);
  }

  Future<List<ConversacionMensaje>> mensajesDespuesDe(
    String idConversacion,
    int ultimoId,
  ) async {
    final rows = await _c
        .from('conversacion_mensajes')
        .select('id, id_autor, cuerpo, creado_en')
        .eq('id_conversacion', idConversacion)
        .gt('id', ultimoId)
        .order('id', ascending: true)
        .limit(80);
    return (rows as List)
        .map(
          (e) =>
              ConversacionMensaje.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  RealtimeChannel suscribirMensajes(
    String idConversacion,
    void Function(ConversacionMensaje) onMensaje,
  ) {
    return _c
        .channel('conversacion_chat_$idConversacion')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'conversacion_mensajes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id_conversacion',
            value: idConversacion,
          ),
          callback: (payload) {
            onMensaje(
              ConversacionMensaje.fromMap(
                Map<String, dynamic>.from(payload.newRecord),
              ),
            );
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⚠️ conversacion realtime: $status $error');
            unawaited(
              Supabase.instance.client.auth.refreshSession().then(
                (_) {},
                onError: (_) {},
              ),
            );
          }
        });
  }

  Future<void> cerrarCanal(RealtimeChannel canal) async {
    await _c.removeChannel(canal);
  }

  String _codigo(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('chat_no_desbloqueado')) return 'chat_no_desbloqueado';
    if (msg.contains('ya_pendiente')) return 'ya_pendiente';
    if (msg.contains('rompehielo_ignorado')) return 'rompehielo_ignorado';
    if (msg.contains('sos_solicitante')) return 'sos_solicitante';
    if (msg.contains('ya_respondida')) return 'ya_respondida';
    if (msg.contains('no_participante')) return 'no_participante';
    if (msg.contains('rate')) return 'rate_limit';
    return 'error';
  }

  String mensajeError(String? codigo, {String accion = 'completar esto'}) {
    switch (codigo) {
      case 'chat_no_desbloqueado':
        return 'Todavía no llegaron a 5 mensajes de cada lado.';
      case 'ya_pendiente':
        return 'Ya hay una solicitud de chat pendiente.';
      case 'rompehielo_ignorado':
        return 'Este rompehielo está ignorado.';
      case 'sos_solicitante':
        return 'Quien pide el chat no puede aceptarlo.';
      case 'ya_respondida':
        return 'Esta solicitud ya se respondió.';
      case 'no_participante':
        return 'Este chat ya no está disponible.';
      case 'rate_limit':
        return 'Esperá un toque y volvé a intentar.';
      default:
        return 'No pude $accion. Probá de nuevo.';
    }
  }
}
