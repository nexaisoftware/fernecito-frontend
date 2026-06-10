/// Pantalla de reseñas de un local (app usuarios).
///
/// Flujo:
/// - Formulario de estrellas + comentario si no tiene reseñas, o al tocar "Agregar otra reseña".
/// - Tus reseñas en este local (puede haber varias; backend limita 5/día).
/// - Debajo: reseñas de otros usuarios.
///
/// Backend:
/// - Escritura: RPC atómico `publicar_resena(p_id_local, p_estrellas, p_comentario)`
///   que valida JWT, anti-spam (token canjeado), UNIQUE y recalcula promedio.
/// - Lectura: query directa a `reviews_locales` JOIN `perfiles_usuarios`
///   (RLS SELECT abierta a authenticated).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/fondo_gradiente_fernecito.dart';

class PantallaResenasLocales extends StatefulWidget {
  final String nombreLocal;
  final String? idLocal;

  const PantallaResenasLocales({
    super.key,
    required this.nombreLocal,
    this.idLocal,
  });

  @override
  State<PantallaResenasLocales> createState() =>
      _PantallaResenasLocalesState();
}

class _PantallaResenasLocalesState extends State<PantallaResenasLocales> {
  final TextEditingController _textoController = TextEditingController();
  final FocusNode _focusComentario = FocusNode();

  int _misEstrellas = 0;
  bool _cargando = true;
  bool _enviando = false;

  /// Reseñas de este local (todas).
  List<Map<String, dynamic>> _resenas = [];

  /// Mis reseñas en este local (puede haber más de una).
  List<Map<String, dynamic>> _misResenas = [];

