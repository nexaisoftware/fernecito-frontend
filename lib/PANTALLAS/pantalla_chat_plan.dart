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

/// Handle @ para etiquetar al local del plan.
String handleMencionLocal(String? nombreLocal) {
  final cleaned = (nombreLocal ?? '').toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9._]+'),
    '',
  );
  if (cleaned.length >= 2) {
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }
  return 'local';
}

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
  final _focus = FocusNode();

  List<PlanMensaje> _mensajes = const [];
  List<PlanMiembro> _miembros = const [];
  PlanComunidad? _planActual;
  bool _cargando = true;
  bool _enviando = false;
  bool _bannerCerrado = false;
  RealtimeChannel? _canal;
  RealtimeChannel? _canalEstado;
  final Map<String, String> _nombresAutores = {};

  String? _queryMencion;
  int? _inicioMencion;

  String? get _miUid => _srv.miUid;

  PlanComunidad get _plan => _planActual ?? widget.plan;

  String get _handleLocal => handleMencionLocal(_plan.nombreLocal);

  String? get _textoBannerBeneficio {
    final estado = _plan.beneficioEstado;
    final oferta = (_plan.beneficioLocal ?? _plan.beneficioContraoferta)?.trim();
    if (estado == 'aceptado') {
      if (oferta == null || oferta.isEmpty) return null;
      // Hubo pedido del grupo → “se puso la 10”; si no, promo del local.
      if ((_plan.pedidoBeneficio ?? '').trim().isNotEmpty) {
        return 'El local se puso la 10 con: $oferta';
      }
      return 'Promo del local: $oferta';
    }
    // Legacy: contraoferta pendiente (ya no debería ocurrir con flujo one-shot).
    if (estado == 'contraoferta') {
      final c = (_plan.beneficioContraoferta ?? '').trim();
      if (c.isEmpty) return null;
      return 'Oferta del local (pendiente): $c';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextoCambio);
    _cargar();
  }

  void _suscribirRealtime() {
    if (!_plan.chatDisponible || _canal != null) return;
    _canal = _srv.suscribirMensajes(_plan.id, (m) {
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
      unawaited(_resolverNombre(m));
      _bajar();
    });
    _canalEstado ??= _srv.suscribirCambiosPlan(_plan.id, () {
      unawaited(_refrescarPlan());
    });
  }

  Future<void> _cerrarRealtime() async {
    final canal = _canal;
    final canalEstado = _canalEstado;
    _canal = null;
    _canalEstado = null;
    if (canal != null) await _srv.cerrarCanal(canal);
    if (canalEstado != null) await _srv.cerrarCanal(canalEstado);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextoCambio);
    final canal = _canal;
    if (canal != null) unawaited(_srv.cerrarCanal(canal));
    final canalEstado = _canalEstado;
    if (canalEstado != null) unawaited(_srv.cerrarCanal(canalEstado));
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final mensajesF = _srv.historial(_plan.id);
      final detalleF = _srv.detalle(_plan.id);
      final mensajes = await mensajesF;
      final det = await detalleF;
      await _srv.marcarLeido(_plan.id);
      if (!mounted) return;
      setState(() {
        _planActual = det.detalle?.plan ?? _plan;
        _mensajes = mensajes;
        _miembros = (det.detalle?.miembros ?? const [])
            .where((m) => m.estado == 'aceptado')
            .toList(growable: false);
        for (final m in _miembros) {
          if (m.idUsuario.isNotEmpty) {
            _nombresAutores[m.idUsuario] = m.nombre;
          }
        }
        _cargando = false;
      });
      if (_plan.chatDisponible) {
        _suscribirRealtime();
      } else {
        await _cerrarRealtime();
      }
      for (final m in mensajes) {
        unawaited(_resolverNombre(m));
      }
      _bajar();
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _refrescarPlan() async {
    final res = await _srv.detalle(_plan.id);
    if (!mounted || res.detalle == null) return;
    setState(() {
      _planActual = res.detalle!.plan;
      _miembros = res.detalle!.miembros
          .where((m) => m.estado == 'aceptado')
          .toList(growable: false);
    });
    if (_plan.chatDisponible) {
      _suscribirRealtime();
    } else {
      await _cerrarRealtime();
    }
  }

  Future<void> _resolverNombre(PlanMensaje m) async {
    final id = m.idAutor;
    if (id == null || id == _miUid) return;
    if (_nombresAutores.containsKey(id) && _nombresAutores[id] != '...') {
      return;
    }
    final fromLista = _miembros.where((x) => x.idUsuario == id);
    if (fromLista.isNotEmpty) {
      _nombresAutores[id] = fromLista.first.nombre;
      if (mounted) setState(() {});
      return;
    }
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

  void _onTextoCambio() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      if (_queryMencion != null) {
        setState(() {
          _queryMencion = null;
          _inicioMencion = null;
        });
      }
      return;
    }
    final before = text.substring(0, cursor);
    final match = RegExp(r'(^|[\s])@([A-Za-z0-9._]{0,32})$').firstMatch(before);
    if (match == null) {
      if (_queryMencion != null) {
        setState(() {
          _queryMencion = null;
          _inicioMencion = null;
        });
      }
      return;
    }
    setState(() {
      _inicioMencion = before.lastIndexOf('@');
      _queryMencion = match.group(2) ?? '';
    });
  }

  List<_CandidatoMencion> get _candidatos {
    final q = (_queryMencion ?? '').toLowerCase();
    final out = <_CandidatoMencion>[];
    final handleLocal = _handleLocal;
    final nombreLocal = _plan.nombreLocal.trim().isNotEmpty
        ? _plan.nombreLocal.trim()
        : 'Local';

    if (_plan.idLocal != _miUid &&
        (q.isEmpty ||
            'local'.startsWith(q) ||
            handleLocal.startsWith(q) ||
            nombreLocal.toLowerCase().contains(q))) {
      out.add(
        _CandidatoMencion(
          handle: handleLocal,
          label: nombreLocal,
          subtitulo: 'LOCAL · @$handleLocal',
          esLocal: true,
        ),
      );
    }

    for (final m in _miembros) {
      final user = (m.username ?? '').trim();
      if (m.idUsuario == _miUid) continue;
      if (q.isNotEmpty &&
          (user.isEmpty || !user.toLowerCase().startsWith(q)) &&
          !m.nombre.toLowerCase().contains(q)) {
        continue;
      }
      out.add(
        _CandidatoMencion(
          handle: user,
          label: m.nombre,
          subtitulo: user.isEmpty ? 'sin @' : '@$user',
          esLocal: false,
          habilitado: user.isNotEmpty,
        ),
      );
    }
    return out.take(8).toList();
  }

  void _insertarMencion(_CandidatoMencion c) {
    final start = _inicioMencion;
    if (start == null) return;
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, start);
    final after = text.substring(cursor);
    final insertion = '@${c.handle} ';
    final nuevo = '$before$insertion$after';
    _ctrl.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(
        offset: before.length + insertion.length,
      ),
    );
    setState(() {
      _queryMencion = null;
      _inicioMencion = null;
    });
    _focus.requestFocus();
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    _ctrl.clear();
    setState(() {
      _queryMencion = null;
      _inicioMencion = null;
    });
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
      final idReal = await _srv.enviarMensaje(_plan.id, texto);
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
    final candidatos = _plan.chatDisponible && _queryMencion != null
        ? _candidatos
        : const <_CandidatoMencion>[];
    final bannerTexto = _textoBannerBeneficio;

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
                      _plan.titulo,
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
            if (!_bannerCerrado && bannerTexto != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: ColoresApp.principalMarca.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        bannerTexto,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _bannerCerrado = true),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: Colors.white70,
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
                      'Chat del plan · escribí @ para etiquetar al local o a alguien del grupo.',
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
                        esAdmin: _mensajes[i].idAutor == _plan.idOrganizador,
                        nombreAutor: _nombreAutor(_mensajes[i]),
                      ),
                    ),
            ),
            if (candidatos.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: candidatos.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (_, i) {
                    final c = candidatos[i];
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      onPressed: c.habilitado
                          ? () => _insertarMencion(c)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            c.esLocal
                                ? CupertinoIcons.building_2_fill
                                : CupertinoIcons.person_fill,
                            size: 18,
                            color: !c.habilitado
                                ? Colors.white38
                                : c.esLocal
                                ? const Color(0xFF5EEAD4)
                                : ColoresApp.principalMarca,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: c.habilitado
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                ),
                                Text(
                                  c.subtitulo,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.habilitado
                                        ? Colors.white54
                                        : Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_plan.chatDisponible)
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, bottomGap + 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        placeholder: 'Escribí… Tocá @ para mencionar',
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
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
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
    if (m.esLocal) return _plan.nombreLocal;
    if (m.idAutor == _miUid) return 'Vos';
    if (m.idAutor == _plan.idOrganizador) {
      return _plan.nombreOrganizador;
    }
    return m.idAutor == null ? 'Alguien' : _nombresAutores[m.idAutor!] ?? '...';
  }
}

