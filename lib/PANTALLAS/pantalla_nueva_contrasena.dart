/// Pantalla unificada para recuperación de contraseña con código de 8 dígitos.
///
/// Flujo:
/// 1. Usuario ingresa email → se envía código por email (Supabase).
/// 2. Misma pantalla muestra: código 8 dígitos + nueva contraseña + confirmar.
/// 3. Al confirmar: verifyOTP (recovery) + updateUser(password) → éxito → Login.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/auth_gate.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../core/auth_errors.dart';
import '../core/recovery_flow_flag.dart';
import '../core/supabase_client.dart';
import '../core/auth_redirect.dart';
import 'pantalla_login.dart';

enum _PasoRecuperacion { email, codigo, password }

class PantallaNuevaContrasena extends StatefulWidget {
  const PantallaNuevaContrasena({super.key});

  @override
  State<PantallaNuevaContrasena> createState() =>
      _PantallaNuevaContrasenaState();
}

class _PantallaNuevaContrasenaState extends State<PantallaNuevaContrasena> {
  _PasoRecuperacion _paso = _PasoRecuperacion.email;

  final TextEditingController _controladorEmail = TextEditingController();
  final TextEditingController _controladorCodigo = TextEditingController();
  final TextEditingController _controladorPassword = TextEditingController();
  final TextEditingController _controladorPasswordConfirm =
      TextEditingController();

  /// Email al que se envió el código (para verifyOTP).
  String _emailEnviado = '';

  bool _ocultarPassword = true;
  bool _ocultarPasswordConfirm = true;
  bool _procesando = false;

  final FocusNode _focusCodigo = FocusNode();
  final FocusNode _focusPassword = FocusNode();
  final FocusNode _focusPasswordConfirm = FocusNode();

  String get _codigoIngresado => _controladorCodigo.text.trim();

  @override
  void initState() {
    super.initState();
    // Referencia explícita para mantener compatibilidad en hot-reload.
    _intentarConfirmarSiListo();
    _focusCodigo.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusCodigo.dispose();
    _focusPassword.dispose();
    _focusPasswordConfirm.dispose();
    _controladorEmail.dispose();
    _controladorCodigo.dispose();
    _controladorPassword.dispose();
    _controladorPasswordConfirm.dispose();
    super.dispose();
  }

  /// Compatibilidad para sesiones con hot-reload previo que dejaron este listener activo.
  /// Se mantiene intencionalmente para evitar crash "no instance method".
  void _intentarConfirmarSiListo() {}

