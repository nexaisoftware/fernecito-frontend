/// Fernecito Match — chat realtime de un match.
///
/// Header: avatar + "Nombre · Plan en Lugar" (el plan del match). Mensajes por
/// Supabase Realtime (RLS de participantes); envío por RPC con rate limit.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/servicio_match.dart';
import '../core/supabase_client.dart';
import '../widgets/stack_avatares_squad.dart';
import '../widgets/dialogo_fernecito.dart';

class PantallaMatchChat extends StatefulWidget {
  const PantallaMatchChat({super.key, required this.match});

  final MatchItem match;

  @override
  State<PantallaMatchChat> createState() => _PantallaMatchChatState();
}

class _PantallaMatchChatState extends State<PantallaMatchChat> {
  final _srv = ServicioMatch();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<MatchMensaje> _mensajes = const [];
  RealtimeChannel? _canal;
  Timer? _pollNuevos;
  bool _cargando = true;
  bool _enviando = false;
  bool _sincronizandoNuevos = false;
  final Map<String, String> _nombresAutores = {};

  String? get _miUid => _srv.miUid;

  @override
  void initState() {
    super.initState();
    _cargar();
    _canal = _srv.suscribirMensajes(widget.match.idMatch, (msj) {
      _incorporarMensaje(msj);
    });
    _pollNuevos = Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(_sincronizarNuevos()),
    );
  }

  @override
  void dispose() {
    _pollNuevos?.cancel();
    final canal = _canal;
    if (canal != null) _srv.cerrarCanal(canal);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    // Abrir el chat = leerlo (apaga el indicador de no leídos en la bandeja).
    unawaited(_srv.marcarLeido(widget.match.idMatch));
    try {
      final mensajes = await _srv.historial(widget.match.idMatch);
      if (!mounted) return;
      setState(() {
        // Si llegó realtime mientras cargaba el historial, no lo pises.
        final porId = <int, MatchMensaje>{
          for (final m in mensajes) m.id: m,
          for (final m in _mensajes.where((m) => m.id > 0)) m.id: m,
        };
        _mensajes = porId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
        _cargando = false;
      });
      _bajar();
      for (final m in mensajes) {
        _resolverNombre(m.idAutor);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _incorporarMensaje(MatchMensaje msj) {
    if (!mounted) return;
    if (_mensajes.any((m) => m.id == msj.id)) return;
    setState(() {
      // Mensaje propio: si la burbuja optimista sigue en pantalla (el
      // realtime ganó la carrera al RPC), la REEMPLAZA en vez de sumarse.
      if (msj.idAutor == _miUid) {
        final i = _mensajes.indexWhere(
          (m) => m.id < 0 && m.cuerpo == msj.cuerpo,
        );
        if (i >= 0) {
          final copia = [..._mensajes];
          copia[i] = msj;
          _mensajes = copia;
          return;
        }
      }
      _mensajes = [..._mensajes, msj]..sort((a, b) => a.id.compareTo(b.id));
    });
    _bajar();
    _resolverNombre(msj.idAutor);
    unawaited(_srv.marcarLeido(widget.match.idMatch));
  }

  Future<void> _sincronizarNuevos() async {
    if (_sincronizandoNuevos || !mounted) return;
    final positivos = _mensajes.where((m) => m.id > 0);
    if (positivos.isEmpty && _cargando) return;
    final ultimoId = positivos.fold<int>(
      0,
      (max, m) => m.id > max ? m.id : max,
    );
    _sincronizandoNuevos = true;
    try {
      final nuevos = await _srv.mensajesDespuesDe(
        widget.match.idMatch,
        ultimoId,
      );
      if (!mounted || nuevos.isEmpty) return;
      for (final m in nuevos) {
        _incorporarMensaje(m);
      }
    } catch (e) {
      debugPrint('⚠️ match sync nuevos: $e');
    } finally {
      _sincronizandoNuevos = false;
    }
  }

  /// En chats de squads hay varios autores: resolvemos nombres una sola vez.
  Future<void> _resolverNombre(String idAutor) async {
    if (idAutor == _miUid || _nombresAutores.containsKey(idAutor)) return;
    _nombresAutores[idAutor] = '...';
    try {
      final row = await ServicioSupabase().cliente
          .from('perfiles_usuarios')
          .select('nombre, username')
          .eq('id', idAutor)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _nombresAutores[idAutor] =
            (row?['nombre']?.toString().trim().isNotEmpty ?? false)
            ? row!['nombre'].toString().trim()
            : (row?['username']?.toString() ?? 'Alguien');
      });
    } catch (_) {
      _nombresAutores.remove(idAutor);
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
    final texto = _input.text.trim();
    if (texto.isEmpty || _enviando) return;
    _input.clear();
    // Id temporal negativo y único: identifica ESTA burbuja optimista aunque
    // se manden dos mensajes idénticos seguidos.
    final idTemp = -(DateTime.now().microsecondsSinceEpoch);
    setState(() {
      _enviando = true;
      _mensajes = [
        ..._mensajes,
        MatchMensaje(
          id: idTemp,
          idAutor: _miUid ?? '',
          cuerpo: texto,
          creadoEn: DateTime.now(),
        ),
      ];
    });
    _bajar();
    try {
      final idReal = await _srv.enviarMensaje(widget.match.idMatch, texto);
      if (!mounted) return;
      setState(() {
        final copia = [..._mensajes];
        final i = copia.indexWhere((m) => m.id == idTemp);
        if (i < 0) return; // ya lo reconcilió el realtime
        if (idReal == null) {
          copia.removeAt(i);
        } else if (copia.any((m) => m.id == idReal)) {
          // El realtime ya lo insertó con el id real → saco la optimista.
          copia.removeAt(i);
        } else {
          copia[i] = MatchMensaje(
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
      final bloqueado = e.toString().contains('bloqueado');
      setState(
        () => _mensajes = _mensajes.where((m) => m.id != idTemp).toList(),
      );
      await showFernecitoDialog<void>(
        context: context,
        builder: (ctx) => DialogoFernecito(
          title: Text(bloqueado ? 'Chat cerrado' : 'No se envió'),
          content: Text(
            bloqueado
                ? 'Este chat ya no está disponible.'
                : 'No pude enviar el mensaje. Probá de nuevo.',
          ),
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

  Future<void> _cancelarDesdeChat() async {
    final nombre = widget.match.otro.nombre;
    final confirmar = await showFernecitoDialog<bool>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: Text('¿Cancelar el match con $nombre?'),
        content: const Text(
          'Se borra este chat y el match. Igual pueden volver a cruzarse en las cards.',
        ),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          AccionDialogoFernecito(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar match'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ok = await _srv.cancelarMatch(widget.match.idMatch);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      await showFernecitoDialog<void>(
        context: context,
        builder: (ctx) => DialogoFernecito(
          title: const Text('No se pudo cancelar'),
          content: const Text('Probá de nuevo en un momento.'),
          actions: [
            AccionDialogoFernecito(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _menuChat() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          widget.match.otro.nombre,
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _cancelarDesdeChat();
            },
            child: const Text('✋ Cancelar match'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Volver'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Web/PWA: el viewport ya se achica con el teclado. Si además sumamos
    // viewInsets, queda un hueco enorme entre input y teclado.
    // Nativo: CupertinoPageScaffold no se reacomoda solo → sí usamos viewInsets.
    final bottomGap = kIsWeb
        ? (keyboard > 0 ? 8.0 : safeBottom)
        : (keyboard > 0 ? keyboard : safeBottom);
    final otro = widget.match.otro;
    final foto = otro.fotoUrl;
    final urlsSquad = otro.avataresMiembrosUrls;
    final esSquadStack = otro.esSquad && urlsSquad.isNotEmpty;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: ColoresApp.principalMarca,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
          onPressed: _menuChat,
          child: const Icon(
            CupertinoIcons.ellipsis_circle,
            color: Colors.white54,
            size: 24,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esSquadStack)
                    StackAvataresSquad(
                      avatares: urlsSquad,
                      totalExtra: otro.miembrosParaStack,
                      size: 36,
                      paddingExterno: 0,
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A2A2A),
                        image: foto != null
                            ? DecorationImage(
                                image: NetworkImage(foto),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: foto == null
                          ? Text(
                              otro.esSquad ? '👥' : '🙋',
                              style: const TextStyle(fontSize: 16),
                            )
                          : null,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.match.tituloParticipantes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.baloo2(
                                  fontWeight: FontWeight.w900,
                                  color: ColoresApp.textoPrincipal,
                                  fontSize: 15,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            if (widget.match.esMatchSquad) ...[
                              const SizedBox(width: 6),
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: BadgeMatchSquads(),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          widget.match.planResumen,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB79CF0),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AvisoSeguridadMatch(esSquad: widget.match.esMatchSquad),
            Expanded(
              child: _cargando
                  ? const Center(child: CupertinoActivityIndicator(radius: 13))
                  : _mensajes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          '¡Hicieron match para "${widget.match.planResumen}"! 💜\nRompé el hielo y coordinen la salida.${widget.match.esMatchSquad ? '\nEn el chat grupal, @username avisa a esa persona.' : ''}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            color: ColoresApp.textoSecundario,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) => _burbuja(_mensajes[i]),
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + bottomGap),
              color: ColoresApp.fondoSuperficie,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      placeholder: widget.match.otro.esSquad
                          ? 'Mensaje... @username avisa'
                          : 'Escribí un mensaje...',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.textoPrincipal,
                        fontWeight: FontWeight.w700,
                      ),
                      placeholderStyle: GoogleFonts.baloo2(
                        color: ColoresApp.textoSecundario,
                      ),
                      decoration: BoxDecoration(
                        color: ColoresApp.fondoPrincipal,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onSubmitted: (_) => _enviar(),
                      onTap: _bajar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _enviar,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF7C3AED),
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_up,
                        color: Colors.white,
                        size: 21,
                      ),
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

  Widget _burbuja(MatchMensaje m) {
    final esMio = m.idAutor == _miUid;
    final nombre = _nombresAutores[m.idAutor];
    final mostrarAutor =
        !esMio &&
        widget.match.otro.esSquad &&
        nombre != null &&
        nombre != '...';
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          // Contraparte = color del theme; el mío = gris más claro.
          color: esMio ? const Color(0xFF3A3A40) : ColoresApp.principalMarca,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(esMio ? 17 : 5),
            bottomRight: Radius.circular(esMio ? 5 : 17),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mostrarAutor)
              Text(
                nombre,
                style: GoogleFonts.baloo2(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            Text(
              m.cuerpo,
              style: GoogleFonts.baloo2(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge compacto para diferenciar un match de squads de uno 1:1.
class BadgeMatchSquads extends StatelessWidget {
  const BadgeMatchSquads({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Squads',
        style: GoogleFonts.baloo2(
          color: const Color(0xFFD4C4F7),
          fontWeight: FontWeight.w800,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Aviso de seguridad al tope del chat. Copy distinto si es 1:1 o grupal.
class AvisoSeguridadMatch extends StatelessWidget {
  const AvisoSeguridadMatch({super.key, required this.esSquad});

  final bool esSquad;

  static const _copyUnoAUno =
      'Asegurate de que la persona sea real. Cuidado con enviar datos sensibles, número de teléfono o dirección. Siempre podés bloquear y reportar desde su perfil.';

  static const _copySquads =
      'Este chat es grupal: hay gente de los dos squads. Asegurate de que sean reales. No compartas teléfono, dirección ni datos sensibles. Podés bloquear y reportar desde el perfil del squad.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        esSquad ? _copySquads : _copyUnoAUno,
        style: GoogleFonts.baloo2(
          color: const Color(0xFF9A9A9A),
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1.28,
        ),
      ),
    );
  }
}
