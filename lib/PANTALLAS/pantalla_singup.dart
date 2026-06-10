/// Pantalla de registro de nuevos usuarios.
///
/// Características:
/// - Diseño iOS premium con estética Fernecito
/// - Registro con email/password (Supabase Auth)
/// - Validaciones client-side (email válido, contraseña segura)
/// - Botón de Google OAuth
/// - Animaciones suaves al interactuar con campos
/// - Navegación a pantalla_crear_perfil después de registro exitoso
///
/// Validaciones:
/// - Email: formato válido
/// - Contraseña: mínimo 8 caracteres, letras y números
/// - Confirmar contraseña: debe coincidir
///
/// Stack: Cupertino widgets + Google Fonts + Font Awesome + Supabase Auth
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../core/supabase_client.dart';
import '../core/auth_redirect.dart';
import '../core/auth_errors.dart';

class PantallaSignup extends StatefulWidget {
  const PantallaSignup({super.key});

  @override
  State<PantallaSignup> createState() => _PantallaSignupState();
}

class _PantallaSignupState extends State<PantallaSignup>
    with SingleTickerProviderStateMixin {
  // Controladores de campos de texto
  final TextEditingController _controladorEmail = TextEditingController();
  final TextEditingController _controladorContrasena = TextEditingController();
  final TextEditingController _controladorConfirmarContrasena =
      TextEditingController();

  // Focus nodes para detectar cuando un campo está activo
  final FocusNode _focusContrasena = FocusNode();

  // Estado
  bool _cargandoRegistro = false;
  bool _mostrarMensajeContrasena = false;
  bool _ocultarContrasena = true;
  bool _ocultarConfirmarContrasena = true;

  // Animación para el mensaje de contraseña
  late AnimationController _controladorAnimacion;
  late Animation<double> _animacionMensaje;

  @override
  void initState() {
    super.initState();

    // Configurar animación
    _controladorAnimacion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animacionMensaje = CurvedAnimation(
      parent: _controladorAnimacion,
      curve: Curves.easeInOut,
    );

    // Listener para mostrar/ocultar mensaje de contraseña
    _focusContrasena.addListener(() {
      setState(() {
        _mostrarMensajeContrasena = _focusContrasena.hasFocus;
        if (_mostrarMensajeContrasena) {
          _controladorAnimacion.forward();
        } else {
          _controladorAnimacion.reverse();
        }
      });
    });
  }

  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorContrasena.dispose();
    _controladorConfirmarContrasena.dispose();
    _focusContrasena.dispose();
    _controladorAnimacion.dispose();
    super.dispose();
  }

  // Validar formato de email
  bool _esEmailValido(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  // Validar seguridad de contraseña (8+ chars, letras y números)
  bool _esContrasenaSegura(String contrasena) {
    if (contrasena.length < 8) return false;
    final tieneLetras = RegExp(r'[a-zA-Z]').hasMatch(contrasena);
    final tieneNumeros = RegExp(r'[0-9]').hasMatch(contrasena);
    return tieneLetras && tieneNumeros;
  }

  // Handler para registro con email
  Future<void> _manejarRegistro() async {
    final email = _controladorEmail.text.trim();
    final contrasena = _controladorContrasena.text;
    final confirmarContrasena = _controladorConfirmarContrasena.text;

    // Validaciones
    if (email.isEmpty) {
      _mostrarError('Por favor ingresa tu email');
      return;
    }

    if (!_esEmailValido(email)) {
      _mostrarError('Por favor ingresa un email válido');
      return;
    }

    if (contrasena.isEmpty) {
      _mostrarError('Por favor ingresa una contraseña');
      return;
    }

    if (!_esContrasenaSegura(contrasena)) {
      _mostrarError(
        'La contraseña debe tener al menos 8 caracteres, con letras y números',
      );
      return;
    }

    if (confirmarContrasena.isEmpty) {
      _mostrarError('Por favor confirma tu contraseña');
      return;
    }

    if (contrasena != confirmarContrasena) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    // Iniciar carga
    setState(() {
      _cargandoRegistro = true;
    });

    try {
      // Registrar usuario en Supabase con deep link para confirmación
      final supabase = ServicioSupabase();
      
      print('📝 Registrando usuario: $email');
      
      final respuesta = await supabase.cliente.auth.signUp(
        email: email,
        password: contrasena,
        emailRedirectTo: authRedirectUrlUsuarios,
      );

      print('📋 Respuesta signUp:');
      print('   User: ${respuesta.user?.email ?? "null"}');
      print('   Session: ${respuesta.session != null ? "activa" : "null"}');

      if (respuesta.user != null) {
        // Usuario creado o ya existe
        
        if (respuesta.session == null) {
          // No hay sesión - requiere confirmación de email
          print('📧 Requiere confirmación de email');

          if (mounted) {
            // Mensaje claro: cuenta creada, revisar email
            _mostrarExito(TraductorErroresAuth.mensajeSignupExitoso(email));

            // Esperar y volver al login
            await Future.delayed(const Duration(seconds: 3));

            if (mounted) {
              Navigator.of(context).pop(); // Volver al login
            }
          }
        } else {
          // Hay sesión activa - registro sin confirmación
          print('✅ Registro exitoso con sesión activa');
          print('⏳ Esperando a que AuthGate maneje la navegación...');

          // NO mostrar diálogo - AuthGate se encargará de navegar automáticamente
        }
      } else {
        // No se obtuvo usuario (raro pero posible)
        print('⚠️ No se obtuvo usuario en respuesta');
        
        if (mounted) {
          _mostrarError('No se pudo crear la cuenta.\n\nIntentá de nuevo.');
        }
      }
    } catch (error) {
      // Usar el traductor de errores centralizado
      print('❌ Error en signup: $error');
      
      if (mounted) {
        final mensajeError = TraductorErroresAuth.traducir(error);
        _mostrarError(mensajeError);
      }
    } finally {
      // Finalizar carga
      if (mounted) {
        setState(() {
          _cargandoRegistro = false;
        });
      }
    }
  }

  // Handler para OAuth con Google
  Future<void> _manejarGoogleSignIn() async {
    try {
      print('🔐 Iniciando registro con Google...');

      final supabase = ServicioSupabase();
      await supabase.cliente.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authRedirectUrlUsuarios,
      );

      // AuthGate se encarga del resto automáticamente
    } catch (error) {
      print('❌ Error en OAuth Google: $error');
      if (mounted) {
        _mostrarError('No se pudo conectar con Google.\n\nProbá de nuevo en unos segundos.');
      }
    }
  }


  // Mostrar diálogo de error
  void _mostrarError(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: ColoresApp.peligroMarca,
            ),
            const SizedBox(width: 8),
            const Text('Error'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo de éxito
  void _mostrarExito(String mensaje) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
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
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Continuar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo de advertencia (para confirmación de email)
  void _mostrarAdvertencia(String titulo, String mensaje) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            const Icon(CupertinoIcons.mail, color: ColoresApp.promoMarca),
            const SizedBox(width: 8),
            Text(titulo),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Entendido'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tamanioPantalla = MediaQuery.of(context).size;
    final anchoPantalla = tamanioPantalla.width;
    final padding = MediaQuery.of(context).padding;

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, padding.top + 32, 24, padding.bottom + 32),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(CupertinoIcons.back, color: ColoresApp.textoPrincipal),
                    ),
                    Expanded(
                      child: Image.asset(
                        'assets/imagenes/logoprincipal.png',
                        height: 32,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(CupertinoIcons.app, color: ColoresApp.principalMarca),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 24),
                // Título principal
                Text(
                  'Fernecito',
                  style: GoogleFonts.baloo2(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.principalMarca,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtítulo
                Text(
                  'Crea tu cuenta en 5 minutos!',
                  style: GoogleFonts.baloo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoPrincipal,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Campo de email
                _construirCampoTexto(
                  controlador: _controladorEmail,
                  placeholder: 'Email',
                  icono: CupertinoIcons.mail,
                  tipoTeclado: TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                // Campo de contraseña
                _construirCampoTexto(
                  controlador: _controladorContrasena,
                  placeholder: 'Contraseña',
                  icono: CupertinoIcons.lock,
                  esContrasena: true,
                  focusNode: _focusContrasena,
                  mostrarIconoOjo: true,
                  ocultarTexto: _ocultarContrasena,
                  onToggleVisibilidad: () {
                    setState(() {
                      _ocultarContrasena = !_ocultarContrasena;
                    });
                  },
                ),

                // Mensaje animado de requisitos de contraseña
                SizeTransition(
                  sizeFactor: _animacionMensaje,
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: _animacionMensaje,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColoresApp.principalMarca.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColoresApp.principalMarca.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.info_circle,
                            color: ColoresApp.principalMarca,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Usa al menos 8 caracteres con letras y números',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                color: ColoresApp.principalMarca,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Campo de confirmar contraseña
                _construirCampoTexto(
                  controlador: _controladorConfirmarContrasena,
                  placeholder: 'Repetir contraseña',
                  icono: CupertinoIcons.lock_fill,
                  esContrasena: true,
                  mostrarIconoOjo: true,
                  ocultarTexto: _ocultarConfirmarContrasena,
                  onToggleVisibilidad: () {
                    setState(() {
                      _ocultarConfirmarContrasena =
                          !_ocultarConfirmarContrasena;
                    });
                  },
                ),

                const SizedBox(height: 32),

                // Botón "Crea tu cuenta!"
                _construirBotonPrincipal(anchoPantalla),

                const SizedBox(height: 32),

                // Texto "O registrarse con"
                Text(
                  'O registrarse con',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: ColoresApp.textoSecundario,
                  ),
                ),

                const SizedBox(height: 16),

                // Botones de redes sociales
                _construirBotonesSociales(anchoPantalla),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        ),
    );
  }

  Widget _construirCampoTexto({
    required TextEditingController controlador,
    required String placeholder,
    required IconData icono,
    bool esContrasena = false,
    FocusNode? focusNode,
    TextInputType tipoTeclado = TextInputType.text,
    bool mostrarIconoOjo = false,
    bool ocultarTexto = true,
    VoidCallback? onToggleVisibilidad,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(icono, color: ColoresApp.principalMarca, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField(
              controller: controlador,
              focusNode: focusNode,
              placeholder: placeholder,
              placeholderStyle: TextStyle(
                color: ColoresApp.textoSecundario,
                fontSize: 16,
              ),
              style: const TextStyle(
                color: ColoresApp.textoPrincipal,
                fontSize: 16,
              ),
              decoration: const BoxDecoration(),
              obscureText: esContrasena && ocultarTexto,
              keyboardType: tipoTeclado,
              textInputAction: TextInputAction.next,
            ),
          ),
          if (mostrarIconoOjo)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onToggleVisibilidad,
              child: Icon(
                ocultarTexto ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                color: ColoresApp.textoSecundario,
                size: 20,
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _construirBotonPrincipal(double anchoPantalla) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _cargandoRegistro ? null : _manejarRegistro,
      child: Container(
        width: anchoPantalla * 0.85,
        height: 56,
        decoration: BoxDecoration(
          color: _cargandoRegistro
              ? ColoresApp.principalMarca.withOpacity(0.5)
              : ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: _cargandoRegistro
              ? const CupertinoActivityIndicator(
                  color: ColoresApp.textoPrincipal,
                )
              : Text(
                  'Crea tu cuenta!',
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _construirBotonesSociales(double anchoPantalla) {
    return Column(
      children: [
        // Botón de Google
        _BotonSocial(
          texto: 'Continuar con Google',
          icono: FontAwesomeIcons.google,
          colorFondo: ColoresApp.textoPrincipal,
          colorTexto: ColoresApp.fondoPrincipal,
          ancho: anchoPantalla * 0.85,
          onPressed: _cargandoRegistro ? () {} : _manejarGoogleSignIn,
        ),
      ],
    );
  }
}

/// Widget reutilizable para botones sociales (Google)
class _BotonSocial extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color colorFondo;
  final Color colorTexto;
  final double ancho;
  final VoidCallback onPressed;

  const _BotonSocial({
    required this.texto,
    required this.icono,
    required this.colorFondo,
    required this.colorTexto,
    required this.ancho,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: ancho,
        height: 56,
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icono, color: colorTexto, size: 20),
            const SizedBox(width: 12),
            Text(
              texto,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
