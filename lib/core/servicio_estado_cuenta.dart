/// Estado de cuenta del usuario (activa / pausada) vía RPC mi_estado_cuenta.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'motivos_pausa_cuenta.dart';

class ServicioEstadoCuenta extends ChangeNotifier {
  ServicioEstadoCuenta._();
  static final ServicioEstadoCuenta instancia = ServicioEstadoCuenta._();

  bool _suspendida = false;
  String? _motivoLabel;
  bool _cargando = false;
  bool _notifyPendiente = false;
  DateTime? _ultimoRefreshAt;
  static const _ttl = Duration(minutes: 2);

  bool get suspendida => _suspendida;
  String? get motivoLabel => _motivoLabel;
  bool get cargando => _cargando;

  /// Evita `notifyListeners` durante el build (p. ej. ListenableBuilder en app.dart).
  void _notifyListenersSeguro() {
    if (!hasListeners || _notifyPendiente) return;
    _notifyPendiente = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyPendiente = false;
      if (hasListeners) notifyListeners();
    });
  }

  /// Refresca desde backend. Devuelve true si la cuenta sigue pausada.
  /// [forzar] ignora TTL (p. ej. pull o acción crítica).
  Future<bool> refrescar({bool forzar = false}) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _suspendida = false;
      _motivoLabel = null;
      _ultimoRefreshAt = null;
      _notifyListenersSeguro();
      return false;
    }

    if (!forzar &&
        _ultimoRefreshAt != null &&
        DateTime.now().difference(_ultimoRefreshAt!) < _ttl) {
      return _suspendida;
    }

    _cargando = true;

    // IMPORTANTE: en la app de USUARIO leemos perfiles_usuarios DIRECTO.
    // No usamos la RPC mi_estado_cuenta porque ésta prioriza perfiles_locales:
    // si la misma cuenta tiene además un perfil de local (cuentas de test/owner),
    // devolvería el estado del LOCAL (activa) y jamás detectaríamos la pausa del
    // USUARIO. El estado del usuario es la única verdad acá. La política RLS
    // "Usuarios ven su propio perfil completo" garantiza esta lectura.
    try {
      final row = await Supabase.instance.client
          .from('perfiles_usuarios')
          .select('estado_cuenta, pausada_motivo_publico')
          .eq('id', uid)
          .maybeSingle();
      final estado = row?['estado_cuenta']?.toString() ?? 'activa';
      _suspendida = estado != 'activa';
      _motivoLabel = _suspendida
          ? etiquetaMotivoPublico(row?['pausada_motivo_publico']?.toString())
          : null;
    } catch (_) {
      _suspendida = false;
      _motivoLabel = null;
    } finally {
      _cargando = false;
      _ultimoRefreshAt = DateTime.now();
      _notifyListenersSeguro();
    }
    return _suspendida;
  }

  void limpiar() {
    _suspendida = false;
    _motivoLabel = null;
    _ultimoRefreshAt = null;
    _notifyListenersSeguro();
  }
}
