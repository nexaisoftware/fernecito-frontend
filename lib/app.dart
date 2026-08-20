/// Widget raíz de la aplicación Fernecito.
///
/// Define la configuración global de la app:
/// - Usa CupertinoApp para estética iOS premium (vibe Apple desde día 1)
/// - Tema oscuro con paleta verde fernet + rojo coca sutil
/// - Configuración de navegación y routing (go_router se integrará aquí)
///
/// Estética: Familiar, memeable, burlesca, premium iOS, cómoda y fácil de usar.
/// No parecer chota ni mal pensada.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, ScaffoldMessenger;
import 'package:flutter/services.dart'
    show AnnotatedRegion, SystemUiOverlayStyle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants.dart';
import 'core/supabase_client.dart';
import 'core/auth_gate.dart';
import 'core/historial_web.dart';
import 'core/tema_fernecito.dart';
import 'core/servicio_estado_cuenta.dart';
import 'core/barra_sistema_fernecito.dart';
import 'core/bootstrap_cartelera.dart';
import 'core/splash_web.dart';
import 'widgets/control_actualizacion_web.dart';
import 'widgets/control_instalar_pwa.dart';
import 'widgets/splash_carga_fernecito.dart';
import 'PANTALLAS/pantalla_login.dart';
import 'PANTALLAS/pantalla_home.dart';
import 'PANTALLAS/pantalla_crear_perfil.dart';
import 'PANTALLAS/pantalla_cuenta_pausada.dart';

class AppFernecito extends StatefulWidget {
  const AppFernecito({super.key});

  @override
  State<AppFernecito> createState() => _AppFernecitoState();
}

