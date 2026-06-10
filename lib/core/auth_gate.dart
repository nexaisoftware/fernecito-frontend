/// AuthGate - Listener Central de Autenticación (CON NAVIGATOR KEY)
///
/// Responsabilidades:
/// - Escuchar cambios en el estado de autenticación de Supabase
/// - Manejar eventos: signedIn, signedOut, passwordRecovery
/// - Navegar automáticamente según el estado usando navigatorKey
///
/// Este widget envuelve la app y maneja toda la lógica de auth routing.
library;

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../PANTALLAS/pantalla_login.dart';
import '../PANTALLAS/pantalla_home.dart';
import '../PANTALLAS/pantalla_crear_perfil.dart';
import '../PANTALLAS/pantalla_cuenta_pausada.dart';
import '../PANTALLAS/pantalla_nueva_contrasena.dart';
import 'recovery_flow_flag.dart';
import 'servicio_estado_cuenta.dart';

// GlobalKey para acceder al Navigator desde cualquier lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  String? _lastUserId; // Para evitar procesar el mismo usuario múltiples veces
  String? _currentRoute; // Trackear la ruta actual para evitar duplicados

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    // Escuchar cambios en el estado de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;

        print('🔐 AuthGate: Evento detectado: $event');
        print('🔐 AuthGate: Session: ${session != null ? "activa (${session.user.email})" : "null"}');

        if (!mounted) {
          print('⚠️ AuthGate: Widget no mounted, ignorando evento');
          return;
        }

        // Si está en flujo de recuperación (OTP → nueva contraseña), no navegar
        if (RecoveryFlowFlag.enFlujoRecuperacion) {
          print('🔐 AuthGate: En flujo recuperación, ignorando evento $event');
          return;
        }

        // Manejar eventos según el tipo
        switch (event) {
          case AuthChangeEvent.signedIn:
            _handleSignedIn(session);
            break;

          case AuthChangeEvent.signedOut:
            _handleSignedOut();
            break;

          case AuthChangeEvent.passwordRecovery:
            _handlePasswordRecovery();
            break;

          case AuthChangeEvent.tokenRefreshed:
            _verificarEstadoCuentaSiHaySesion();
            break;

          case AuthChangeEvent.userUpdated:
            print('🔐 AuthGate: Usuario actualizado (no navegar)');
            break;

          default:
            print('🔐 AuthGate: Evento no manejado: $event');
        }
      },
      onError: (error) {
        print('❌ AuthGate: Error en listener: $error');
      },
    );
  }

  Future<void> _handleSignedIn(Session? session) async {
    if (session == null) {
      print('⚠️ AuthGate: Session null en signedIn');
      return;
    }

    // Verificar si ya procesamos este usuario (evitar duplicados)
    if (_lastUserId == session.user.id && _currentRoute != null) {
      print('⚠️ AuthGate: Usuario ${session.user.email} ya procesado, ignorando');
      return;
    }

    print('✅ AuthGate: Procesando usuario logueado: ${session.user.email}');
    _lastUserId = session.user.id;

    try {
      final suspendida = await ServicioEstadoCuenta.instancia.refrescar();
      if (!mounted) return;

      if (suspendida) {
        print('🛑 AuthGate: Cuenta pausada, redirigiendo a CuentaPausada');
        _navigateTo(const PantallaCuentaPausada(), 'cuenta_pausada');
        return;
      }

      // Verificar si el perfil está completo
      print('🔍 AuthGate: Consultando perfil_completo para user ${session.user.id}');
      
      final respuesta = await Supabase.instance.client
          .from('perfiles_usuarios')
          .select('perfil_completo, estado_cuenta')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      final estado = respuesta?['estado_cuenta']?.toString();
      if (estado == 'pausada') {
        print('🛑 AuthGate: Cuenta pausada (fallback), redirigiendo a CuentaPausada');
        _navigateTo(const PantallaCuentaPausada(), 'cuenta_pausada');
        return;
      }

      final perfilCompleto = respuesta?['perfil_completo'] ?? false;

      print('🔐 AuthGate: Perfil completo: $perfilCompleto');

      // Navegar según estado del perfil
      if (perfilCompleto) {
        print('➡️ AuthGate: Navegando a Home');
        _navigateTo(const PantallaHome(), 'home');
      } else {
        print('➡️ AuthGate: Navegando a CrearPerfil');
        _navigateTo(const PantallaCrearPerfil(), 'crear_perfil');
      }
    } catch (error) {
      print('❌ AuthGate: Error verificando perfil: $error');
      // Si hay error, asumir perfil incompleto
      if (mounted) {
        print('➡️ AuthGate: Error en consulta, navegando a CrearPerfil por seguridad');
        _navigateTo(const PantallaCrearPerfil(), 'crear_perfil');
      }
    }
  }

  void _handleSignedOut() {
    print('🔐 AuthGate: Usuario cerró sesión');
    ServicioEstadoCuenta.instancia.limpiar();
    _lastUserId = null; // Resetear el último usuario
    _currentRoute = null; // Resetear la ruta

    print('➡️ AuthGate: Navegando a Login');
    _navigateTo(const PantallaLogin(), 'login');
  }

  void _handlePasswordRecovery() {
    print('🔐 AuthGate: Recuperación de contraseña detectada');
    RecoveryFlowFlag.activar(); // Evitar que signedIn nos lleve a Home
    print('➡️ AuthGate: Navegando a NuevaContrasena');
    _navigateTo(const PantallaNuevaContrasena(), 'nueva_contrasena');
  }

  void _navigateTo(Widget screen, String routeName) {
    // Si ya estamos en esta ruta, no hacer nada
    if (_currentRoute == routeName) {
      print('⚠️ AuthGate: Ya estamos en $routeName, ignorando navegación');
      return;
    }

    print('🚀 AuthGate: Iniciando navegación a $routeName');

    // Obtener el NavigatorState desde el GlobalKey
    final navigator = navigatorKey.currentState;
    
    if (navigator == null) {
      print('❌ AuthGate: Navigator no disponible');
      return;
    }

    try {
      // Navegar limpiando todo el stack
      navigator.pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (context) => screen,
          maintainState: false,
        ),
        (route) => false, // Remover todas las rutas anteriores
      );

      _currentRoute = routeName;
      print('✅ AuthGate: Navegación completada a $routeName');
    } catch (error) {
      print('❌ AuthGate: Error en navegación: $error');
      _currentRoute = null; // Resetear si falla
    }
  }

  Future<void> _verificarEstadoCuentaSiHaySesion() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    if (RecoveryFlowFlag.enFlujoRecuperacion) return;

    final suspendida = await ServicioEstadoCuenta.instancia.refrescar();
    if (!mounted) return;

    if (suspendida && _currentRoute != 'cuenta_pausada') {
      _navigateTo(const PantallaCuentaPausada(), 'cuenta_pausada');
      return;
    }

    if (!suspendida && _currentRoute == 'cuenta_pausada') {
      await _handleSignedIn(session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
