/// Pantalla de inicio de sesión para usuarios y locales.
///
/// Características:
/// - Diseño iOS premium con estética Fernecito (oscura)
/// - Fondo con glow animado (blobs difuminados) inspirado en el hero de la landing
/// - Login con email/password (Supabase Auth)
/// - Botón de Google OAuth
/// - Acordeón para formulario de email
///
/// Stack: Cupertino widgets + Google Fonts + Font Awesome
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/tema_fernecito.dart';
import '../core/supabase_client.dart';
import '../core/auth_redirect.dart';
import '../core/auth_errors.dart';
import 'pantalla_singup.dart';
import 'pantalla_nueva_contrasena.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controladorEmail = TextEditingController();
  final TextEditingController _controladorContrasena = TextEditingController();

  bool _mostrarFormularioEmail = false;

  late AnimationController _controladorAnimacion;
  late Animation<double> _animacionAcordeon;

  final ScrollController _controladorScroll = ScrollController();
  final GlobalKey _keyAcordeon = GlobalKey();

  bool _cargandoLogin = false;
  bool _ocultarContrasenaLogin = true;

  @override
  void initState() {
    super.initState();
    _controladorAnimacion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animacionAcordeon = CurvedAnimation(
      parent: _controladorAnimacion,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorContrasena.dispose();
    _controladorAnimacion.dispose();
    _controladorScroll.dispose();
    super.dispose();
  }

  void _alternarFormularioEmail() {
    setState(() {
      _mostrarFormularioEmail = !_mostrarFormularioEmail;
      if (_mostrarFormularioEmail) {
        _controladorAnimacion.forward();
        Future.delayed(const Duration(milliseconds: 120), () {
          if (_keyAcordeon.currentContext != null) {
            Scrollable.ensureVisible(
              _keyAcordeon.currentContext!,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOut,
              alignment: 0.1,
            );
          }
        });
      } else {
        _controladorAnimacion.reverse();
      }
    });
  }

  Future<void> _manejarLoginEmail() async {
    final email = _controladorEmail.text.trim();
    final contrasena = _controladorContrasena.text;

    if (email.isEmpty) {
      _mostrarError('Por favor ingresa tu email');
      return;
    }
    if (!email.contains('@')) {
      _mostrarError('Por favor ingresa un email válido');
      return;
    }
    if (contrasena.isEmpty) {
      _mostrarError('Por favor ingresa tu contraseña');
      return;
    }
    if (contrasena.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _cargandoLogin = true);

    try {
      final supabase = ServicioSupabase();
      final respuesta = await supabase.cliente.auth.signInWithPassword(
        email: email,
        password: contrasena,
      );

      if (respuesta.user != null) {
        debugPrint('✅ Login exitoso: ${respuesta.user!.email}');
        // AuthGate se encarga de la navegación.
      }
    } catch (error) {
      debugPrint('❌ Error en login: $error');
      if (mounted) {
        final mensajeError = TraductorErroresAuth.traducir(error);
        _mostrarError(mensajeError, email: email);
      }
    } finally {
      if (mounted) setState(() => _cargandoLogin = false);
    }
  }

  void _mostrarError(String mensaje, {String? email}) {
    final esErrorConfirmacion = mensaje.contains('falta confirmar') ||
        mensaje.contains('confirmar tu email');

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(
              esErrorConfirmacion
                  ? CupertinoIcons.mail
                  : CupertinoIcons.exclamationmark_circle,
              color: esErrorConfirmacion
                  ? ColoresApp.promoMarca
                  : ColoresApp.peligroMarca,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                esErrorConfirmacion ? 'Email sin confirmar' : 'Error',
                style: GoogleFonts.baloo2(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje, style: GoogleFonts.baloo2(fontSize: 14)),
        ),
        actions: [
          if (esErrorConfirmacion && email != null)
            CupertinoDialogAction(
              child: Text('Reenviar confirmación', style: GoogleFonts.baloo2()),
              onPressed: () async {
                Navigator.of(context).pop();
                await _reenviarEmailConfirmacion(email);
              },
            ),
          CupertinoDialogAction(
            child: Text('OK', style: GoogleFonts.baloo2()),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _reenviarEmailConfirmacion(String email) async {
    if (email.isEmpty) {
      _mostrarError('Por favor ingresa tu email primero');
      return;
    }
    try {
      final supabase = ServicioSupabase();
      await supabase.cliente.auth.resend(type: OtpType.signup, email: email);
      if (mounted) {
        _mostrarExito(TraductorErroresAuth.mensajeConfirmacionReenviada());
      }
    } catch (error) {
      debugPrint('❌ Error al reenviar email: $error');
      if (mounted) {
        _mostrarError(TraductorErroresAuth.traducir(error));
      }
    }
  }

  void _mostrarExito(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(
              CupertinoIcons.check_mark_circled,
              color: ColoresApp.principalMarca,
            ),
            const SizedBox(width: 8),
            const Text('Éxito'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje, style: GoogleFonts.baloo2(fontSize: 14)),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Continuar', style: GoogleFonts.baloo2()),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _manejarLoginGoogle() async {
    try {
      debugPrint('🔐 Iniciando login con Google...');
      final supabase = ServicioSupabase();
      await supabase.cliente.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authRedirectUrlUsuarios,
      );
    } catch (error) {
      debugPrint('❌ Error en login con Google: $error');
      if (mounted) {
        _mostrarError(
          'No se pudo conectar con Google.\n\nProbá de nuevo en unos segundos.',
        );
      }
    }
  }

  void _irARecuperacionPassword() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => const PantallaNuevaContrasena()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final anchoContenido = math.min(size.width * 0.86, 420.0);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      child: Stack(
        children: [
          const Positioned.fill(child: _GlowAnimadoFondo()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _controladorScroll,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: math.max(size.height * 0.04, 24),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: anchoContenido),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _construirLogo(),
                      const SizedBox(height: 22),
                      _construirTitulo(),
                      const SizedBox(height: 12),
                      _construirFrase(),
                      const SizedBox(height: 40),
                      _construirBotonGoogle(),
                      const SizedBox(height: 14),
                      _construirBotonEmail(),
                      _construirAcordeonEmail(),
                      const SizedBox(height: 28),
                      _construirSeparador(),
                      const SizedBox(height: 22),
                              _construirLinkRegistro(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirLogo() {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: colorTema.withValues(alpha: 0.30),
                blurRadius: 40,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Image.asset(
            'assets/imagenes/logoprincipal.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  CupertinoIcons.photo,
                  size: 40,
                  color: ColoresApp.textoSecundario,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _construirTitulo() {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.baloo2(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.0,
            ),
            children: [
              const TextSpan(
                text: 'Fernecito',
                style: TextStyle(color: ColoresApp.textoPrincipal),
              ),
              TextSpan(
                text: ' app',
                style: TextStyle(color: colorTema),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _construirFrase() {
    return Text(
      'Tu ciudad tiene más planes\nde los que imaginás.',
      textAlign: TextAlign.center,
      style: GoogleFonts.baloo2(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: ColoresApp.textoSecundario,
      ),
    );
  }

  Widget _construirBotonGoogle() {
    return _BotonGlass(
      onPressed: _manejarLoginGoogle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.google,
            color: ColoresApp.textoPrincipal,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            'Continuar con Google',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColoresApp.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonEmail() {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return _BotonPrimario(
          color: colorTema,
          onPressed: _alternarFormularioEmail,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _mostrarFormularioEmail
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.mail_solid,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Continuar con email',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _construirAcordeonEmail() {
    return SizeTransition(
      sizeFactor: _animacionAcordeon,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _animacionAcordeon,
        child: Padding(
          key: _keyAcordeon,
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              _CampoTexto(
                controlador: _controladorEmail,
                placeholder: 'Tu email',
                icono: CupertinoIcons.mail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _CampoTexto(
                controlador: _controladorContrasena,
                placeholder: 'Tu contraseña',
                icono: CupertinoIcons.lock,
                obscure: _ocultarContrasenaLogin,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _manejarLoginEmail(),
                trailing: CupertinoButton(
                  padding: const EdgeInsets.only(right: 12),
                  onPressed: () => setState(
                    () => _ocultarContrasenaLogin = !_ocultarContrasenaLogin,
                  ),
                  child: Icon(
                    _ocultarContrasenaLogin
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    color: ColoresApp.textoSecundario,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<Color>(
                valueListenable: TemaFernecito.instancia.colorActual,
                builder: (context, colorTema, _) {
                  return _BotonPrimario(
                    color: colorTema,
                    onPressed: _cargandoLogin ? null : _manejarLoginEmail,
                    child: _cargandoLogin
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text(
                            'Iniciar sesión',
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _irARecuperacionPassword,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirSeparador() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '¿Sos nuevo?',
            style: GoogleFonts.baloo2(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  Widget _construirLinkRegistro() {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const PantallaSignup()),
            );
          },
          child: Text(
            '¡Quiero una cuenta Fernecito!',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorTema,
            ),
          ),
        );
      },
    );
  }
}

// ── Fondo con glow animado — réplica del hero de la landing ───────────────────
//
// Colores y parámetros tomados de landing.html (.hero-glow / hero-float-a/b/c):
//   verde  #1DB954 (9s),  violeta #7C3AED (11s),  dorado #E0B800 (8s).
// Cada blob sigue sus propios keyframes (translate en vw/vh + scale) con
// interpolación ease-in-out, igual que las @keyframes CSS.
class _GlowAnimadoFondo extends StatelessWidget {
  const _GlowAnimadoFondo();

  // Keyframes: [progreso(0..1), translateX, translateY, scale]
  static const List<List<double>> _keysVerde = [
    [0.00, 0, 0, 1.00],
    [0.20, -28, 18, 1.08],
    [0.40, -50, 40, 0.96],
    [0.60, -18, 55, 1.05],
    [0.80, -40, 12, 1.02],
    [1.00, 0, 0, 1.00],
  ];
  static const List<List<double>> _keysVioleta = [
    [0.00, 0, 0, 1.00],
    [0.18, 35, -20, 1.06],
    [0.38, 58, -48, 0.95],
    [0.58, 20, -60, 1.08],
    [0.78, 48, -12, 1.02],
    [1.00, 0, 0, 1.00],
  ];
  static const List<List<double>> _keysDorado = [
    [0.00, -50, -50, 1.00],
    [0.20, -90, -20, 1.07],
    [0.40, -15, -75, 0.96],
    [0.60, -80, -80, 1.05],
    [0.80, -25, -25, 1.03],
    [1.00, -50, -50, 1.00],
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final verdeSize = w * 1.4;
    final violetaSize = w * 1.3;
    final doradoSize = w * 0.95;

    return RepaintBoundary(
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF0A0A0A)),
          ),
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Stack(
                children: [
                  // Verde — top:-15vh; right:-40vw; 9s
                  Positioned(
                    top: -0.15 * h,
                    right: -0.40 * w,
                    width: verdeSize,
                    height: verdeSize,
                    child: _Blob(
                      color: const Color(0xFF1DB954),
                      opacity: 0.40,
                      stop: 0.65,
                      duracion: const Duration(seconds: 9),
                      keys: _keysVerde,
                      unitX: w / 100,
                      unitY: h / 100,
                    ),
                  ),
                  // Violeta — bottom:-8vh; left:-40vw; 11s
                  Positioned(
                    bottom: -0.08 * h,
                    left: -0.40 * w,
                    width: violetaSize,
                    height: violetaSize,
                    child: _Blob(
                      color: const Color(0xFF7C3AED),
                      opacity: 0.34,
                      stop: 0.65,
                      duracion: const Duration(seconds: 11),
                      keys: _keysVioleta,
                      unitX: w / 100,
                      unitY: h / 100,
                    ),
                  ),
                  // Dorado — top:30% left:50%; translate %propio; 8s
                  Positioned(
                    top: 0.30 * h,
                    left: 0.50 * w,
                    width: doradoSize,
                    height: doradoSize,
                    child: _Blob(
                      color: const Color(0xFFE0B800),
                      opacity: 0.20,
                      stop: 0.65,
                      duracion: const Duration(seconds: 8),
                      keys: _keysDorado,
                      unitX: doradoSize / 100,
                      unitY: doradoSize / 100,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrim sutil para asegurar contraste del contenido
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatefulWidget {
  const _Blob({
    required this.color,
    required this.opacity,
    required this.stop,
    required this.duracion,
    required this.keys,
    required this.unitX,
    required this.unitY,
  });

  final Color color;
  final double opacity;
  final double stop;
  final Duration duracion;
  final List<List<double>> keys;
  final double unitX;
  final double unitY;

  @override
  State<_Blob> createState() => _BlobState();
}

class _BlobState extends State<_Blob> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duracion)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _valor(double t, int idx) {
    final keys = widget.keys;
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (t >= a[0] && t <= b[0]) {
        final span = b[0] - a[0];
        final localT = span <= 0 ? 0.0 : (t - a[0]) / span;
        final e = Curves.easeInOut.transform(localT.clamp(0.0, 1.0));
        return a[idx] + (b[idx] - a[idx]) * e;
      }
    }
    return keys.last[idx];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final tx = _valor(t, 1) * widget.unitX;
        final ty = _valor(t, 2) * widget.unitY;
        final s = _valor(t, 3);
        return Transform.translate(
          offset: Offset(tx, ty),
          child: Transform.scale(scale: s, child: child),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.color.withValues(alpha: widget.opacity),
              widget.color.withValues(alpha: 0),
            ],
            stops: [0.0, widget.stop],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Botón primario sólido (color del tema) ────────────────────────────────────
class _BotonPrimario extends StatelessWidget {
  const _BotonPrimario({
    required this.child,
    required this.onPressed,
    required this.color,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        color: habilitado ? color : color.withValues(alpha: 0.5),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

// ── Botón glass (secundario, frosted) ─────────────────────────────────────────
class _BotonGlass extends StatelessWidget {
  const _BotonGlass({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            onPressed: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Campo de texto estilo iOS oscuro ──────────────────────────────────────────
class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.controlador,
    required this.placeholder,
    required this.icono,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controlador;
  final String placeholder;
  final IconData icono;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icono, color: ColoresApp.textoSecundario, size: 20),
          Expanded(
            child: CupertinoTextField(
              controller: controlador,
              placeholder: placeholder,
              placeholderStyle: TextStyle(
                color: ColoresApp.textoSecundario,
                fontSize: 16,
              ),
              style: const TextStyle(
                color: ColoresApp.textoPrincipal,
                fontSize: 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: const BoxDecoration(),
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
