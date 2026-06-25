/// Configuración centralizada de Supabase.
///
/// Responsabilidades:
/// - Proporcionar acceso centralizado a configuraciones de Supabase
/// - Validar que las credenciales estén correctamente configuradas
/// - Facilitar testing y cambios de configuración
///
/// La configuracion se carga desde --dart-define y cae a .env solo en local.
/// Este archivo proporciona métodos helper para validar y acceder a la config.
///
/// Uso:
/// ```dart
/// if (ConfiguracionSupabase.estaConfigurado()) {
///   final url = ConfiguracionSupabase.obtenerUrl();
/// }
/// ```
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfiguracionSupabase {
  // Nombres de las variables en el archivo .env
  static const String _nombreVariableUrl = 'URL_SUPABASE';
  static const String _nombreVariableClave = 'CLAVE_PUBLICA_SUPABASE';

  static const String _urlDefine = String.fromEnvironment('URL_SUPABASE');
  static const String _claveDefine = String.fromEnvironment(
    'CLAVE_PUBLICA_SUPABASE',
  );

  /// Obtiene la URL de Supabase desde --dart-define o .env local.
  static String? obtenerUrl() {
    return _urlDefine.isNotEmpty ? _urlDefine : dotenv.env[_nombreVariableUrl];
  }

  /// Obtiene la clave publica (anon key) desde --dart-define o .env local.
  static String? obtenerClavePublica() {
    return _claveDefine.isNotEmpty
        ? _claveDefine
        : dotenv.env[_nombreVariableClave];
  }

  /// Verifica si Supabase está correctamente configurado
  /// (ambas credenciales existen y no están vacías)
  static bool estaConfigurado() {
    final url = obtenerUrl();
    final clave = obtenerClavePublica();

    return url != null &&
        url.isNotEmpty &&
        clave != null &&
        clave.isNotEmpty &&
        url.startsWith('https://');
  }

  /// Valida las credenciales y lanza excepción si hay problemas
  static void validarConfiguracion() {
    if (!estaConfigurado()) {
      throw Exception(
        'Supabase no está configurado correctamente. '
        'Verifica que el archivo .env contenga:\n'
        '- $_nombreVariableUrl\n'
        '- $_nombreVariableClave',
      );
    }
  }

  /// Información de debug sobre la configuración (sin exponer claves completas)
  static String obtenerInfoDebug() {
    final url = obtenerUrl();
    final clave = obtenerClavePublica();

    return '''
    Configuración Supabase:
    - URL configurada: ${url != null ? '✅' : '❌'} ${url ?? 'No definida'}
    - Clave configurada: ${clave != null ? '✅' : '❌'} ${clave != null ? '${clave.substring(0, 20)}...' : 'No definida'}
    - Estado: ${estaConfigurado() ? '✅ Listo' : '❌ Incompleto'}
    ''';
  }
}