class _CandidatoMencion {
  const _CandidatoMencion({
    required this.handle,
    required this.label,
    required this.subtitulo,
    required this.esLocal,
    this.habilitado = true,
  });
  final String handle;
  final String label;
  final String subtitulo;
  final bool esLocal;
  final bool habilitado;
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
            _TextoConMenciones(
              texto: m.cuerpo,
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

/// Resalta `@menciones` dentro del cuerpo del mensaje.
final RegExp _mencionRegex = RegExp(r'(@[a-zA-Z0-9_.]+)');

class _TextoConMenciones extends StatelessWidget {
  const _TextoConMenciones({required this.texto, required this.style});
  final String texto;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final partes = texto.split(_mencionRegex);
    final menciones = _mencionRegex
        .allMatches(texto)
        .map((m) => m.group(0)!)
        .toList();
    if (menciones.isEmpty) {
      return Text(texto, style: style);
    }
    final spans = <TextSpan>[];
    for (var i = 0; i < partes.length; i++) {
      if (partes[i].isNotEmpty) spans.add(TextSpan(text: partes[i]));
      if (i < menciones.length) {
        spans.add(
          TextSpan(
            text: menciones[i],
            style: TextStyle(
              color: ColoresApp.principalMarca,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      }
    }
    return Text.rich(TextSpan(style: style, children: spans));
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
