/// ServicioPush — registro y manejo de notificaciones push (FCM).
///
/// Registra tokens FCM nativos (Android/iOS) y Web/PWA cuando existe config
/// Firebase Web. El token se ata al usuario logueado via edge
/// `registrar_push_token`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config_push_web.dart';
import '../models/notificacion.dart';
import 'navegacion_notificaciones.dart';
import 'push_web_helper.dart';
import 'servicio_notificaciones_usuarios.dart';

class ServicioPush {
  ServicioPush._();
  static final ServicioPush instancia = ServicioPush._();

  bool _inicializado = false;
  String? _ultimoTokenRegistrado;

  bool get soportado =>
      (kIsWeb && ConfigPushWeb.habilitada) ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  /// Se llama una vez tras inicializar Firebase (en main). Configura listeners
  /// de refresh y de mensajes en primer plano. No pide permiso todavía: eso
  /// ocurre cuando hay un usuario logueado (registrarParaUsuario()).
  Future<void> inicializar() async {
    if (_inicializado || !soportado) return;
    _inicializado = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registrarToken(token);
    });

    // Mensaje recibido con la app en primer plano: Android no muestra la
    // notificación del sistema automáticamente. Por ahora solo lo logueamos;
    // la UI in-app (campanita) ya cubre el detalle dentro de la app.
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      debugPrint('📩 Push en primer plano: ${msg.notification?.title}');
      if (kIsWeb) {
        unawaited(
          mostrarNotificacionForegroundWeb(
            titulo: msg.notification?.title ?? 'Fernecito',
            cuerpo: msg.notification?.body ?? '',
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_procesarPushAbierta);
    unawaited(_procesarPushInicial());
  }

  Future<void> _procesarPushInicial() async {
    try {
      final msg = await FirebaseMessaging.instance.getInitialMessage();
      if (msg != null) {
        // El navigator/auth pueden terminar de montarse unos frames después
        // del tap del sistema, especialmente viniendo de app terminada.
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _procesarPushAbierta(msg);
      }
    } catch (e) {
      debugPrint('⚠️ push inicial: $e');
    }
  }

  Future<void> _procesarPushAbierta(RemoteMessage msg) async {
    try {
      final n = await _resolverNotificacionDesdePush(msg);
      if (n == null) return;

      var abierta = false;
      for (var i = 0; i < 8 && !abierta; i++) {
        // Sin onIrATab: navegarDesdeNotificacion usa irATabHome del shell.
        abierta = await navegarDesdeNotificacion(n);
        if (!abierta) {
          await Future<void>.delayed(Duration(milliseconds: 250 + i * 150));
        }
      }
      if (abierta && n.id.isNotEmpty && !n.id.startsWith('push_')) {
        unawaited(ServicioNotificacionesUsuarios().marcarLeida(n.id));
      }
    } catch (e) {
      debugPrint('⚠️ abrir push: $e');
    }
  }

  Future<Notificacion?> _resolverNotificacionDesdePush(
    RemoteMessage msg,
  ) async {
    final data = msg.data;
    final idNotif = _leerData(data, ['id_notificacion', 'idNotif', 'notif_id']);
    if (idNotif != null && idNotif.isNotEmpty) {
      final real = await ServicioNotificacionesUsuarios().obtenerPorId(idNotif);
      if (real != null) return real;
    }

    final tipo = _leerData(data, ['tipo', 'type']) ?? '';
    final ruta = _leerData(data, ['cta_ruta', 'ruta', 'route']);
    final ref = _leerData(data, ['cta_id_ref', 'ref', 'id_ref']);
    final titulo =
        msg.notification?.title ??
        _leerData(data, ['titulo', 'title']) ??
        'Fernecito';
    final cuerpo =
        msg.notification?.body ??
        _leerData(data, ['descripcion', 'cuerpo', 'body']) ??
        '';
    final sinDestino =
        (ruta == null || ruta.isEmpty) && (ref == null || ref.isEmpty);
    if ((tipo.isEmpty && sinDestino) || _esPushSoloAbrirApp(tipo, sinDestino)) {
      return null; // Broadcast/owner: abrir la app alcanza.
    }

    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    return Notificacion(
      id: idNotif == null || idNotif.isEmpty
          ? 'push_${msg.messageId ?? DateTime.now().microsecondsSinceEpoch}'
          : idNotif,
      idUsuario: uid,
      tipo: tipo.isEmpty ? 'notificacion' : tipo,
      prioridad: _leerData(data, ['prioridad']) ?? 'media',
      titulo: titulo,
      descripcion: cuerpo,
      ctaRuta: ruta,
      ctaIdRef: ref,
      payload: data.isEmpty ? null : Map<String, dynamic>.from(data),
      leida: false,
      fechaCreacion: DateTime.now().toUtc(),
    );
  }

  String? _leerData(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool _esPushSoloAbrirApp(String tipo, bool sinDestino) {
    if (!sinDestino) return false;
    switch (tipo.trim().toLowerCase()) {
      case 'promo':
      case 'broadcast':
      case 'novedad':
      case 'novedad_owner':
      case 'campania':
      case 'campana':
      case 'notificacion':
        return true;
      default:
        return false;
    }
  }

  /// Pide permiso (Android 13+/iOS) y registra el token del usuario actual.
  /// Llamar tras un login exitoso. Idempotente.
  Future<bool> registrarParaUsuario() async {
    if (!soportado) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 Permiso push: ${settings.authorizationStatus.name}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('🔕 Permiso de notificaciones denegado');
        return false;
      }
      if (kIsWeb) {
        await asegurarServiceWorkerPush();
      }
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? ConfigPushWeb.vapidKey : null,
      );
      if (token != null && token.isNotEmpty) {
        await _registrarToken(token);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ registrarParaUsuario push: $e');
    }
    return false;
  }

  Future<bool> tienePermiso() async {
    if (!soportado) return false;
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<void> _registrarToken(String token) async {
    // Evitar registrar el mismo token repetidamente en la misma sesión.
    if (token == _ultimoTokenRegistrado) return;
    final sesion = Supabase.instance.client.auth.currentSession;
    if (sesion == null) return; // solo con usuario logueado
    try {
      await Supabase.instance.client.functions.invoke(
        'registrar_push_token',
        body: {
          'token': token,
          'app': 'usuarios',
          'plataforma': kIsWeb
              ? 'web'
              : (defaultTargetPlatform == TargetPlatform.iOS
                    ? 'ios'
                    : 'android'),
        },
      );
      _ultimoTokenRegistrado = token;
      debugPrint('✅ Token push registrado');
    } catch (e) {
      debugPrint('⚠️ registrar token push: $e');
    }
  }

  /// Al cerrar sesión: olvidar el token local (best-effort) para no re-registrar
  /// contra el usuario anterior.
  void olvidarLocal() {
    _ultimoTokenRegistrado = null;
  }
}