  Future<void> _mostrarExitoYEnfocarCodigo(String mensaje) async {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.checkmark_circle,
                color: ColoresApp.principalMarca),
            const SizedBox(width: 8),
            const Flexible(child: Text('Listo')),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (mounted) {
      // Pequeño delay para evitar colisión de eventos de teclado al cerrar dialog.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _focusCodigo.requestFocus();
      });
    }
  }

  void _limpiarCodigo() {
    _controladorCodigo.clear();
  }

  void _onCodigoChanged(String value) {
    if (_procesando) return;
    final limpio = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (limpio != value) {
      _controladorCodigo.value = TextEditingValue(
        text: limpio,
        selection: TextSelection.collapsed(offset: limpio.length),
      );
    }
    setState(() {});
    if (limpio.length == 8) {
      FocusScope.of(context).unfocus();
      _verificarCodigo();
    }
  }

  /// Paso 1: enviar código al email.
  Future<void> _enviarCodigo() async {
    final email = _controladorEmail.text.trim();

    if (email.isEmpty) {
      _mostrarError('Ingresá tu email');
      return;
    }
    if (!email.contains('@')) {
      _mostrarError('Ingresá un email válido');
      return;
    }

    setState(() => _procesando = true);

    try {
      final supabase = ServicioSupabase();
      await supabase.cliente.auth.resetPasswordForEmail(
        email,
        redirectTo: authRedirectUrlUsuarios,
      );

      if (mounted) {
        setState(() {
          _paso = _PasoRecuperacion.codigo;
          _emailEnviado = email;
          _procesando = false;
        });
        await _mostrarExitoYEnfocarCodigo(
          'Revisá tu email.\n\n'
          'Te enviamos un código de 8 dígitos. Ingresalo abajo.',
        );
      }
    } catch (e, st) {
      // Log para debug: ver si es rate limit, red, o config
      print('❌ Error enviando código recuperación: $e');
      print('❌ Stack: $st');
      if (mounted) {
        setState(() => _procesando = false);
        final mensaje = TraductorErroresAuth.traducir(e);
        _mostrarError(mensaje);
      }
    }
  }

  /// Permite avanzar al paso de código sin reenviar email (útil si ya lo recibiste).
  void _continuarConCodigoSinReenviar() {
    final email = _controladorEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _mostrarError('Ingresá el mismo email al que te llegó el código.');
      return;
    }
    setState(() {
      _emailEnviado = email;
      _paso = _PasoRecuperacion.codigo;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCodigo.requestFocus();
    });
  }

  /// Paso 2: verificar token OTP de 8 dígitos.
  Future<void> _verificarCodigo() async {
    final codigo = _codigoIngresado.trim();
    if (codigo.length != 8) {
      _mostrarError('Ingresá el código completo de 8 dígitos.');
      return;
    }
    setState(() => _procesando = true);
    RecoveryFlowFlag.activar();
    try {
      final supabase = ServicioSupabase();
      await supabase.cliente.auth.verifyOTP(
        type: OtpType.recovery,
        token: codigo,
        email: _emailEnviado,
      );
      if (!mounted) return;
      setState(() {
        _paso = _PasoRecuperacion.password;
        _procesando = false;
      });
      _mostrarExito('Código verificado ✅\n\nAhora elegí tu nueva contraseña.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusPassword.requestFocus();
      });
    } catch (e) {
      if (mounted) {
        RecoveryFlowFlag.desactivar();
        setState(() => _procesando = false);
        final mensaje = TraductorErroresAuth.traducir(e);
        _mostrarError(mensaje);
      }
    }
  }

  /// Paso 3: actualizar contraseña (requiere token ya verificado).
  Future<void> _confirmarNuevaContrasena() async {
    final password = _controladorPassword.text.trim();
    final passwordConfirm = _controladorPasswordConfirm.text.trim();

    if (password.isEmpty || passwordConfirm.isEmpty) {
      _mostrarError('Completá la nueva contraseña y la confirmación.');
      return;
    }
    if (password.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (password != passwordConfirm) {
      _mostrarError('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _procesando = true);
    RecoveryFlowFlag.activar();

    try {
      final supabase = ServicioSupabase();
      await supabase.cliente.auth.updateUser(
        UserAttributes(password: password),
      );

      if (mounted) {
        RecoveryFlowFlag.desactivar();
        await ServicioSupabase().cliente.auth.signOut();
        setState(() => _procesando = false);
        _mostrarExito(
          'Contraseña actualizada correctamente.\n\n'
          'Ya podés iniciar sesión con tu nueva contraseña.',
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pop();
        final navigator = navigatorKey.currentState;
        if (navigator != null && mounted) {
          navigator.pushAndRemoveUntil(
            CupertinoPageRoute(
              builder: (context) => const PantallaLogin(),
              maintainState: false,
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        RecoveryFlowFlag.desactivar();
        setState(() => _procesando = false);
        final mensaje = TraductorErroresAuth.traducir(e);
        _mostrarError(mensaje);
      }
    }
  }

  /// Reenviar código al mismo email.
  Future<void> _reenviarCodigo() async {
    if (_emailEnviado.isEmpty) return;
    setState(() => _procesando = true);
    try {
      final supabase = ServicioSupabase();
      await supabase.cliente.auth.resend(
        type: OtpType.recovery,
        email: _emailEnviado,
      );
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarExito('Te reenviamos el código. Revisá tu email.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarError('No se pudo reenviar. Probá de nuevo en un momento.');
      }
    }
  }

  void _mostrarError(String mensaje) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle,
                color: ColoresApp.peligroMarca),
            const SizedBox(width: 8),
            const Flexible(child: Text('Error')),
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

  void _mostrarExito(String mensaje) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(CupertinoIcons.checkmark_circle,
                color: ColoresApp.principalMarca),
            const SizedBox(width: 8),
            const Flexible(child: Text('Listo')),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, padding.top + 24, 24, padding.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (_paso != _PasoRecuperacion.email) {
                        setState(() {
                          _paso = _PasoRecuperacion.email;
                          _limpiarCodigo();
                          _controladorPassword.clear();
                          _controladorPasswordConfirm.clear();
                        });
                        RecoveryFlowFlag.desactivar();
                        FocusScope.of(context).unfocus();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Icon(CupertinoIcons.back,
                        color: ColoresApp.principalMarca),
                  ),
                  Expanded(
                    child: Text(
                      _paso == _PasoRecuperacion.email
                          ? 'Recuperar contraseña'
                          : 'Nueva contraseña',
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 24),

              if (_paso == _PasoRecuperacion.email) ...[
                _buildPasoEmail(padding),
              ] else if (_paso == _PasoRecuperacion.codigo) ...[
                _buildPasoCodigo(padding),
              ] else ...[
                _buildPasoPassword(padding),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasoEmail(EdgeInsets padding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                CupertinoIcons.lock_rotation,
                size: 80,
                color: ColoresApp.principalMarca,
              ),
              const SizedBox(height: 24),
              Text(
                '¿Olvidaste tu contraseña?',
                style: GoogleFonts.baloo2(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Ingresá tu email y te enviamos un código de 8 dígitos para crear una nueva contraseña.',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: ColoresApp.textoSecundario,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        _buildCampoEmail(),
        const SizedBox(height: 24),
        Center(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _procesando ? null : _continuarConCodigoSinReenviar,
            child: Text(
              'Ya tengo código',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.principalMarca,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildBoton('Enviar código', _procesando, _enviarCodigo),
      ],
    );
  }

  Widget _buildPasoCodigo(EdgeInsets padding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                CupertinoIcons.lock_shield,
                size: 80,
                color: ColoresApp.principalMarca,
              ),
              const SizedBox(height: 24),
              Text(
                'Verificá tu código',
                style: GoogleFonts.baloo2(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Ingresá el código de 8 dígitos que te llegó por email para validar tu identidad.',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: ColoresApp.textoSecundario,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Código',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        const SizedBox(height: 12),
        _buildCodigoOtp(),
        const SizedBox(height: 16),
        Center(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _procesando ? null : _reenviarCodigo,
            child: Text(
              'Reenviar código',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.principalMarca,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildBoton('Verificar código', _procesando, _verificarCodigo),
      ],
    );
  }

  Widget _buildPasoPassword(EdgeInsets padding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                CupertinoIcons.lock_shield,
                size: 80,
                color: ColoresApp.principalMarca,
              ),
              const SizedBox(height: 24),
              Text(
                'Nueva contraseña',
                style: GoogleFonts.baloo2(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Código verificado. Ahora elegí y confirmá tu nueva contraseña.',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: ColoresApp.textoSecundario,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildCampoPassword(),
        const SizedBox(height: 24),
        _buildCampoPasswordConfirm(),
        const SizedBox(height: 24),
        _buildBoton('Guardar nueva contraseña', _procesando, _confirmarNuevaContrasena),
      ],
    );
  }

  Widget _buildCampoEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _controladorEmail,
          placeholder: 'tu@email.com',
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(color: ColoresApp.textoPrincipal),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: ColoresApp.textoSecundario.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(CupertinoIcons.mail, color: ColoresApp.principalMarca),
          ),
        ),
      ],
    );
  }

  Widget _buildCodigoOtp() {
    final placeholderStyle = GoogleFonts.baloo2(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: ColoresApp.textoSecundario.withOpacity(0.35),
    );
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusCodigo.requestFocus(),
        child: Column(
          children: [
            SizedBox(
              width: 1,
              height: 1,
              child: CupertinoTextField(
                controller: _controladorCodigo,
                focusNode: _focusCodigo,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                onChanged: _onCodigoChanged,
                onSubmitted: (_) => _verificarCodigo(),
                style: const TextStyle(
                  color: Color(0x00000000),
                  fontSize: 1,
                ),
                cursorColor: const Color(0x00000000),
                decoration: const BoxDecoration(
                  color: Color(0x00000000),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(8, (index) {
                  final digit = index < _codigoIngresado.length
                      ? _codigoIngresado[index]
                      : '−';
                  final isFocusedSlot = _focusCodigo.hasFocus &&
                      index == _codigoIngresado.length.clamp(0, 7);
                  return Padding(
                    padding: EdgeInsets.only(right: index == 7 ? 0 : 6),
                    child: Container(
                      width: 36,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ColoresApp.fondoSuperficie,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFocusedSlot
                              ? ColoresApp.principalMarca
                              : ColoresApp.textoSecundario.withOpacity(0.28),
                          width: isFocusedSlot ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        digit,
                        style: digit == '−'
                            ? placeholderStyle
                            : GoogleFonts.baloo2(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.textoPrincipal,
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nueva contraseña',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _controladorPassword,
          focusNode: _focusPassword,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _focusPasswordConfirm.requestFocus(),
          placeholder: 'Mínimo 6 caracteres',
          obscureText: _ocultarPassword,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: ColoresApp.textoPrincipal),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: ColoresApp.textoSecundario.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(CupertinoIcons.lock, color: ColoresApp.principalMarca),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                _ocultarPassword
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                color: ColoresApp.textoSecundario,
              ),
              onPressed: () =>
                  setState(() => _ocultarPassword = !_ocultarPassword),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoPasswordConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirmar contraseña',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: _controladorPasswordConfirm,
          focusNode: _focusPasswordConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirmarNuevaContrasena(),
          placeholder: 'Repetí tu nueva contraseña',
          obscureText: _ocultarPasswordConfirm,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(color: ColoresApp.textoPrincipal),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: ColoresApp.textoSecundario.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(CupertinoIcons.lock, color: ColoresApp.principalMarca),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                _ocultarPasswordConfirm
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                color: ColoresApp.textoSecundario,
              ),
              onPressed: () => setState(
                  () => _ocultarPasswordConfirm = !_ocultarPasswordConfirm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoton(String texto, bool procesando, VoidCallback onPressed) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: procesando ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: procesando
              ? ColoresApp.principalMarca.withOpacity(0.5)
              : ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: procesando
              ? const CupertinoActivityIndicator(
                  color: ColoresApp.textoPrincipal,
                )
              : Text(
                  texto,
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
}
