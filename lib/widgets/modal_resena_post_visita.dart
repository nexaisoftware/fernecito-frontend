/// Modal post-visita: pedir reseña después de un evento terminado.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/servicio_resena_post_visita.dart';
import '../core/supabase_client.dart';
import 'avatar_local.dart';
import 'fernecito_loader.dart';

/// Muestra el modal si hay una visita pendiente. Devuelve true si se publicó.
Future<bool> mostrarModalResenaPostVisita(
  BuildContext context, {
  required PendienteResenaPostVisita pendiente,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Reseña',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: c.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - c.value)),
          child: _ModalResenaPostVisita(pendiente: pendiente),
        ),
      );
    },
  );
  return result == true;
}

class _ModalResenaPostVisita extends StatefulWidget {
  const _ModalResenaPostVisita({required this.pendiente});

  final PendienteResenaPostVisita pendiente;

  @override
  State<_ModalResenaPostVisita> createState() => _ModalResenaPostVisitaState();
}

class _ModalResenaPostVisitaState extends State<_ModalResenaPostVisita> {
  final _texto = TextEditingController();
  final _focus = FocusNode();

  int _estrellas = 5;
  bool _enviando = false;
  bool _mostrarCerrar = false;
  Timer? _timerCerrar;

  bool get _requiereTexto => _estrellas <= 4;

  bool get _puedeCalificar {
    if (_enviando) return false;
    if (_estrellas < 1 || _estrellas > 5) return false;
    if (_requiereTexto && _texto.text.trim().isEmpty) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _texto.addListener(() {
      if (mounted) setState(() {});
    });
    // Al mostrar: ignorado (si cierra la app sin decidir, no vuelve a salir).
    unawaited(
      ServicioResenaPostVisita.instancia.marcarCalificado(
        widget.pendiente.idToken,
        'ignorado',
      ),
    );
    _timerCerrar = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _mostrarCerrar = true);
    });
  }

  @override
  void dispose() {
    _timerCerrar?.cancel();
    _texto.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _cerrar({
    required String calificado,
    bool publicado = false,
  }) async {
    await ServicioResenaPostVisita.instancia.marcarCalificado(
      widget.pendiente.idToken,
      calificado,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(publicado);
  }

  Future<void> _publicar() async {
    if (!_puedeCalificar) return;
    setState(() => _enviando = true);
    _focus.unfocus();
    try {
      await ServicioSupabase().cliente.rpc(
        'publicar_resena_post_visita',
        params: {
          'p_id_token': widget.pendiente.idToken,
          'p_estrellas': _estrellas,
          'p_comentario': _texto.text.trim(),
        },
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
    } on PostgrestException catch (e) {
      debugPrint('⚠️ post-visita publicar_resena: ${e.message}');
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarError(_mensajeError(e.message));
    } catch (e) {
      debugPrint('⚠️ post-visita publicar_resena: $e');
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarError('No pudimos publicar tu reseña. Intentá de nuevo.');
    }
  }

  String _mensajeError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('rate_limit')) {
      return 'Ya publicaste varias reseñas hoy. Probá más tarde.';
    }
    if (s.contains('unauthorized')) return 'Iniciá sesión para reseñar.';
    return 'No pudimos publicar tu reseña. Intentá de nuevo.';
  }

  void _mostrarError(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('No se pudo publicar'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pendiente;
    final placeholder = _requiereTexto
        ? 'Contanos más sobre tu experiencia…'
        : 'Escribir reseña (opcional)…';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ColoresApp.principalMarca.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _mostrarCerrar ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: IgnorePointer(
                        ignoring: !_mostrarCerrar,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                          onPressed: _enviando
                              ? null
                              : () => _cerrar(calificado: 'no'),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 28,
                            color: ColoresApp.textoSecundario.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '¡Visitaste ${p.nombreLocal}!',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textoPrincipal,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dejale una reseña',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 18),
              AvatarLocal(
                imageUrl: p.avatarUrl,
                size: 88,
                esPionero: p.esPionero,
                memCacheWidth: 200,
              ),
              const SizedBox(height: 8),
              Text(
                p.nombreLocal,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 16),
              _EstrellasTactiles(
                valor: _estrellas,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _estrellas = v);
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: ColoresApp.fondoPrincipal.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _requiereTexto && _texto.text.trim().isEmpty
                        ? ColoresApp.principalMarca.withValues(alpha: 0.35)
                        : ColoresApp.textoSecundario.withValues(alpha: 0.15),
                  ),
                ),
                child: CupertinoTextField(
                  controller: _texto,
                  focusNode: _focus,
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  enabled: !_enviando,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  placeholder: placeholder,
                  placeholderStyle: GoogleFonts.baloo2(
                    fontSize: 14,
                    color: ColoresApp.textoSecundario,
                  ),
                  style: GoogleFonts.baloo2(
                    fontSize: 14.5,
                    color: ColoresApp.textoPrincipal,
                  ),
                  decoration: const BoxDecoration(color: Colors.transparent),
                ),
              ),
              if (_requiereTexto) ...[
                const SizedBox(height: 8),
                Text(
                  'Con 4 estrellas o menos, contanos qué pasó.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: _puedeCalificar
                      ? ColoresApp.principalMarca
                      : ColoresApp.textoSecundario.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _puedeCalificar ? _publicar : null,
                  child: _enviando
                      ? const FernecitoLoader.inline(
                          size: 18,
                          color: Colors.black,
                        )
                      : Text(
                          'Calificar',
                          style: GoogleFonts.baloo2(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _puedeCalificar
                                ? Colors.black
                                : ColoresApp.textoSecundario,
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

class _EstrellasTactiles extends StatelessWidget {
  const _EstrellasTactiles({required this.valor, required this.onChanged});

  final int valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final n = i + 1;
        final activa = n <= valor;
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(40, 40),
          onPressed: () => onChanged(n),
          child: Icon(
            activa ? CupertinoIcons.star_fill : CupertinoIcons.star,
            size: 36,
            color: activa
                ? ColoresApp.principalMarca
                : ColoresApp.textoSecundario.withValues(alpha: 0.45),
          ),
        );
      }),
    );
  }
}
