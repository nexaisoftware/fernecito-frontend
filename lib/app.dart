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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'core/constants.dart';
import 'core/supabase_client.dart';
import 'core/auth_gate.dart';
import 'core/tema_fernecito.dart';
import 'core/servicio_estado_cuenta.dart';
import 'widgets/skeleton_pantallas.dart';
import 'PANTALLAS/pantalla_login.dart';
import 'PANTALLAS/pantalla_home.dart';
import 'PANTALLAS/pantalla_crear_perfil.dart';
import 'PANTALLAS/pantalla_cuenta_pausada.dart';

class AppFernecito extends StatefulWidget {
  const AppFernecito({super.key});

  @override
  State<AppFernecito> createState() => _AppFernecitoState();
}

class _AppFernecitoState extends State<AppFernecito> with WidgetsBindingObserver {
  bool _verificandoSesion = true;
  bool _tieneSesionActiva = false;
  bool _perfilCompleto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarSesionExistente();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      setState(() {
        _verificandoSesion = false;
      });
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
            DefaultMaterialLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
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
          return ListenableBuilder(
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
          );
        },
        // Pantalla inicial según estado de sesión y perfil (skeleton de cartelera mientras verifica)
        home: _verificandoSesion
            ? const SkeletonPantallaCartelera()
            : _tieneSesionActiva
                ? (_perfilCompleto
                    ? const PantallaHome()
                    : const PantallaCrearPerfil())
                : const PantallaLogin(),
        ),
      ),
    );
  }
}
