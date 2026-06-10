library;

import 'package:flutter/foundation.dart';
import '../models/notificacion.dart';
import 'supabase_client.dart';

/// Servicio singleton para leer / marcar / borrar notificaciones del usuario.
///
/// Espejo de `ServicioNotificacionesLocales`. Expone un
/// `ValueNotifier<int> contadorNoLeidas` para badges reactivos (bottom nav, etc.).
class ServicioNotificacionesUsuarios {
  static final ServicioNotificacionesUsuarios _instancia =
      ServicioNotificacionesUsuarios._interno();
  factory ServicioNotificacionesUsuarios() => _instancia;
  ServicioNotificacionesUsuarios._interno();

  /// Total de notificaciones no leídas del usuario actual (para badge).
  final ValueNotifier<int> contadorNoLeidas = ValueNotifier<int>(0);

  String? get _uid => ServicioSupabase().usuarioActual?.id;

  /// Lista las notificaciones del usuario actual (más recientes primero).
  /// Filtra automáticamente las expiradas.
  Future<List<Notificacion>> listar({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return const [];

    try {
      final data = await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .select()
          .eq('id_usuario', uid)
          .gte('fecha_expiracion', DateTime.now().toUtc().toIso8601String())
          .order('fecha_creacion', ascending: false)
          .limit(limit);

      return (data as List)
          .cast<Map<String, dynamic>>()
          .map(Notificacion.fromMap)
          .toList();
    } catch (e) {
      debugPrint('⚠️ listar notificaciones usuario: $e');
      return const [];
    }
  }

  /// Sincroniza el badge con una lista ya cargada.
  void sincronizarDesdeLista(List<Notificacion> lista) {
    contadorNoLeidas.value = lista.where((n) => !n.leida).length;
  }

  /// Refresca el contador de no leídas (consulta puntual).
  Future<int> refrescarContador() async {
    final uid = _uid;
    if (uid == null) {
      contadorNoLeidas.value = 0;
      return 0;
    }
    try {
      final rows = await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .select('id')
          .eq('id_usuario', uid)
          .eq('leida', false)
          .gte('fecha_expiracion', DateTime.now().toUtc().toIso8601String());
      final count = (rows as List).length;
      contadorNoLeidas.value = count;
      return count;
    } catch (e) {
      debugPrint('⚠️ refrescarContador usuario: $e');
      return contadorNoLeidas.value;
    }
  }

  /// Marca una notificación específica como leída (idempotente).
  Future<bool> marcarLeida(String idNotif) async {
    try {
      await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .update({
            'leida': true,
            'fecha_lectura': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', idNotif)
          .eq('leida', false);
      return true;
    } catch (e) {
      debugPrint('⚠️ marcarLeida usuario: $e');
      return false;
    }
  }

  /// Marca todas las no-leídas del usuario como leídas.
  Future<bool> marcarTodasLeidas() async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .update({
            'leida': true,
            'fecha_lectura': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id_usuario', uid)
          .eq('leida', false);
      contadorNoLeidas.value = 0;
      return true;
    } catch (e) {
      debugPrint('⚠️ marcarTodasLeidas usuario: $e');
      return false;
    }
  }

  /// Borra una notificación (deja al usuario "limpiar" su feed).
  Future<bool> borrar(String idNotif) async {
    try {
      await ServicioSupabase().cliente
          .from('notificaciones_usuarios')
          .delete()
          .eq('id', idNotif);
      await refrescarContador();
      return true;
    } catch (e) {
      debugPrint('⚠️ borrar notif usuario: $e');
      return false;
    }
  }
}
