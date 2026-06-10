/// Pantalla bloqueante mostrada cuando la cuenta del usuario fue pausada
/// desde el dashboard de owner.
///
/// Toma el control total de la app (se monta desde [AppFernecito] vía el
/// `builder` de CupertinoApp mientras `ServicioEstadoCuenta.suspendida` es true).
/// Solo permite contactar a soporte o cerrar sesión: no deja hacer nada más.
/// Es autosuficiente (no depende del Navigator principal de la app).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/servicio_estado_cuenta.dart';

const String _emailSoporte = 'soporte@fernecito.app';

class PantallaCuentaPausada extends StatefulWidget {
  const PantallaCuentaPausada({super.key});

  @override
  State<PantallaCuentaPausada> createState() => _PantallaCuentaPausadaState();
}

class _PantallaCuentaPausadaState extends State<PantallaCuentaPausada> {
  bool _verificando = true;
  bool _emailCopiado = false;
  String? _mensajeRefresh;

  @override
  void initState() {
    super.initState();
    _verificarEstado();
  }

  /// Reconsulta `mi_estado_cuenta`. Si ya no está suspendida, el gate de
  /// [AppFernecito] quita esta pantalla automáticamente.
  Future<void> _verificarEstado({bool desdeRefresh = false}) async {
    if (!desdeRefresh && mounted) {
      setState(() {
        _verificando = true;
        _mensajeRefresh = null;
      });
    } else if (desdeRefresh && mounted) {
      setState(() => _mensajeRefresh = null);
    }

    await ServicioEstadoCuenta.instancia.refrescar();

    if (!mounted) return;
    // Si dejó de estar suspendida, el ListenableBuilder de app.dart reconstruye
    // y esta pantalla se desmonta — no hace falta navegar manualmente.
    if (ServicioEstadoCuenta.instancia.suspendida) {
      setState(() {
        _verificando = false;
        if (desdeRefresh) {
          _mensajeRefresh =
              'Tu cuenta sigue suspendida. Probá más tarde o escribinos a soporte.';
        }
      });
    } else {
      setState(() => _verificando = false);
    }
  }

  Future<void> _copiarSoporte() async {
    await Clipboard.setData(const ClipboardData(text: _emailSoporte));
    if (!mounted) return;
    setState(() => _emailCopiado = true);
  }

  Future<void> _cerrarSesion() async {
    // Limpiamos primero para que el gate devuelva el control al Navigator
    // principal; el AuthGate detecta el signOut y rutea a Login.
    ServicioEstadoCuenta.instancia.limpiar();
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final motivo = ServicioEstadoCuenta.instancia.motivoLabel ??
        'Tu cuenta fue suspendida por el equipo de Fernecito';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        body: SafeArea(
          child: _verificando
              ? Center(
                  child: CupertinoActivityIndicator(
                    radius: 16,
                    color: ColoresApp.principalMarca,
                  ),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () =>
                          _verificarEstado(desdeRefresh: true),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 24,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: ColoresApp.peligroMarca
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: ColoresApp.peligroMarca
                                            .withValues(alpha: 0.20),
                                        blurRadius: 26,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.gpp_bad_rounded,
                                    size: 72,
                                    color: ColoresApp.peligroMarca,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Cuenta suspendida',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: ColoresApp.textoPrincipal,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'El acceso a tu cuenta fue suspendido temporalmente '
                                  'por el equipo de Fernecito.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 14.5,
                                    color: ColoresApp.textoSecundario,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Deslizá hacia abajo para verificar si tu cuenta '
                                  'ya fue rehabilitada.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: ColoresApp.principalMarca,
                                    height: 1.35,
                                  ),
                                ),
                                if (_mensajeRefresh != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: ColoresApp.fondoSuperficie,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: ColoresApp.textoSecundario
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Text(
                                      _mensajeRefresh!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.baloo2(
                                        fontSize: 13,
                                        color: ColoresApp.textoSecundario,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: ColoresApp.fondoSuperficie,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: ColoresApp.peligroMarca
                                          .withValues(alpha: 0.40),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MOTIVO',
                                        style: GoogleFonts.baloo2(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: ColoresApp.peligroMarca,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        motivo,
                                        style: GoogleFonts.baloo2(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: ColoresApp.textoPrincipal,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Podés contactar a soporte oficial para revisar tu caso. '
                                  'El resto de las funciones permanecen deshabilitadas.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    color: ColoresApp.textoSecundario,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _copiarSoporte();
                                    },
                                    icon: const Icon(Icons.support_agent_rounded,
                                        size: 22),
                                    label: Text(
                                      'Contactar a soporte',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          ColoresApp.principalMarca,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(50),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _emailCopiado
                                      ? '✓ $_emailSoporte copiado al portapapeles'
                                      : 'Escribinos a $_emailSoporte',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    fontWeight: _emailCopiado
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _emailCopiado
                                        ? ColoresApp.principalMarca
                                        : ColoresApp.textoSecundario,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextButton.icon(
                                  onPressed: _cerrarSesion,
                                  icon: Icon(Icons.logout_rounded,
                                      size: 18,
                                      color: ColoresApp.textoSecundario),
                                  label: Text(
                                    'Cerrar sesión',
                                    style: GoogleFonts.baloo2(
                                      fontWeight: FontWeight.w700,
                                      color: ColoresApp.textoSecundario,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
