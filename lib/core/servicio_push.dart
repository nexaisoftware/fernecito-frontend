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
import 'push_web_helper.dart';

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
