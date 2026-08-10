library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/servicio_planes.dart';
import '../core/supabase_client.dart';
import '../widgets/fernecito_loader.dart';

class PantallaChatPlan extends StatefulWidget {
  const PantallaChatPlan({super.key, required this.plan});
  final PlanComunidad plan;

  @override
  State<PantallaChatPlan> createState() => _PantallaChatPlanState();
}

class _PantallaChatPlanState extends State<PantallaChatPlan> {
  final _srv = ServicioPlanes();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<PlanMensaje> _mensajes = const [];
  bool _cargando = true;
  bool _enviando = false;
  RealtimeChannel? _canal;
  final Map<String, String> _nombresAutores = {};

  String? get _miUid => _srv.miUid;

  @override
  void initState() {
    super.initState();
    _cargar();
    _canal = _srv.suscribirMensajes(widget.plan.id, (m) {
      if (!mounted) return;
      if (_mensajes.any((x) => x.id == m.id)) return;
      setState(() {
        if (m.idAutor == _miUid) {
          final i = _mensajes.indexWhere(
            (x) => x.id < 0 && x.cuerpo == m.cuerpo,
          );
          if (i >= 0) {
            final copia = [..._mensajes];
            copia[i] = m;
            _mensajes = copia;
            return;
          }
        }
        _mensajes = [..._mensajes, m];
      });
      _resolverNombre(m);
      _bajar();
    });
  }