  /// Si ya tengo reseñas, el formulario arranca oculto hasta "Agregar otra reseña".
  bool _mostrarFormNuevaResena = false;

  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = ServicioSupabase().cliente.auth.currentUser?.id;
    _cargar();
  }

  @override
  void dispose() {
    _textoController.dispose();
    _focusComentario.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (widget.idLocal == null || widget.idLocal!.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final sb = ServicioSupabase().cliente;
    try {
      // 1. Reseñas + perfil del autor (JOIN embebido)
      final res = await sb
          .from('reviews_locales')
          .select(
              'id_review, id_usuario, estrellas, comentario, fecha_creacion, '
              'perfiles_usuarios:id_usuario(username, nombre, foto_perfil_url)')
          .eq('id_local', widget.idLocal!)
          .order('fecha_creacion', ascending: false);
      final lista = List<Map<String, dynamic>>.from(res as List);

      final mis = _userId == null
          ? <Map<String, dynamic>>[]
          : lista
              .where((r) => r['id_usuario']?.toString() == _userId)
              .toList();

      if (!mounted) return;
      setState(() {
        _resenas = lista;
        _misResenas = mis;
        _cargando = false;
      });
    } catch (e, st) {
      debugPrint('⚠️ Reseñas cargar: $e\n$st');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _publicar() async {
    if (_enviando) return;
    if (_misEstrellas < 1 || _misEstrellas > 5) {
      _toast('Elegí una calificación de 1 a 5 estrellas.');
      return;
    }
    if (widget.idLocal == null || widget.idLocal!.isEmpty) {
      _toast('No pudimos identificar este local.');
      return;
    }
    setState(() => _enviando = true);
    _focusComentario.unfocus();
    final sb = ServicioSupabase().cliente;
    try {
      final resp = await sb.rpc('publicar_resena', params: {
        'p_id_local': widget.idLocal,
        'p_estrellas': _misEstrellas,
        'p_comentario': _textoController.text.trim(),
      });
      debugPrint('✅ publicar_resena resp: $resp');
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _textoController.clear();
        _misEstrellas = 0;
        _mostrarFormNuevaResena = false;
      });
      await _cargar();
      if (mounted) _mostrarDialogoExito();
    } on PostgrestException catch (e) {
      debugPrint('⚠️ publicar_resena PostgrestException: ${e.code} ${e.message}');
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarError(_mensajeError(e.message));
    } catch (e) {
      debugPrint('⚠️ publicar_resena error: $e');
      if (!mounted) return;
      setState(() => _enviando = false);
      _mostrarError(_mensajeError(e.toString()));
    }
  }

  String _mensajeError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('unauthorized')) return 'Iniciá sesión para reseñar.';
    if (s.contains('account_not_active')) {
      return 'Tu cuenta no está activa. Contactá a soporte si creés que es un error.';
    }
    if (s.contains('rate_limit_exceeded')) {
      return 'Ya publicaste varias reseñas hoy. Volvé a intentar en unas horas (máximo 5 por día).';
    }
    if (s.contains('invalid_stars')) return 'Elegí una calificación de 1 a 5.';
    if (s.contains('comment_too_long')) return 'El comentario es muy largo (máx 500 caracteres).';
    if (s.contains('local_not_found')) return 'Este local ya no está disponible.';
    if (s.contains('duplicate_review')) {
      return 'No pudimos publicar: parece un duplicado. Probá de nuevo en unos segundos.';
    }
    if (s.contains('network') || s.contains('socket') || s.contains('timeout')) {
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    }
    return 'No pudimos publicar tu reseña. Intentá de nuevo en unos momentos.';
  }

  void _toast(String msg) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg)),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoExito() {
    HapticFeedback.mediumImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.88 + 0.12 * c.value,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(ColoresApp.fondoSuperficie,
                          ColoresApp.principalMarca, 0.12)!,
                      ColoresApp.fondoSuperficie,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ColoresApp.principalMarca.withOpacity(0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColoresApp.principalMarca.withOpacity(0.35),
                      blurRadius: 36,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            ColoresApp.principalMarca.withOpacity(0.4),
                            ColoresApp.principalMarca.withOpacity(0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: ColoresApp.principalMarca,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ColoresApp.principalMarca.withOpacity(0.55),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(CupertinoIcons.star_fill,
                            size: 30, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '¡Reseña publicada!',
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gracias por compartir tu experiencia. Esto ayuda a la comunidad de Fernecito.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 13.5,
                        color: ColoresApp.textoSecundario,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: ColoresApp.principalMarca,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Listo',
                          style: GoogleFonts.baloo2(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarError(String msg) {
    HapticFeedback.heavyImpact();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill,
                color: ColoresApp.peligroMarca, size: 18),
            const SizedBox(width: 6),
            const Text('No se pudo publicar'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(msg),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _resenasDeOtros {
    if (_userId == null) return _resenas;
    return _resenas
        .where((r) => r['id_usuario']?.toString() != _userId)
        .toList();
  }

  void _abrirFormNuevaResena() {
    HapticFeedback.selectionClick();
    setState(() {
      _mostrarFormNuevaResena = true;
      _misEstrellas = 0;
      _textoController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusComentario.requestFocus();
    });
  }

  void _cerrarFormNuevaResena() {
    _focusComentario.unfocus();
    setState(() {
      _mostrarFormNuevaResena = false;
      _misEstrellas = 0;
      _textoController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SafeArea(
          child: Column(
            children: [
              _AppBarLocal(nombre: widget.nombreLocal),
              Expanded(
                child: _cargando
                    ? const Center(child: CupertinoActivityIndicator(radius: 14))
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          if (_userId != null &&
                              (_misResenas.isEmpty || _mostrarFormNuevaResena))
                            SliverToBoxAdapter(
                              child: _buildFormPublicar(
                                esNuevaResena: _misResenas.isNotEmpty,
                              ),
                            ),
                          if (_userId != null &&
                              _misResenas.isNotEmpty &&
                              !_mostrarFormNuevaResena)
                            SliverToBoxAdapter(
                              child: _buildBotonAgregarOtraResena(),
                            ),
                          if (_misResenas.isNotEmpty)
                            SliverToBoxAdapter(child: _buildMisResenas()),
                          SliverToBoxAdapter(child: _buildHeaderListado()),
                          if (_resenasDeOtros.isEmpty)
                            SliverToBoxAdapter(child: _buildEmptyOtros())
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final r = _resenasDeOtros[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _CardResena(resena: r),
                                    );
                                  },
                                  childCount: _resenasDeOtros.length,
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
    );
  }

  Widget _buildBotonAgregarOtraResena() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _abrirFormNuevaResena,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ColoresApp.principalMarca.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ColoresApp.principalMarca.withOpacity(0.45),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.plus_circle_fill,
                size: 20,
                color: ColoresApp.principalMarca,
              ),
              const SizedBox(width: 8),
              Text(
                'Agregar otra reseña',
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.principalMarca,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormPublicar({bool esNuevaResena = false}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColoresApp.fondoSuperficie,
            Color.lerp(ColoresApp.fondoSuperficie,
                ColoresApp.principalMarca, 0.12)!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ColoresApp.principalMarca.withOpacity(0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: ColoresApp.principalMarca.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.star_fill,
                  size: 18, color: ColoresApp.principalMarca),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  esNuevaResena ? 'Nueva reseña' : 'Tu reseña',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ),
              if (esNuevaResena)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  onPressed: _cerrarFormNuevaResena,
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 22,
                    color: ColoresApp.textoSecundario.withOpacity(0.85),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Selector estrellas
          _SelectorEstrellas(
            valor: _misEstrellas,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _misEstrellas = v);
            },
          ),
          if (_misEstrellas > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _labelEstrellas(_misEstrellas),
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  color: ColoresApp.principalMarca,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 14),
          // TextField
          Container(
            decoration: BoxDecoration(
              color: ColoresApp.fondoPrincipal.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColoresApp.textoSecundario.withOpacity(0.18),
              ),
            ),
            child: CupertinoTextField(
              controller: _textoController,
              focusNode: _focusComentario,
              maxLines: 4,
              minLines: 3,
              maxLength: 500,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              placeholder: 'Contá tu experiencia (opcional)…',
              placeholderStyle: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.textoSecundario,
              ),
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.textoPrincipal,
                height: 1.4,
              ),
              cursorColor: ColoresApp.principalMarca,
              decoration: const BoxDecoration(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 13),
              color: _misEstrellas > 0
                  ? ColoresApp.principalMarca
                  : ColoresApp.principalMarca.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              onPressed: _misEstrellas > 0 && !_enviando ? _publicar : null,
              child: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CupertinoActivityIndicator(color: Colors.black),
                    )
                  : Text(
                      _misEstrellas > 0 ? 'Publicar reseña' : 'Elegí estrellas',
                      style: GoogleFonts.baloo2(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMisResenas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.checkmark_seal_fill,
                  size: 16, color: ColoresApp.principalMarca),
              const SizedBox(width: 6),
              Text(
                _misResenas.length == 1
                    ? 'Tu reseña'
                    : 'Tus reseñas (${_misResenas.length})',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.principalMarca,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._misResenas.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(ColoresApp.fondoSuperficie,
                          ColoresApp.principalMarca, 0.15)!,
                      ColoresApp.fondoSuperficie,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: ColoresApp.principalMarca.withOpacity(0.5),
                    width: 1.2,
                  ),
                ),
                child: _CardResenaInner(resena: r, sinBorde: true),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderListado() {
    final total = _resenasDeOtros.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Text(
            'Lo que dicen otros',
            style: GoogleFonts.baloo2(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(width: 6),
          if (total > 0)
            Text(
              '($total)',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.textoSecundario,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyOtros() {
    final soloMias =
        _resenas.isNotEmpty && _resenasDeOtros.isEmpty && _misResenas.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        children: [
          Icon(CupertinoIcons.bubble_left,
              size: 48, color: ColoresApp.textoSecundario.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            soloMias
                ? 'Todavía no hay reseñas de otros'
                : 'Todavía no hay reseñas',
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            soloMias
                ? 'Cuando otros visitantes opinen, las vas a ver acá.'
                : 'Sé el primero en compartir tu experiencia.',
            style: GoogleFonts.baloo2(
              fontSize: 13,
              color: ColoresApp.textoSecundario,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _labelEstrellas(int e) {
    switch (e) {
      case 1:
        return 'Pésimo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Muy bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }
}

// ============================================================================
// Sub-widgets
// ============================================================================

class _AppBarLocal extends StatelessWidget {
  final String nombre;
  const _AppBarLocal({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(36, 36),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Icon(CupertinoIcons.chevron_back,
                size: 22, color: ColoresApp.textoPrincipal),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reseñas',
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoSecundario,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _SelectorEstrellas extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;
  const _SelectorEstrellas({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final pos = i + 1;
        final llena = valor >= pos;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(pos),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              scale: llena ? 1.0 : 0.92,
              child: Icon(
                llena
                    ? CupertinoIcons.star_fill
                    : CupertinoIcons.star,
                size: 36,
                color: llena
                    ? const Color(0xFFFFC107)
                    : ColoresApp.textoSecundario.withOpacity(0.45),
                shadows: llena
                    ? [
                        Shadow(
                          color: const Color(0xFFFFC107).withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CardResena extends StatelessWidget {
  final Map<String, dynamic> resena;
  const _CardResena({required this.resena});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withOpacity(0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: _CardResenaInner(resena: resena),
    );
  }
}

class _CardResenaInner extends StatelessWidget {
  final Map<String, dynamic> resena;
  final bool sinBorde;
  const _CardResenaInner({required this.resena, this.sinBorde = false});

  @override
  Widget build(BuildContext context) {
    final perfil = resena['perfiles_usuarios'];
    final perfilMap = perfil is Map ? Map<String, dynamic>.from(perfil) : null;
    final username = perfilMap?['username']?.toString() ?? 'usuario';
    final fotoPath = perfilMap?['foto_perfil_url']?.toString();
    // El bucket de avatars de usuarios es público; resolvemos URL pública.
    final fotoUrl = (fotoPath == null || fotoPath.isEmpty)
        ? ''
        : (fotoPath.startsWith('http')
            ? fotoPath
            : ServicioSupabase()
                .cliente
                .storage
                .from('avatars')
                .getPublicUrl(fotoPath));
    final estrellas =
        (resena['estrellas'] as int?) ?? int.tryParse(resena['estrellas']?.toString() ?? '') ?? 0;
    final comentario = resena['comentario']?.toString() ?? '';
    final fecha = _formatearFecha(resena['fecha_creacion']?.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AvatarUsuario(
              size: 38,
              avatar: fotoUrl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  if (fecha.isNotEmpty)
                    Text(
                      fecha,
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                ],
              ),
            ),
            // estrellas pequeñas a la derecha
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.only(left: 1.5),
                  child: Icon(
                    i < estrellas
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    size: 12,
                    color: i < estrellas
                        ? const Color(0xFFFFC107)
                        : ColoresApp.textoSecundario.withOpacity(0.4),
                  ),
                );
              }),
            ),
          ],
        ),
        if (comentario.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            comentario,
            style: GoogleFonts.baloo2(
              fontSize: 13.5,
              color: ColoresApp.textoPrincipal.withOpacity(0.92),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  String _formatearFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final ahora = DateTime.now();
      final diff = ahora.difference(dt);
      if (diff.inDays >= 30) {
        const meses = [
          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
          'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
        ];
        return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
      }
      if (diff.inDays >= 1) return 'hace ${diff.inDays}d';
      if (diff.inHours >= 1) return 'hace ${diff.inHours}h';
      if (diff.inMinutes >= 1) return 'hace ${diff.inMinutes}m';
      return 'recién';
    } catch (_) {
      return '';
    }
  }
}
