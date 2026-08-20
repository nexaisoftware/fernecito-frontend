library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/chat_paginacion.dart';
import '../core/constants.dart';
import '../core/servicio_conversaciones.dart';
import '../core/supabase_client.dart';
import '../widgets/boton_cargar_mas_mensajes.dart';
import '../widgets/encabezado_chat.dart';
import '../widgets/dialogo_fernecito.dart';
import 'pantalla_perfil_usuarios.dart';

class PantallaChatConversacion extends StatefulWidget {
  const PantallaChatConversacion({
    super.key,
    required this.idConversacion,
    required this.otroId,
    this.nombreOtro,
    this.fotoOtro,
  });

  final String idConversacion;
  final String otroId;
  final String? nombreOtro;
  final String? fotoOtro;

  @override
  State<PantallaChatConversacion> createState() =>
      _PantallaChatConversacionState();
}

class _PantallaChatConversacionState extends State<PantallaChatConversacion> {
  final _srv = ServicioConversaciones();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ConversacionMensaje> _mensajes = const [];
  RealtimeChannel? _canal;
  Timer? _pollNuevos;
  bool _cargando = true;
  bool _enviando = false;
  bool _sincronizandoNuevos = false;
  bool _hayMasAntiguos = false;
  bool _cargandoMas = false;
  String? _nombreOtro;
  String? _fotoOtro;

  String? get _miUid => _srv.miUid;

  @override
  void initState() {
    super.initState();
    _nombreOtro = widget.nombreOtro;
    _fotoOtro = widget.fotoOtro;
    _cargar();
    _resolverPerfil();
    _canal = _srv.suscribirMensajes(widget.idConversacion, _incorporarMensaje);
    _pollNuevos = Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(_sincronizarNuevos()),
    );
  }

  @override
  void dispose() {
    _pollNuevos?.cancel();
    final canal = _canal;
    if (canal != null) unawaited(_srv.cerrarCanal(canal));
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _resolverPerfil() async {
    if ((_nombreOtro ?? '').trim().isNotEmpty &&
        (_fotoOtro ?? '').trim().isNotEmpty) {
      return;
    }
    try {
      final row = await ServicioSupabase().cliente
          .from('perfiles_usuarios')
          .select('nombre, username, foto_perfil_url')
          .eq('id', widget.otroId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _nombreOtro ??=
            (row['nombre']?.toString().trim().isNotEmpty ?? false)
            ? row['nombre'].toString().trim()
            : (row['username']?.toString() ?? 'Alguien');
        _fotoOtro ??= ServicioSupabase().urlAvatar(
          row['foto_perfil_url']?.toString(),
        );
      });
    } catch (_) {}
  }

  Future<void> _cargar() async {
    unawaited(_srv.marcarLeido(widget.idConversacion));
    try {
      final pag = await _srv.historial(widget.idConversacion);
      if (!mounted) return;
      setState(() {
        final porId = <int, ConversacionMensaje>{
          for (final m in pag.items) m.id: m,
          for (final m in _mensajes.where((m) => m.id > 0)) m.id: m,
        };
        _mensajes = porId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
        _hayMasAntiguos = pag.hayMas;
        _cargando = false;
      });
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
      final pag = await _srv.historialAntesDe(widget.idConversacion, minId);
      if (!mounted) return;
      final ids = _mensajes.map((m) => m.id).toSet();
      final nuevos = pag.items.where((m) => !ids.contains(m.id)).toList();
      setState(() {
        _cargandoMas = false;
        _hayMasAntiguos = pag.hayMas;
        _mensajes = [...nuevos, ..._mensajes]
          ..sort((a, b) => a.id.compareTo(b.id));
      });
      scrollTrasPrepend(_scroll, prevMax, prevOffset);
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _incorporarMensaje(ConversacionMensaje msj) {
    if (!mounted) return;
    if (_mensajes.any((m) => m.id == msj.id)) return;
    setState(() {
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
    unawaited(_srv.marcarLeido(widget.idConversacion));
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
        widget.idConversacion,
        ultimoId,
      );
      if (!mounted || nuevos.isEmpty) return;
      for (final m in nuevos) {
        _incorporarMensaje(m);
      }
    } catch (e) {
      debugPrint('⚠️ conversacion sync nuevos: $e');
    } finally {
      _sincronizandoNuevos = false;
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
    final idTemp = -(DateTime.now().microsecondsSinceEpoch);
    setState(() {
      _enviando = true;
      _mensajes = [
        ..._mensajes,
        ConversacionMensaje(
          id: idTemp,
          idAutor: _miUid ?? '',
          cuerpo: texto,
          creadoEn: DateTime.now(),
        ),
      ];
    });
    _bajar();
    try {
      final idReal = await _srv.enviarMensaje(widget.idConversacion, texto);
      if (!mounted) return;
      setState(() {
        final copia = [..._mensajes];
        final i = copia.indexWhere((m) => m.id == idTemp);
        if (i < 0) return;
        if (idReal == null) {
          copia.removeAt(i);
        } else if (copia.any((m) => m.id == idReal)) {
          copia.removeAt(i);
        } else {
          copia[i] = ConversacionMensaje(
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
          content: Text(
            _srv.mensajeError('error', accion: 'enviar el mensaje'),
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

  Future<void> _verPerfil() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': widget.otroId,
            if ((_nombreOtro ?? '').trim().isNotEmpty)
              'username': _nombreOtro!.trim(),
            if ((_fotoOtro ?? '').trim().isNotEmpty) 'avatar': _fotoOtro,
          },
          estadoRelacion: EstadoRelacionUsuario.ninguno,
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
    final nombre = (_nombreOtro ?? '').trim().isEmpty
        ? 'Chat'
        : _nombreOtro!.trim();
    final foto = (_fotoOtro ?? '').trim();
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EncabezadoChat(
              nombre: nombre,
              subtitulo: 'Chat privado',
              fotoUrl: foto.isNotEmpty ? foto : null,
              onBack: () => Navigator.of(context).pop(),
              onTapPerfil: _verPerfil,
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Asegurate de que la persona sea real. Cuidado con enviar datos sensibles, número de teléfono o dirección.',
                style: GoogleFonts.baloo2(
                  color: const Color(0xFF9A9A9A),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.28,
                ),
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CupertinoActivityIndicator(radius: 13))
                  : _mensajes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'Ya pueden chatear. Coordinen la previa, el after o lo que se les ocurra.',
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
                        return _burbuja(_mensajes[idx]);
                      },
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
                      placeholder: 'Escribí un mensaje...',
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

  Widget _burbuja(ConversacionMensaje m) {
    final esMio = m.idAutor == _miUid;
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: esMio ? const Color(0xFF3A3A40) : ColoresApp.principalMarca,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(esMio ? 17 : 5),
            bottomRight: Radius.circular(esMio ? 5 : 17),
          ),
        ),
        child: Text(
          m.cuerpo,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.22,
          ),
        ),
      ),
    );
  }
}
