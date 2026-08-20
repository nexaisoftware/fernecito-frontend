library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/chat_paginacion.dart';
import '../core/constants.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../models/social.dart';
import '../widgets/boton_cargar_mas_mensajes.dart';
import '../widgets/encabezado_chat.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/dialogo_fernecito.dart';
import 'pantalla_perfil_squads.dart';

class PantallaChatSquad extends StatefulWidget {
  const PantallaChatSquad({
    super.key,
    required this.idGrupo,
    required this.nombre,
  });

  final String idGrupo;
  final String nombre;

  @override
  State<PantallaChatSquad> createState() => _PantallaChatSquadState();
}

class _PantallaChatSquadState extends State<PantallaChatSquad> {
  final _srv = ServicioSquads();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  List<SquadMensaje> _mensajes = const [];
  List<MiembroSquad> _miembros = const [];
  String? _idCreador;
  bool _cargando = true;
  bool _enviando = false;
  bool _hayMasAntiguos = false;
  bool _cargandoMas = false;
  RealtimeChannel? _canal;
  final Map<String, String> _nombresAutores = {};
  String? _queryMencion;
  int? _inicioMencion;

  String? get _miUid => ServicioSupabase().usuarioActual?.id;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextoMencion);
    _cargar();
    _canal = _srv.suscribirChat(widget.idGrupo, (m) {
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
    _ctrl.removeListener(_onTextoMencion);
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final resultados = await Future.wait([
        _srv.historialChat(widget.idGrupo),
        _srv.detalle(widget.idGrupo),
      ]);
      await _srv.marcarChatLeido(widget.idGrupo);
      if (!mounted) return;
      final pag = resultados[0] as PaginaChatMensajes<SquadMensaje>;
      final det = resultados[1] as SquadDetalle?;
      setState(() {
        _mensajes = pag.items;
        _hayMasAntiguos = pag.hayMas;
        _miembros = det?.miembros ?? const [];
        _idCreador = det?.idCreador;
        _cargando = false;
      });
      for (final m in pag.items) {
        _resolverNombre(m);
      }
      _bajar();
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  int? get _idMinimoPositivo {
    var min = 0;
    var hay = false;
    for (final m in _mensajes) {
      if (m.id <= 0) continue;
      if (!hay || m.id < min) {
        min = m.id;
        hay = true;
      }
    }
    return hay ? min : null;
  }

  Future<void> _cargarMasAntiguos() async {
    if (_cargandoMas || !_hayMasAntiguos) return;
    final minId = _idMinimoPositivo;
    if (minId == null) return;
    final prevMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final prevOffset = _scroll.hasClients ? _scroll.offset : 0.0;
    setState(() => _cargandoMas = true);
    try {
      final pag = await _srv.historialChatAntesDe(widget.idGrupo, minId);
      if (!mounted) return;
      final ids = _mensajes.map((m) => m.id).toSet();
      final nuevos = pag.items.where((m) => !ids.contains(m.id)).toList();
      setState(() {
        _cargandoMas = false;
        _hayMasAntiguos = pag.hayMas;
        _mensajes = [...nuevos, ..._mensajes]
          ..sort((a, b) => a.id.compareTo(b.id));
      });
      for (final m in nuevos) {
        _resolverNombre(m);
      }
      scrollTrasPrepend(_scroll, prevMax, prevOffset);
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _onTextoMencion() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;
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
    final atIndex = before.lastIndexOf('@');
    setState(() {
      _inicioMencion = atIndex;
      _queryMencion = match.group(2) ?? '';
    });
  }

  List<_CandidatoMencionSquad> get _candidatos {
    final q = (_queryMencion ?? '').toLowerCase();
    final out = <_CandidatoMencionSquad>[];
    for (final m in _miembros) {
      final user = m.username.trim();
      if (user.isEmpty || m.idUsuario == _miUid) continue;
      if (q.isNotEmpty &&
          !user.toLowerCase().startsWith(q) &&
          !m.nombre.toLowerCase().contains(q)) {
        continue;
      }
      out.add(
        _CandidatoMencionSquad(
          handle: user,
          label: m.nombre.trim().isEmpty ? user : m.nombre,
          subtitulo: '@$user',
        ),
      );
    }
    return out.take(8).toList();
  }

  void _insertarMencion(_CandidatoMencionSquad c) {
    final start = _inicioMencion;
    if (start == null) return;
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, start);
    final after = text.substring(cursor);
    final insertion = '@${c.handle} ';
    _ctrl.value = TextEditingValue(
      text: '$before$insertion$after',
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

  Future<void> _resolverNombre(SquadMensaje m) async {
    final id = m.idAutor;
    if (id == null || id == _miUid || _nombresAutores.containsKey(id)) return;
    final local = _miembros.where((x) => x.idUsuario == id).toList();
    if (local.isNotEmpty) {
      final nombre = local.first.nombre.trim();
      _nombresAutores[id] = nombre.isNotEmpty
          ? nombre
          : (local.first.username.isNotEmpty
                ? local.first.username
                : 'Alguien');
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
        SquadMensaje(
          id: idTemp,
          idAutor: _miUid,
          cuerpo: texto,
          creadoEn: DateTime.now(),
        ),
      ];
    });
    _bajar();
    try {
      final idReal = await _srv.enviarMensajeChat(widget.idGrupo, texto);
      if (!mounted) return;
      setState(() {
        final copia = [..._mensajes];
        final i = copia.indexWhere((m) => m.id == idTemp);
        if (i < 0) return;
        if (idReal == null || copia.any((m) => m.id == idReal)) {
          copia.removeAt(i);
        } else {
          copia[i] = SquadMensaje(
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
      await showFernecitoDialog<void>(
        context: context,
        builder: (ctx) => DialogoFernecito(
          title: const Text('No se envió'),
          content: Text(_srv.mensajeErrorChat(e)),
          actions: [
            AccionDialogoFernecito(
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

  bool _esAdmin(String? id) {
    if (id == null) return false;
    if (id == _idCreador) return true;
    return _miembros.any((m) => m.idUsuario == id && m.esAdmin);
  }

  Future<void> _verPerfilSquad() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilSquads(
          squad: {
            'id_grupo': widget.idGrupo,
            'nombre_grupo': widget.nombre,
          },
          estadoRelacion: EstadoRelacionSquad.ninguno,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomGap = kIsWeb
        ? (keyboard > 0 ? 8.0 : safeBottom)
        : (keyboard > 0 ? keyboard : safeBottom);
    final candidatos = _queryMencion != null
        ? _candidatos
        : const <_CandidatoMencionSquad>[];
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: Column(
          children: [
            EncabezadoChat(
              nombre: widget.nombre,
              subtitulo: 'Chat del squad',
              esSquad: true,
              onBack: () => Navigator.pop(context),
              onTapPerfil: _verPerfilSquad,
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
                      'Chat del squad · usá @ para avisar a alguien. Solo texto.',
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
                      itemCount:
                          _mensajes.length + (_hayMasAntiguos ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_hayMasAntiguos && i == 0) {
                          return BotonCargarMasMensajes(
                            cargando: _cargandoMas,
                            onTap: _cargarMasAntiguos,
                          );
                        }
                        final idx = _hayMasAntiguos ? i - 1 : i;
                        final m = _mensajes[idx];
                        return _BurbujaMensajeSquad(
                          m: m,
                          esMio: m.idAutor == _miUid,
                          esAdmin: _esAdmin(m.idAutor),
                          nombreAutor: _nombreAutor(m),
                        );
                      },
                    ),
            ),
            if (candidatos.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidatos.length,
                  itemBuilder: (_, i) {
                    final c = candidatos[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        CupertinoIcons.person_fill,
                        color: ColoresApp.principalMarca,
                        size: 20,
                      ),
                      title: Text(
                        c.label,
                        style: GoogleFonts.baloo2(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        c.subtitulo,
                        style: GoogleFonts.baloo2(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      onTap: () => _insertarMencion(c),
                    );
                  },
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, bottomGap + 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      placeholder: 'Escribí… Usá @ para mencionar',
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

  String? _nombreAutor(SquadMensaje m) {
    if (m.idAutor == _miUid) return 'Vos';
    return m.idAutor == null ? 'Alguien' : _nombresAutores[m.idAutor!] ?? '...';
  }
}

class _CandidatoMencionSquad {
  const _CandidatoMencionSquad({
    required this.handle,
    required this.label,
    required this.subtitulo,
  });
  final String handle;
  final String label;
  final String subtitulo;
}

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

class _BurbujaMensajeSquad extends StatelessWidget {
  const _BurbujaMensajeSquad({
    required this.m,
    required this.esMio,
    required this.esAdmin,
    required this.nombreAutor,
  });
  final SquadMensaje m;
  final bool esMio;
  final bool esAdmin;
  final String? nombreAutor;

  @override
  Widget build(BuildContext context) {
    final colorAutor = (!esMio && m.idAutor != null)
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
          color: esMio
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.065),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(esMio ? 22 : 8),
            bottomRight: Radius.circular(esMio ? 8 : 22),
          ),
          border: colorAutor != null
              ? Border.all(color: colorAutor.withValues(alpha: 0.38))
              : null,
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
                        color: colorAutor ?? Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                  if (esAdmin && !esMio) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (colorAutor ?? ColoresApp.principalMarca)
                            .withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ADMIN',
                        style: GoogleFonts.baloo2(
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (nombreAutor != null) const SizedBox(height: 3),
            _TextoConMencionesSquad(
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

final RegExp _mencionRegex = RegExp(r'(@[a-zA-Z0-9_.]+)');

class _TextoConMencionesSquad extends StatelessWidget {
  const _TextoConMencionesSquad({required this.texto, required this.style});
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
