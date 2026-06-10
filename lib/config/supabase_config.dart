/// Configuración centralizada de Supabase.
///
/// Responsabilidades:
/// - Proporcionar acceso centralizado a configuraciones de Supabase
/// - Validar que las credenciales estén correctamente configuradas
/// - Facilitar testing y cambios de configuración
///
/// Las credenciales se cargan desde el archivo .env en main.dart
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

  /// Obtiene la URL de Supabase desde variables de entorno
  static String? obtenerUrl() {
    return dotenv.env[_nombreVariableUrl];
  }

  /// Obtiene la clave pública (anon key) de Supabase desde variables de entorno
  static String? obtenerClavePublica() {
    return dotenv.env[_nombreVariableClave];
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