  @override
  void dispose() {
    final canal = _canal;
    if (canal != null) unawaited(_srv.cerrarCanal(canal));
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final mensajes = await _srv.historial(widget.plan.id);
      await _srv.marcarLeido(widget.plan.id);
      if (!mounted) return;
      setState(() {
        _mensajes = mensajes;
        _cargando = false;
      });
      for (final m in mensajes) {
        _resolverNombre(m);
      }
      _bajar();
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _resolverNombre(PlanMensaje m) async {
    final id = m.idAutor;
    if (id == null || id == _miUid || _nombresAutores.containsKey(id)) return;
    _nombresAutores[id] = '...';
    try {
      final row = await ServicioSupabase().cliente
          .from('perfiles_usuarios')
          .select('nombre, username')
          .eq('id', id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _nombresAutores[id] =
            (row?['nombre']?.toString().trim().isNotEmpty ?? false)
            ? row!['nombre'].toString().trim()
            : (row?['username']?.toString() ?? 'Alguien');
      });
    } catch (_) {
      _nombresAutores.remove(id);
    }
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    _ctrl.clear();
    final idTemp = -(DateTime.now().microsecondsSinceEpoch);
    setState(() {
      _enviando = true;
      _mensajes = [
        ..._mensajes,
        PlanMensaje(
          id: idTemp,
          idAutor: _miUid,
          cuerpo: texto,
          creadoEn: DateTime.now(),
        ),
      ];
    });
    _bajar();
    try {
      final idReal = await _srv.enviarMensaje(widget.plan.id, texto);
      if (!mounted) return;
      setState(() {
        final copia = [..._mensajes];
        final i = copia.indexWhere((m) => m.id == idTemp);
        if (i < 0) return;
        if (idReal == null || copia.any((m) => m.id == idReal)) {
          copia.removeAt(i);
        } else {
          copia[i] = PlanMensaje(
            id: idReal,
            idAutor: copia[i].idAutor,
            cuerpo: copia[i].cuerpo,
            creadoEn: copia[i].creadoEn,
          );
        }
        _mensajes = copia;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _mensajes = _mensajes.where((m) => m.id != idTemp).toList(),
      );
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No se envió'),
          content: Text(_srv.mensajeError(e, accion: 'enviar el mensaje')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomGap = kIsWeb
        ? (keyboard > 0 ? 8.0 : safeBottom)
        : (keyboard > 0 ? keyboard : safeBottom);
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      color: ColoresApp.principalMarca,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.plan.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.info_circle,
                    size: 14,
                    color: ColoresApp.principalMarca.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Chat del plan · ${widget.plan.nombreLocal} aparece destacado cuando participa.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: FernecitoLoader.inline(size: 26))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) => _BurbujaMensaje(
                        m: _mensajes[i],
                        esMio: _mensajes[i].idAutor == _miUid,
                        esAdmin:
                            _mensajes[i].idAutor == widget.plan.idOrganizador,
                        nombreAutor: _nombreAutor(_mensajes[i]),
                      ),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, bottomGap + 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _ctrl,
                      placeholder: 'Escribí en el plan...',
                      placeholderStyle: TextStyle(
                        color: ColoresApp.textoSecundario.withValues(
                          alpha: 0.75,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 4,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: _enviando ? null : _enviar,
                    child: _enviando
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Icon(
                            CupertinoIcons.paperplane_fill,
                            color: Colors.white,
                            size: 19,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _nombreAutor(PlanMensaje m) {
    if (m.esSistema) return null;
    if (m.esLocal) return widget.plan.nombreLocal;
    if (m.idAutor == _miUid) return 'Vos';
    if (m.idAutor == widget.plan.idOrganizador) {
      return widget.plan.nombreOrganizador;
    }
    return m.idAutor == null ? 'Alguien' : _nombresAutores[m.idAutor!] ?? '...';
  }
}

/// Paleta estilo WhatsApp: colores fuertes y de buen contraste sobre fondo
/// oscuro, para diferenciar autores del chat de forma estable (client-only).
const List<Color> _paletteAutores = [
  Color(0xFFEF6C6C),
  Color(0xFF4FC3F7),
  Color(0xFFFFB86B),
  Color(0xFF7ED9A8),
  Color(0xFFC792EA),
  Color(0xFFF2A65A),
  Color(0xFF64D8CB),
  Color(0xFFFF8FB1),
];

int _hashUid(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

Color _colorAutor(String uid) =>
    _paletteAutores[_hashUid(uid) % _paletteAutores.length];

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({
    required this.m,
    required this.esMio,
    required this.esAdmin,
    required this.nombreAutor,
  });
  final PlanMensaje m;
  final bool esMio;
  final bool esAdmin;
  final String? nombreAutor;

  @override
  Widget build(BuildContext context) {
    if (m.esSistema) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              m.cuerpo,
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ),
        ),
      );
    }

    final local = m.esLocal;
    final admin = esAdmin && !local;
    final colorAutor = (!esMio && !local && m.idAutor != null)
        ? _colorAutor(m.idAutor!)
        : null;

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
        decoration: BoxDecoration(
          color: local
              ? const Color(0xFF14B8A6).withValues(alpha: 0.18)
              : esMio
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.065),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(esMio ? 22 : 8),
            bottomRight: Radius.circular(esMio ? 8 : 22),
          ),
          border: local
              ? Border.all(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                )
              : (colorAutor != null
                    ? Border.all(color: colorAutor.withValues(alpha: 0.38))
                    : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nombreAutor != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      nombreAutor!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: local
                            ? const Color(0xFF5EEAD4)
                            : (colorAutor ??
                                  Colors.white.withValues(alpha: 0.62)),
                      ),
                    ),
                  ),
                  if (local || admin) ...[
                    const SizedBox(width: 6),
                    _BadgeChat(
                      texto: local ? 'LOCAL' : 'ADMIN',
                      color: local
                          ? const Color(0xFF14B8A6)
                          : (colorAutor ?? ColoresApp.principalMarca),
                    ),
                  ],
                ],
              ),
            if (nombreAutor != null) const SizedBox(height: 3),
            Text(
              m.cuerpo,
              style: GoogleFonts.baloo2(
                fontSize: 15,
                height: 1.18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeChat extends StatelessWidget {
  const _BadgeChat({required this.texto, required this.color});
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: GoogleFonts.baloo2(
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}
