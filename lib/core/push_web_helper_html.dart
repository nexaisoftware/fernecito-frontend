import 'dart:html' as html;

/// Registra el SW de FCM (distinto del flutter_service_worker de cache).
Future<void> asegurarServiceWorkerPush() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return;
  try {
    await sw.register('/firebase-messaging-sw.js');
  } catch (_) {}
}

/// Tab visible: FCM no muestra banner solo; lo hacemos acá.
Future<void> mostrarNotificacionForegroundWeb({
  required String titulo,
  String cuerpo = '',
}) async {
  if (!html.Notification.supported) return;
  if (html.Notification.permission != 'granted') return;
  try {
    html.Notification(titulo, body: cuerpo, icon: '/icons/apple-touch-icon.png');
  } catch (_) {}
}
