/// Llamadas a RPC tolerantes a sesión vencida.
///
/// Problema que resuelve: si el JWT venció (la app quedó abierta un rato, o
/// la PWA estuvo en segundo plano y no corrió el auto-refresh), la RPC falla
/// con `unauthorized`. Como los servicios de ranking hacían `catch → []`, la
/// sección simplemente DESAPARECÍA hasta recargar la app.
///
/// Ahora: ante un fallo se refresca la sesión una vez y se reintenta. Si aun
/// así falla, el llamador puede quedarse con el último resultado bueno en vez
/// de vaciar la pantalla.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// True si el error parece de sesión/token (vale la pena refrescar y reintentar).
bool esErrorDeSesion(Object error) {
  final texto = error.toString().toLowerCase();
  return texto.contains('jwt') ||
      texto.contains('unauthorized') ||
      texto.contains('no_auth') ||
      texto.contains('expired') ||
      texto.contains('401');
}

/// Ejecuta [accion]; si falla, refresca la sesión y reintenta UNA vez.
Future<T> rpcConReintento<T>(
  Future<T> Function() accion, {
  String etiqueta = 'rpc',
}) async {
  try {
    return await accion();
  } catch (error) {
    if (!esErrorDeSesion(error)) rethrow;
    debugPrint('🔄 $etiqueta: sesión vencida, refrescando y reintentando...');
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (e) {
      debugPrint('⚠️ $etiqueta: no se pudo refrescar la sesión: $e');
    }
    return await accion();
  }
}
