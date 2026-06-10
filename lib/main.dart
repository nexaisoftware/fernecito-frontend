/// Punto de entrada principal de la aplicación Fernecito.
///
/// Responsabilidades:
/// - Inicializar Flutter binding (requerido para async en main)
/// - Cargar variables de entorno desde archivo .env
/// - Configurar y conectar con Supabase (backend BaaS)
/// - Lanzar la aplicación principal (AppFernecito)
///
/// Stack: Flutter + Supabase (PostgreSQL, Auth, Storage, Realtime)
/// Objetivo MVP: App mobile iOS/Android para conectar usuarios con promos exclusivas
/// in-local en bares, boliches, restós y eventos en Córdoba (escalable a ARG/LATAM).
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/servicio_enlace_evento.dart';
import 'core/tema_fernecito.dart';

void main() async {
  // Asegura que Flutter esté inicializado antes de operaciones async
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno desde archivo .env
  try {
    await dotenv.load(fileName: '.env');
    print('✅ Variables de entorno cargadas correctamente');
  } catch (e) {
    print('❌ Error al cargar archivo .env: $e');
    print('Asegúrate de que existe un archivo .env en la raíz del proyecto');
  }

  // Inicializar Supabase con credenciales del archivo .env y deep link
  bool supabaseInicializado = false;
  String? errorSupabase;
  try {
    final urlSupabase = dotenv.env['URL_SUPABASE'];
    final clavePublica = dotenv.env['CLAVE_PUBLICA_SUPABASE'];

    // Validar que las credenciales existan
    if (urlSupabase == null || clavePublica == null) {
      throw Exception(
        'Faltan credenciales en .env: URL_SUPABASE o CLAVE_PUBLICA_SUPABASE. '
        'Copia .env.ejemplo a .env en fernecito_frontend y rellena los valores.',
      );
    }

    // Inicializar conexión con Supabase + deep link para OAuth y recovery
    await Supabase.initialize(
      url: urlSupabase,
      anonKey: clavePublica,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // Deep link único para OAuth, confirmación email y recovery
        // fernecito://auth-callback
      ),
    );

    supabaseInicializado = true;
    print('✅ Supabase inicializado correctamente');
    print('📡 Conectado a: $urlSupabase');
    print('🔗 Deep link: fernecito://auth-callback');
  } catch (e) {
    errorSupabase = e.toString();
    print('❌ Error al inicializar Supabase: $e');
    print(
      'La app no puede arrancar sin Supabase. Revisa .env en fernecito_frontend.',
    );
  }

  // Cargar tema guardado
  await TemaFernecito.instancia.cargar();

  // Deep link web ?evento= /e/{id} → PantallaVerEvento tras login
  ServicioEnlaceEvento.instancia.capturarDesdeUriActual();
  await _inicializarDeepLinksNativos();

  // Solo lanzar la app principal si Supabase está inicializado (evita crash por Supabase.instance)
  if (supabaseInicializado) {
    runApp(const AppFernecito());
  } else {
    runApp(_PantallaErrorConfig(errorSupabase ?? 'Supabase no inicializado'));
  }
}

Future<void> _inicializarDeepLinksNativos() async {
  try {
    final appLinks = AppLinks();
    final inicial = await appLinks.getInitialLink();
    if (inicial != null) {
      ServicioEnlaceEvento.instancia.capturarDesdeUri(
        inicial,
        notificar: false,
      );
    }

    appLinks.uriLinkStream.listen(
      ServicioEnlaceEvento.instancia.capturarDesdeUri,
      onError: (Object e) => print('⚠️ Deep link nativo: $e'),
    );
  } catch (e) {
    print('⚠️ No se pudo inicializar deep links nativos: $e');
  }
}

/// Pantalla mínima cuando falla la inicialización de Supabase (no usa Supabase.instance).
class _PantallaErrorConfig extends StatelessWidget {
  const _PantallaErrorConfig(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Error de configuración',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  mensaje,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Revisa que exista el archivo .env en la carpeta fernecito_frontend '
                  'con URL_SUPABASE y CLAVE_PUBLICA_SUPABASE. Usa .env.ejemplo como guía.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
