library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secciones_impresion.dart';
import 'supabase_client.dart';

/// Registro en memoria de cada impresión detectada en la sesión (auditoría local).
class RegistroImpresionSesion {
  const RegistroImpresionSesion({
    required this.idLocal,
    required this.seccion,
    required this.fecha,
    this.idEvento,
    this.delta = 1,
  });

  final String idLocal;
  final String? idEvento;
  final String seccion;
  final DateTime fecha;
  final int delta;
}

/// Cola de impresiones hacia Supabase con envío cada 30 s (máx ~2/min).
class ServicioImpresiones {
  ServicioImpresiones._();
  static final ServicioImpresiones instancia = ServicioImpresiones._();

  static const _intervaloMinimo = Duration(seconds: 30);
  /// Sentinel cuando no hay evento (perfil / card de local en cartelera).
  static const uuidSinEvento = '00000000-0000-0000-0000-000000000000';
  static const _uuidPerfilSentinel = uuidSinEvento;
  static const _maxHistorialSesion = 1000;

  final Map<String, int> _pendientes = {};
  final List<RegistroImpresionSesion> historialSesion = [];

  Timer? _timer;
  DateTime? _ultimoEnvio;
  bool _enviando = false;

  void asegurarTimer() {
    _timer ??= Timer.periodic(_intervaloMinimo, (_) => flush());
  }

  void detenerTimer() {
    _timer?.cancel();
    _timer = null;
  }

  static bool _esSinEvento(String seccion) =>
      seccion == SeccionesImpresion.perfilLocal ||
      seccion == SeccionesImpresion.cardLocal;

  String _clave(String idLocal, String? idEvento, String seccion) {
    final ev = _esSinEvento(seccion)
        ? _uuidPerfilSentinel
        : (idEvento ?? '');
    return '$idLocal|$ev|$seccion';
  }

  void registrar({
    required String idLocal,
    String? idEvento,
    required String seccion,
    int delta = 1,
  }) {
    final local = idLocal.trim();
    if (local.isEmpty || delta <= 0) return;
    if (ServicioSupabase().usuarioActual == null) return;
    // perfil_local / card_local: no requieren idEvento (sentinel en backend).
    if (!_esSinEvento(seccion) &&
        (idEvento == null || idEvento.trim().isEmpty)) {
      return;
    }

    asegurarTimer();

    historialSesion.add(
      RegistroImpresionSesion(
        idLocal: local,
        idEvento: idEvento?.trim(),
        seccion: seccion,
        fecha: DateTime.now(),
        delta: delta,
      ),
    );
    if (historialSesion.length > _maxHistorialSesion) {
      historialSesion.removeRange(
        0,
        historialSesion.length - _maxHistorialSesion,
      );
    }

    final k = _clave(local, idEvento, seccion);
    _pendientes[k] = (_pendientes[k] ?? 0) + delta;
  }

  void registrarCartelera({
    required String idLocal,
    required String idEvento,
    required String seccion,
  }) {
    registrar(idLocal: idLocal, idEvento: idEvento, seccion: seccion);
  }

  void registrarVisitaPerfil({required String idLocal}) {
    registrar(idLocal: idLocal, seccion: SeccionesImpresion.perfilLocal);
  }

  void registrarClickEvento({
    required String idLocal,
    required String idEvento,
  }) {
    registrar(
      idLocal: idLocal,
      idEvento: idEvento,
      seccion: SeccionesImpresion.clickEvento,
    );
  }

  /// Al salir de cartelera: solo envía si pasaron ≥30 s desde el último envío.
  Future<void> alSalirCartelera() => flush(respetarIntervalo: true);

  /// Envía la cola al backend. [respetarIntervalo] evita spam al cambiar de tab.
  Future<void> flush({bool respetarIntervalo = true}) async {
    if (_pendientes.isEmpty || _enviando) return;

    final ahora = DateTime.now();
    if (respetarIntervalo &&
        _ultimoEnvio != null &&
        ahora.difference(_ultimoEnvio!) < _intervaloMinimo) {
      return;
    }

    final snapshot = Map<String, int>.from(_pendientes);
    _pendientes.clear();
    _enviando = true;

    try {
      final items = snapshot.entries.map((e) {
        final partes = e.key.split('|');
        final idLocal = partes[0];
        final idEventoRaw = partes.length > 1 ? partes[1] : '';
        final seccion = partes.length > 2 ? partes[2] : '';
        final sinEvento = _esSinEvento(seccion);
        return {
          'id_local': idLocal,
          if (!sinEvento && idEventoRaw.isNotEmpty) 'id_evento': idEventoRaw,
          'seccion': seccion,
          'delta': e.value,
        };
      }).toList();

      final sb = ServicioSupabase().cliente;
      final session = sb.auth.currentSession;
      if (session == null) {
        _reintegrar(snapshot);
        return;
      }

      final itemsLimitados = items.map((item) {
        final copy = Map<String, dynamic>.from(item);
        final d = copy['delta'];
        if (d is num && d > 500) copy['delta'] = 500;
        return copy;
      }).toList();

      await sb.functions.invoke(
        'registrar_impresiones',
        body: {'items': itemsLimitados},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      _ultimoEnvio = DateTime.now();
    } on FunctionException catch (e) {
      debugPrint('⚠️ registrar_impresiones ${e.status}: ${e.details}');
      // Reintegrar siempre (incluye 429): el timer reintentará; no perder visitas.
      _reintegrar(snapshot);
    } catch (e) {
      debugPrint('⚠️ registrar_impresiones: $e');
      _reintegrar(snapshot);
    } finally {
      _enviando = false;
    }
  }

  void _reintegrar(Map<String, int> snapshot) {
    snapshot.forEach((k, v) {
      _pendientes[k] = (_pendientes[k] ?? 0) + v;
    });
  }
}