class _AppFernecitoState extends State<AppFernecito>
    with WidgetsBindingObserver {
  bool _verificandoSesion = true;
  bool _tieneSesionActiva = false;
  bool _perfilCompleto = false;
  bool _splashMinimaCumplida = false;
  bool _splashLockupListo = false;
  Timer? _splashHoldTimer;
  Timer? _splashSeguridadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BootstrapCartelera.lista.addListener(_onBootstrapCartelera);
    splashAnimacionCompleta.value = false;
    splashLockupListo.value = false;
    splashLockupListo.addListener(_onSplashLockup);
    // PWA: barra oscura desde el primer frame (no verde tipo "en llamada").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      quitarSplashHtml();
      BarraSistemaFernecito.aplicar();
    });
    _verificarSesionExistente();
    // No atar el hold al reloj de initState: en Android debug el primer
    // vsync del splash puede llegar tarde y el timer viejo dejaba el Stack vacío.
    _splashSeguridadTimer = Timer(kSplashSeguridadMaxima, _forzarFinSplash);
  }

  @override
  void dispose() {
    _splashHoldTimer?.cancel();
    _splashSeguridadTimer?.cancel();
    splashLockupListo.removeListener(_onSplashLockup);
    BootstrapCartelera.lista.removeListener(_onBootstrapCartelera);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSplashLockup() {
    if (!mounted) return;
    if (splashLockupListo.value == _splashLockupListo) return;
    // Sin setState: montar Home acá reconstruye el árbol y tira la splash.
    _splashLockupListo = splashLockupListo.value;
    if (_splashLockupListo) _programarHoldTrasLockup();
  }

  void _programarHoldTrasLockup() {
    if (_splashMinimaCumplida || _splashHoldTimer != null) return;
    _splashHoldTimer = Timer(kSplashHoldTrasLockup, () {
      if (!mounted) return;
      splashAnimacionCompleta.value = true;
      setState(() => _splashMinimaCumplida = true);
    });
  }

  void _forzarFinSplash() {
    if (!mounted) return;
    if (_splashMinimaCumplida && _splashLockupListo) return;
    splashLockupListo.value = true;
    splashAnimacionCompleta.value = true;
    setState(() {
      _splashLockupListo = true;
      _splashMinimaCumplida = true;
    });
  }

  void _onBootstrapCartelera() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de background, re-chequea suspensión a nivel app (sin importar
    // en qué pantalla esté el usuario). El gate del builder reacciona solo.
    if (state == AppLifecycleState.resumed &&
        ServicioSupabase().usuarioActual != null) {
      ServicioEstadoCuenta.instancia.refrescar();
    }
  }

  // Verificar si hay una sesión activa y si el perfil está completo
  Future<void> _verificarSesionExistente() async {
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario != null) {
        print('✅ Sesión existente detectada: ${usuario.email}');

        // Refresca el switch de suspensión (el gate del builder reacciona solo).
        await ServicioEstadoCuenta.instancia.refrescar();

        // Verificar si el perfil está completo en tabla perfiles_usuarios
        try {
          final respuesta = await supabase.cliente
              .from('perfiles_usuarios')
              .select('perfil_completo, estado_cuenta')
              .eq('id', usuario.id)
              .maybeSingle();

          if (respuesta != null && respuesta['perfil_completo'] == true) {
            print('✅ Perfil completo');
            setState(() {
              _tieneSesionActiva = true;
              _perfilCompleto = true;
            });
          } else {
            print('⚠️ Perfil incompleto o no existe');
            setState(() {
              _tieneSesionActiva = true;
              _perfilCompleto = false;
            });
          }
        } catch (e) {
          print('❌ Error verificando perfil: $e');
          // Si hay error verificando perfil, asumir que no está completo
          setState(() {
            _tieneSesionActiva = true;
            _perfilCompleto = false;
          });
        }
      } else {
        print('ℹ️ No hay sesión activa');
      }
    } catch (e) {
      print('❌ Error verificando sesión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _verificandoSesion = false;
        });
        if (_tieneSesionActiva) {
          // Evita que el "atrás" del browser vuelva a OAuth/login tras un cold start.
          limpiarHistorialAuthWeb();
        }
        // Login / crear perfil: salir del splash verde a la UI oscura.
        // Home aplica la barra al terminar de cargar la cartelera.
        if (!_tieneSesionActiva || !_perfilCompleto) {
          BarraSistemaFernecito.aplicar();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      child: ValueListenableBuilder<Color>(
        valueListenable: TemaFernecito.instancia.colorActual,
        builder: (context, colorTema, _) => CupertinoApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          // Delegates necesarios para usar Material widgets (Scaffold, RefreshIndicator,
          // InkWell, TextField, FilledButton, etc.) dentro de un CupertinoApp.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'AR'), Locale('es')],
          locale: const Locale('es', 'AR'),
          title: CadenasApp.nombreApp,
          theme: CupertinoThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: ColoresApp.fondoPrincipal,
            primaryColor: colorTema,
            primaryContrastingColor: ColoresApp.promoMarca,
            barBackgroundColor: ColoresApp.fondoSuperficie,
            textTheme: CupertinoTextThemeData(
              textStyle: const TextStyle(color: ColoresApp.textoPrincipal),
              actionTextStyle: TextStyle(color: colorTema),
              navTitleTextStyle: const TextStyle(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Rutas nombradas para navegación
          routes: {
            '/login': (context) => const PantallaLogin(),
            '/home': (context) => const PantallaHome(),
          },
          // Gate de cuenta suspendida: mientras esté pausada, toma el control
          // total de la app (igual que el guard de rutas del panel de locales).
          // Escucha ServicioEstadoCuenta y reemplaza toda la UI por la pantalla
          // bloqueante, que solo permite soporte o cerrar sesión.
          builder: (context, child) {
            return Material(
              color: ColoresApp.fondoPrincipal,
              child: ScaffoldMessenger(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: BarraSistemaFernecito.estilo,
                  child: ControlInstalarPwa(
                    child: ControlActualizacionWeb(
                      child: ListenableBuilder(
                        listenable: ServicioEstadoCuenta.instancia,
                        builder: (context, _) {
                          if (ServicioEstadoCuenta.instancia.suspendida) {
                            return Navigator(
                              onGenerateRoute: (_) => CupertinoPageRoute<void>(
                                builder: (_) => const PantallaCuentaPausada(),
                              ),
                            );
                          }
                          return child ?? const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          // Un solo splash (misma instancia) hasta sesión + cartelera lista.
          home: _buildHome(),
        ),
      ),
    );
  }

  Widget _buildHome() {
    // Home/login recién después del hold: la cartelera no pelea los
    // últimos frames del lockup ni el segundo extra de splash sola.
    final listo = _splashMinimaCumplida;
    final sesionLista = !_verificandoSesion;
    final irAHome =
        listo && sesionLista && _tieneSesionActiva && _perfilCompleto;

    Widget? destino;
    if (listo && sesionLista && !_tieneSesionActiva) {
      destino = const PantallaLogin();
    } else if (listo &&
        sesionLista &&
        _tieneSesionActiva &&
        !_perfilCompleto) {
      destino = const PantallaCrearPerfil();
    }

    // Nunca sacar el splash si no hay Home ni login: si no, queda #121212 vacío.
    final mostrarSplash =
        !listo ||
        !sesionLista ||
        (irAHome && !BootstrapCartelera.lista.value);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (irAHome) const PantallaHome(),
        if (destino != null) destino,
        if (mostrarSplash)
          const RepaintBoundary(
            child: SplashCargaFernecito(key: ValueKey('splash_fernecito')),
          ),
      ],
    );
  }
}
