/// Cambiar contraseña (logueado) — estilo Fernecito Cupertino
/// con tema oscuro de la app.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../widgets/fondo_gradiente_fernecito.dart';

class PantallaCambiarContrasena extends StatefulWidget {
  const PantallaCambiarContrasena({super.key});

  @override
  State<PantallaCambiarContrasena> createState() =>
      _PantallaCambiarContrasenaState();
}

class _PantallaCambiarContrasenaState extends State<PantallaCambiarContrasena> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();
  bool _ocultarActual = true;
  bool _ocultarNueva = true;
  bool _ocultarRepetir = true;
  bool _procesando = false;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  bool _esValida(String s) =>
      s.length >= 8 &&
      RegExp(r'[a-zA-Z]').hasMatch(s) &&
      RegExp(r'[0-9]').hasMatch(s);

  Future<void> _cambiar() async {
    if (_procesando) return;
    HapticFeedback.selectionClick();

    final actual = _actual.text;
    final nueva = _nueva.text;
    final repetir = _repetir.text;

    if (actual.isEmpty || nueva.isEmpty || repetir.isEmpty) {
      _alert('Completá los tres campos.');
      return;
    }
    if (!_esValida(nueva)) {
      _alert('La nueva debe tener mínimo 8 caracteres,\n'
          'una letra y un número.');
      return;
    }
    if (nueva != repetir) {
      _alert('Las contraseñas nuevas no coinciden.');
      return;
    }
    if (nueva == actual) {
      _alert('La nueva tiene que ser distinta a la actual.');
      return;
    }

    final sb = Supabase.instance.client;
    final email = sb.auth.currentUser?.email;
    if (email == null) {
      _alert('Sesión inválida. Volvé a iniciar sesión.');
      return;
    }

    setState(() => _procesando = true);
    try {
      await sb.auth.signInWithPassword(email: email, password: actual);
      await sb.auth.updateUser(UserAttributes(password: nueva));

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listo, tu contraseña fue actualizada.',
              style: GoogleFonts.baloo2()),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase().contains('credentials')
          ? 'La contraseña actual es incorrecta.'
          : 'No pudimos cambiar la contraseña: ${e.message}';
      _alert(msg);
    } catch (e) {
      _alert('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _alert(String msg) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          'No se pudo cambiar',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w900),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg, style: GoogleFonts.baloo2()),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.principalMarca)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ColoresApp.textoPrincipal),
        title: Text(
          'Cambiar contraseña',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w900,
            color: ColoresApp.textoPrincipal,
            fontSize: 18,
          ),
        ),
      ),
      body: FondoGradienteFernecito(
        corto: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero ───────────────────────────────────────────
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: ColoresApp.principalMarca.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.lock_rotation,
                          size: 48,
                          color: ColoresApp.principalMarca,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Actualizá tu contraseña',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu sesión queda activa.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 13.5,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Campos ─────────────────────────────────────────
                    _CampoPass(
                      placeholder: 'Contraseña actual',
                      controller: _actual,
                      ocultar: _ocultarActual,
                      onToggle: () =>
                          setState(() => _ocultarActual = !_ocultarActual),
                      autofocus: true,
                    ),
                    const SizedBox(height: 14),
                    _CampoPass(
                      placeholder: 'Nueva contraseña',
                      controller: _nueva,
                      ocultar: _ocultarNueva,
                      onChanged: (_) => setState(() {}),
                      onToggle: () =>
                          setState(() => _ocultarNueva = !_ocultarNueva),
                    ),
                    const SizedBox(height: 14),
                    _CampoPass(
                      placeholder: 'Repetir nueva contraseña',
                      controller: _repetir,
                      ocultar: _ocultarRepetir,
                      onToggle: () =>
                          setState(() => _ocultarRepetir = !_ocultarRepetir),
                    ),

                    const SizedBox(height: 16),
                    _ReglasContrasena(valor: _nueva.text),

                    const SizedBox(height: 24),

                    // ── CTA ───────────────────────────────────────────
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _procesando ? null : _cambiar,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: _procesando
                              ? ColoresApp.principalMarca.withOpacity(0.5)
                              : ColoresApp.principalMarca,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _procesando
                              ? const CupertinoActivityIndicator(
                                  color: ColoresApp.textoPrincipal)
                              : Text(
                                  'Cambiar contraseña',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ColoresApp.textoPrincipal,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Helper ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ColoresApp.fondoSuperficie.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ColoresApp.principalMarca.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(CupertinoIcons.info_circle,
                              size: 18,
                              color: ColoresApp.principalMarca),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '¿Olvidaste la actual? Cerrá sesión y desde el login usá "¿Olvidaste tu contraseña?" o escribinos a soporte.',
                              style: GoogleFonts.baloo2(
                                fontSize: 12.5,
                                color: ColoresApp.textoSecundario,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CampoPass — mismo patrón que el TextField del login (Container con sombra
// + CupertinoTextField sin decoración interna)
// ═══════════════════════════════════════════════════════════════════════════
class _CampoPass extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final bool ocultar;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const _CampoPass({
    required this.placeholder,
    required this.controller,
    required this.ocultar,
    required this.onToggle,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(CupertinoIcons.lock,
              color: ColoresApp.textoSecundario, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              placeholder: placeholder,
              placeholderStyle: GoogleFonts.baloo2(
                color: ColoresApp.textoSecundario,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(),
              obscureText: ocultar,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(right: 18, left: 4),
            onPressed: onToggle,
            child: Icon(
              ocultar ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              color: ColoresApp.textoSecundario,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reglas en vivo
// ═══════════════════════════════════════════════════════════════════════════
class _ReglasContrasena extends StatelessWidget {
  final String valor;
  const _ReglasContrasena({required this.valor});

  @override
  Widget build(BuildContext context) {
    final largo = valor.length >= 8;
    final letra = RegExp(r'[a-zA-Z]').hasMatch(valor);
    final num = RegExp(r'[0-9]').hasMatch(valor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _regla('Mínimo 8 caracteres', largo),
          _regla('Al menos 1 letra', letra),
          _regla('Al menos 1 número', num),
        ],
      ),
    );
  }

  Widget _regla(String txt, bool ok) {
    final okColor = const Color(0xFF4ADE80);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.circle,
            size: 15,
            color: ok ? okColor : ColoresApp.textoSecundario,
          ),
          const SizedBox(width: 8),
          Text(
            txt,
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              color: ok ? okColor : ColoresApp.textoSecundario,
              fontWeight: ok ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
