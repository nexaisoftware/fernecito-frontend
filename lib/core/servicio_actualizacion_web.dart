library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'recarga_web.dart';

/// Detecta deploys nuevos en web/PWA comparando [version.json] (con [deploy_id]).
class ServicioActualizacionWeb {
  ServicioActualizacionWeb._();
  static final ServicioActualizacionWeb instancia =
      ServicioActualizacionWeb._();

  static const _prefsKey = 'fernecito_usuarios_web_build_fingerprint';

  bool get soportado => kIsWeb;

  Future<bool> verificar() async {
    if (!kIsWeb) return false;

    try {
      final remoto = await _obtenerFingerprintRemoto();
      if (remoto == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_prefsKey);

      if (guardado == null || guardado.isEmpty) {
        await prefs.setString(_prefsKey, remoto);
        return false;
      }

      return guardado != remoto;
    } catch (e) {
      debugPrint('ServicioActualizacionWeb.verificar: $e');
      return false;
    }
  }

  Future<void> aplicarActualizacion() async {
    if (!kIsWeb) return;

    try {
      final remoto = await _obtenerFingerprintRemoto();
      if (remoto != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, remoto);
      }
    } catch (_) {}

    await recargarAppWeb();
  }

  Future<String?> _obtenerFingerprintRemoto() async {
    final base = Uri.base;
    final uri = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/version.json',
      queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'},
    );

    final res = await http.get(
      uri,
      headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
    );
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);

    final deployId = map['deploy_id']?.toString().trim();
    if (deployId != null && deployId.isNotEmpty) return deployId;

    final version = map['version']?.toString() ?? '';
    final build = map['build_number']?.toString() ?? '';
    if (version.isEmpty && build.isEmpty) return null;
    return '$version+$build';
  }
}
