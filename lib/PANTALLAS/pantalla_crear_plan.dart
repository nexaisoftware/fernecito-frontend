library;

import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/comprimir_imagen_storage.dart';
import '../core/constants.dart';
import '../core/planes_presets.dart';
import '../core/servicio_planes.dart';
import '../core/supabase_client.dart';
import '../widgets/dialogo_fernecito.dart';
import '../widgets/fernecito_loader.dart';

class PantallaCrearPlan extends StatefulWidget {
  const PantallaCrearPlan({super.key});

  @override
  State<PantallaCrearPlan> createState() => _PantallaCrearPlanState();
}

enum _PasoPlan {
  titulo,
  identidad,
  descripcion,
  descripcionPreview,
  local,
  fondo,
  fechas,
  fechasPreview,
  union,
  contacto,
  resumen,
  guardando,
  felicitacion,
}

class _PantallaCrearPlanState extends State<PantallaCrearPlan> {
  final _srv = ServicioPlanes();
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _buscarLocal = TextEditingController();
  final _focus = FocusNode();

  final List<_MensajePlan> _mensajes = <_MensajePlan>[];
  List<Map<String, dynamic>> _locales = const [];
  Map<String, dynamic>? _local;
  List<PlanSquadOpcion> _squadsOrganizar = const [];

  String _titulo = '';
  String _descripcion = '';
  DateTime _inicio = DateTime.now().add(const Duration(days: 7));
  DateTime? _fin;
  String _modo = 'auto';
  int? _cupo;
  int? _edadMinima;
  bool _permiteSquads = true;
  String? _contacto;
  String _contactoModo = 'contactar';
  String _presetAsset = fondosPlanesPreset.first.asset;
  XFile? _imagen;
  String _tipoOrganizador = 'usuario';
  String? _idSquad;
  String _nombreOrganizador = 'Vos';

  _PasoPlan _paso = _PasoPlan.titulo;
  bool _botEscribiendo = false;
  bool _procesando = false;
  bool _buscando = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_arrancar());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _buscarLocal.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _arrancar() async {
    await _bot([
      '¡Vamos a crear un super plan! 🍻',
      'Te guío paso a paso. El local define la ciudad, puede durar hasta 45 días, y la gente se suma libre o con tu aprobación.',
      '¿Cómo querés que se llame?',
    ]);
    _focus.requestFocus();
  }

  void _scrollFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _bot(List<String> textos) async {
    setState(() => _procesando = true);
    for (final t in textos) {
      if (!mounted) return;
      setState(() => _botEscribiendo = true);
      _scrollFinal();
      await Future<void>.delayed(const Duration(milliseconds: 820));
      if (!mounted) return;
      setState(() {
        _botEscribiendo = false;
        _mensajes.add(_MensajePlan.bot(_TextoBurbujaPlan(t, esBot: true)));
      });
      _scrollFinal();
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    if (mounted) setState(() => _procesando = false);
  }

  void _usuarioTexto(String texto) {
    setState(
      () => _mensajes.add(
        _MensajePlan.usuario(_TextoBurbujaPlan(texto, esBot: false)),
      ),
    );
    _scrollFinal();
  }

  void _usuarioWidget(Widget child) {
    setState(() => _mensajes.add(_MensajePlan.usuario(child)));
    _scrollFinal();
  }

  void _irA(_PasoPlan paso) {
    setState(() => _paso = paso);
    _scrollFinal();
  }

  Future<void> _cargarSquadsOrganizar() async {
    setState(() => _procesando = true);
    final todos = await _srv.misSquads();
    if (!mounted) return;
    setState(() {
      _squadsOrganizar = todos
          .where((s) => s.puedeOrganizar)
          .toList(growable: false);
      _procesando = false;
    });
  }

  Future<void> _onTexto() async {
    final v = _input.text.trim();
    if (v.isEmpty || _guardando || _procesando || _botEscribiendo) return;
    _input.clear();
    switch (_paso) {
      case _PasoPlan.titulo:
        if (v.length < 3) {
          _toast('El nombre tiene que tener al menos 3 caracteres.');
          return;
        }
        _titulo = v;
        _usuarioTexto(v);
        await _bot([
          'Buena elección 👍',
          '¿Lo publicás **vos** o como **admin de un squad**?',
        ]);
        await _cargarSquadsOrganizar();
        _irA(_PasoPlan.identidad);
        break;
      case _PasoPlan.descripcion:
        if (v.length < 8) {
          _toast('Sumale un poquito más de contexto.');
          return;
        }
        _descripcion = v;
        _usuarioTexto(v);
        await _bot([
          'Buena, ya se entiende 😊',
          'Quedó así:\n\n**$_titulo**\n$_descripcion',
          '¿Está bien o lo corregimos?',
        ]);
        _irA(_PasoPlan.descripcionPreview);
        break;
      case _PasoPlan.contacto:
        _contacto = v;
        _usuarioTexto(v);
        await _mostrarResumen();
        break;
      default:
        break;
    }
  }

  Future<void> _elegirOrganizadorUsuario() async {
    if (_procesando || _botEscribiendo) return;
    _tipoOrganizador = 'usuario';
    _idSquad = null;
    _nombreOrganizador = 'Vos';
    _usuarioWidget(
      const _ChipRespuesta(
        icono: CupertinoIcons.person_fill,
        texto: 'Lo publico yo',
      ),
    );
    await _bot([
      'Perfecto, vas como anfitrión ✨',
      'Contame en pocas líneas qué se hace y por qué alguien se sumaría.',
      'Ej: birritas tranqui, solos y solas, previa con música, merienda para charlar…',
    ]);
    _irA(_PasoPlan.descripcion);
    _focus.requestFocus();
  }

  Future<void> _elegirOrganizadorSquad(PlanSquadOpcion squad) async {
    if (_procesando || _botEscribiendo) return;
    _tipoOrganizador = 'squad';
    _idSquad = squad.idGrupo;
    _nombreOrganizador = squad.nombre;
    _usuarioWidget(
      _ChipRespuesta(
        icono: CupertinoIcons.person_3_fill,
        texto: 'Como admin de ${squad.nombre}',
      ),
    );
    await _bot([
      'Genial, el plan sale a nombre de **${squad.nombre}**',
      'Contame en pocas líneas qué se hace y por qué alguien se sumaría.',
      'Ej: birritas tranqui, solos y solas, previa con música, merienda para charlar…',
    ]);
    _irA(_PasoPlan.descripcion);
    _focus.requestFocus();
  }

  Future<void> _confirmarDescripcion() async {
    if (_procesando || _botEscribiendo) return;
    _usuarioTexto('Está bien');
    await _bot([
      'Ahora elegí el local. El plan aparece según la ciudad de ese local 📍',
      'No hace falta elegir ubicación aparte: Fernecito la toma del local.',
    ]);
    _irA(_PasoPlan.local);
  }

  Future<void> _corregirDescripcion() async {
    if (_procesando || _botEscribiendo) return;
    _usuarioTexto('Corregir');
    await _bot(['Dale, reescribí la descripción y la vemos de nuevo ✏️']);
    _irA(_PasoPlan.descripcion);
    _focus.requestFocus();
  }

  Future<void> _buscar(String q) async {
    if (q.trim().length < 2) {
      setState(() => _locales = const []);
      return;
    }
    setState(() => _buscando = true);
    final res = await _srv.buscarLocales(q);
    if (!mounted) return;
    setState(() {
      _locales = res;
      _buscando = false;
    });
  }

  Future<void> _seleccionarLocal(Map<String, dynamic> local) async {
    if (_procesando || _botEscribiendo) return;
    _local = local;
    _buscarLocal.text = local['nombre_local']?.toString() ?? '';
    _usuarioWidget(
      _ChipRespuesta(
        icono: CupertinoIcons.placemark_fill,
        texto:
            '${local['nombre_local'] ?? 'Local'} · ${local['ciudad'] ?? 'sin ciudad'}',
      ),
    );
    await _bot([
      'Perfecto: ese local define la ciudad del plan ✅',
      'Ahora elegí un fondo o subí una portada 🎨',
    ]);
    _irA(_PasoPlan.fondo);
  }

  Future<void> _seleccionarFondo(String asset) async {
    if (_procesando || _botEscribiendo) return;
    final preset = fondosPlanesPreset.firstWhere(
      (p) => p.asset == asset,
      orElse: () => fondosPlanesPreset.first,
    );
    setState(() {
      _presetAsset = asset;
      _imagen = null;
    });
    _usuarioWidget(
      _ChipRespuesta(icono: CupertinoIcons.photo, texto: preset.nombre),
    );
    await _bot([
      'Buena elección 🎨',
      'Ahora pongamos cuándo arranca y, si querés, cuándo termina 🕒',
    ]);
    _irA(_PasoPlan.fechas);
  }

  Future<void> _pickImagen() async {
    if (_procesando || _botEscribiendo) return;
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() => _imagen = img);
    _usuarioWidget(
      const _ChipRespuesta(
        icono: CupertinoIcons.photo_fill_on_rectangle_fill,
        texto: 'Portada custom seleccionada',
      ),
    );
    await _bot([
      'Portada lista ✨',
      'Ahora pongamos cuándo arranca y, si querés, cuándo termina 🕒',
    ]);
    _irA(_PasoPlan.fechas);
  }

  Future<void> _pickFecha({required bool inicio}) async {
    final ahora = DateTime.now();
    var base = inicio
        ? _inicio
        : (_fin ?? _inicio.add(const Duration(hours: 3)));
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 310,
        color: const Color(0xFF1B1B1B),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Listo'),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: base.isBefore(ahora) ? ahora : base,
                minimumDate: ahora.subtract(const Duration(minutes: 10)),
                maximumDate: ahora.add(const Duration(days: 45)),
                use24hFormat: true,
                onDateTimeChanged: (v) => base = v,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (inicio) {
        _inicio = base;
        if (_fin != null && _fin!.isBefore(_inicio)) _fin = null;
      } else {
        _fin = base;
      }
    });
  }

  Future<void> _confirmarFechas() async {
    if (_procesando || _botEscribiendo) return;
    if (_fin != null && _fin!.isBefore(_inicio)) {
      _toast('La fecha de fin no puede ser antes del inicio.');
      return;
    }
    final resumen =
        '${_fmt(_inicio)}${_fin == null ? '' : ' · fin ${_fmt(_fin!)}'}';
    _usuarioWidget(
      _ChipRespuesta(icono: CupertinoIcons.calendar, texto: resumen),
    );
    await _bot([
      'Quedó agendado así:\n\n**$resumen**',
      '¿Están bien las fechas o las corregimos?',
    ]);
    _irA(_PasoPlan.fechasPreview);
  }

  Future<void> _aceptarFechasPreview() async {
    if (_procesando || _botEscribiendo) return;
    _usuarioTexto('Están bien');
    await _bot([
      'Listo. Ahora definamos cómo se suma la gente 🚪',
      'Puede ser entrada libre o con tu aprobación, una por una.',
    ]);
    _irA(_PasoPlan.union);
  }

  Future<void> _corregirFechas() async {
    if (_procesando || _botEscribiendo) return;
    _usuarioTexto('Corregir');
    await _bot(['Dale, ajustá inicio o fin y confirmá de nuevo 🕒']);
    _irA(_PasoPlan.fechas);
  }

  Future<void> _confirmarUnion() async {
    if (_procesando || _botEscribiendo) return;
    _usuarioWidget(
      _ChipRespuesta(
        icono: CupertinoIcons.person_2_fill,
        texto:
            '${_modo == 'manual' ? 'Con aprobación' : 'Entrada libre'} · ${_cupo == null ? 'sin cupo' : '${_cupo!} cupos'} · ${_permiteSquads ? 'squads ok' : 'solo personas'}',
      ),
    );
    await _bot([
      'Último detalle opcional 📲',
      'Elegí **contactar organizador** (WhatsApp/IG) o **colaborar** (link o alias).',
      'Solo una opción. Si no hace falta, saltealo.',
    ]);
    _irA(_PasoPlan.contacto);
    _focus.requestFocus();
  }

  Future<void> _saltearContacto() async {
    if (_procesando || _botEscribiendo) return;
    _contacto = null;
    _usuarioTexto('Sin contacto opcional');
    await _mostrarResumen();
  }

  Future<void> _mostrarResumen() async {
    await _bot([
      'Listo, ya tenemos el plan armado 🥂',
      'Revisá el resumen y, si está todo bien, lo publicamos.',
    ]);
    _irA(_PasoPlan.resumen);
  }

  Future<void> _guardar() async {
    final local = _local;
    if (local == null || _titulo.length < 3 || _descripcion.length < 8) {
      _toast('Faltan datos del plan.');
      return;
    }
    if (_tipoOrganizador == 'squad' &&
        (_idSquad == null || _idSquad!.isEmpty)) {
      _toast('Elegí un squad para publicar.');
      return;
    }
    if (_inicio.isAfter(DateTime.now().add(const Duration(days: 45)))) {
      _toast('Los planes duran 45 días. Crealo más cerca de la fecha.');
      return;
    }
    setState(() {
      _guardando = true;
      _procesando = true;
      _paso = _PasoPlan.guardando;
    });
    _usuarioTexto('Publicar plan');
    await _bot([
      'Publicando tu plan…',
    ]);
    setState(() => _procesando = true);
    try {
      String? portada;
      if (_imagen != null) {
        final comprimida = await comprimirDesdeXFile(
          _imagen!,
          perfil: PerfilImagenStorage.portadaPlan,
        );
        portada = await _srv.subirPortada(
          idTemporal:
              '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
          bytes: comprimida.bytes,
          ext: comprimida.extension,
        );
      }
      portada ??= _presetAsset;
      final id = await _srv.crear(
        titulo: _titulo,
        descripcion: _descripcion,
        idLocal: local['id']?.toString() ?? '',
        fechaInicio: _inicio,
        fechaFin: _fin,
        modoLista: _modo,
        cupoMax: _cupo,
        tipoOrganizador: _tipoOrganizador,
        idSquad: _tipoOrganizador == 'squad' ? _idSquad : null,
        contactoAnfitrion: _contacto,
        contactoModo: _contactoModo,
        portadaPath: portada,
        colorHex: '#111111',
        permiteSquads: _permiteSquads,
        edadMinima: _edadMinima,
      );
      if (!mounted) return;
      if (id == null) {
        setState(() {
          _guardando = false;
          _procesando = false;
        });
        _toast('No se pudo crear el plan.');
        _irA(_PasoPlan.resumen);
        return;
      }
      await _bot([
        '¡Listo! Plan publicado 🍻',
        'Ya está en la cartelera para que la comunidad se sume.',
      ]);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _procesando = false;
      });
      _irA(_PasoPlan.felicitacion);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _procesando = false;
      });
      _toast(_srv.mensajeError(e, accion: 'crear el plan'));
      _irA(_PasoPlan.resumen);
    }
  }

  void _toast(String msg) {
    showFernecitoDialog<void>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        content: Text(msg),
        actions: [
          AccionDialogoFernecito(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarSalir() async {
    if (_paso == _PasoPlan.felicitacion) return true;
    final r = await showFernecitoDialog<bool>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('¿Salir del asistente?'),
        content: const Text(
          'Vas a perder lo que cargaste acá. ¿Seguro querés salir?',
        ),
        actions: [
          AccionDialogoFernecito(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir acá'),
          ),
          AccionDialogoFernecito(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _intentarSalir() async {
    if (await _confirmarSalir() && mounted) {
      Navigator.of(context).pop();
    }
  }

  int get _pasoIndice {
    switch (_paso) {
      case _PasoPlan.titulo:
        return 1;
      case _PasoPlan.identidad:
        return 2;
      case _PasoPlan.descripcion:
      case _PasoPlan.descripcionPreview:
        return 3;
      case _PasoPlan.local:
        return 4;
      case _PasoPlan.fondo:
        return 5;
      case _PasoPlan.fechas:
      case _PasoPlan.fechasPreview:
        return 6;
      case _PasoPlan.union:
        return 7;
      case _PasoPlan.contacto:
        return 8;
      case _PasoPlan.resumen:
      case _PasoPlan.guardando:
        return 9;
      case _PasoPlan.felicitacion:
        return 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _intentarSalir();
      },
      child: CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: SafeArea(
          child: Column(
            children: [
              _HeaderPlan(paso: _pasoIndice, onClose: _intentarSalir),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  itemCount: _mensajes.length + (_botEscribiendo ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _mensajes.length) return const _TypingPlan();
                    return _mensajes[i].build();
                  },
                ),
              ),
              _AreaInputPlan(child: _buildInput()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    if (_guardando || _paso == _PasoPlan.guardando) {
      return const _InputDeshabilitadoPlan(texto: 'Publicando…');
    }
    if (_procesando || _botEscribiendo) {
      return const _InputDeshabilitadoPlan(texto: 'Un segundo…');
    }
    switch (_paso) {
      case _PasoPlan.titulo:
        return _InputTextoPlan(
          controller: _input,
          focus: _focus,
          hint: 'Nombre del plan',
          onSend: _onTexto,
        );
      case _PasoPlan.identidad:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OpcionBarraPlan(
              texto: 'Lo publico yo',
              icono: CupertinoIcons.person_fill,
              primario: true,
              onTap: _elegirOrganizadorUsuario,
            ),
            if (_squadsOrganizar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'O como admin de un squad',
                  style: GoogleFonts.baloo2(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final s in _squadsOrganizar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OpcionBarraPlan(
                            texto: s.nombre,
                            icono: CupertinoIcons.person_3_fill,
                            onTap: () => _elegirOrganizadorSquad(s),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No tenés squads donde puedas organizar. Seguí como vos.',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ],
          ],
        );
      case _PasoPlan.descripcion:
        return _InputTextoPlan(
          controller: _input,
          focus: _focus,
          hint: 'Descripción breve',
          maxLines: 3,
          onSend: _onTexto,
        );
      case _PasoPlan.descripcionPreview:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OpcionBarraPlan(
              texto: 'Está bien 👍',
              icono: CupertinoIcons.checkmark_circle_fill,
              primario: true,
              onTap: _confirmarDescripcion,
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: 'Corregir',
              icono: CupertinoIcons.pencil,
              onTap: _corregirDescripcion,
            ),
          ],
        );
      case _PasoPlan.local:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoSearchTextField(
              controller: _buscarLocal,
              placeholder: 'Buscar local de Fernecito',
              style: const TextStyle(color: Colors.white),
              onChanged: _buscar,
            ),
            if (_buscando)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: FernecitoLoader.inline(size: 18),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final l in _locales)
                      _LocalTilePlan(
                        local: l,
                        onTap: () => _seleccionarLocal(l),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      case _PasoPlan.fondo:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 190,
              child: GridView.builder(
                itemCount: fondosPlanesPreset.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.7,
                ),
                itemBuilder: (_, i) {
                  final preset = fondosPlanesPreset[i];
                  final url = ServicioSupabase().urlPortadaPlan(preset.asset);
                  return GestureDetector(
                    onTap: () => _seleccionarFondo(preset.asset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (url != null)
                            CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                          else
                            const ColoredBox(color: Color(0xFF252525)),
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Text(
                                '${preset.emoji} ${preset.nombre}',
                                style: GoogleFonts.baloo2(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 9),
            _OpcionBarraPlan(
              texto: 'Subir portada custom',
              icono: CupertinoIcons.photo_on_rectangle,
              onTap: _pickImagen,
            ),
          ],
        );
      case _PasoPlan.fechas:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OpcionBarraPlan(
              texto: 'Arranca · ${_fmt(_inicio)}',
              icono: CupertinoIcons.calendar,
              onTap: () => _pickFecha(inicio: true),
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: _fin == null ? 'Agregar fin' : 'Termina · ${_fmt(_fin!)}',
              icono: CupertinoIcons.clock,
              onTap: () => _pickFecha(inicio: false),
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: 'Confirmar fechas',
              icono: CupertinoIcons.checkmark_circle_fill,
              primario: true,
              onTap: _confirmarFechas,
            ),
          ],
        );
      case _PasoPlan.fechasPreview:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OpcionBarraPlan(
              texto: 'Están bien 👍',
              icono: CupertinoIcons.checkmark_circle_fill,
              primario: true,
              onTap: _aceptarFechasPreview,
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: 'Corregir fechas',
              icono: CupertinoIcons.pencil,
              onTap: _corregirFechas,
            ),
          ],
        );
      case _PasoPlan.union:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ChoicePlan(
                    texto: 'Entrada libre',
                    selected: _modo == 'auto',
                    onTap: () => setState(() => _modo = 'auto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoicePlan(
                    texto: 'Yo acepto',
                    selected: _modo == 'manual',
                    onTap: () => setState(() => _modo = 'manual'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StepperPlan(
                    label: 'Cupo',
                    value: _cupo,
                    onChanged: (v) => setState(() => _cupo = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StepperPlan(
                    label: 'Edad mín.',
                    value: _edadMinima,
                    min: 13,
                    onChanged: (v) => setState(() => _edadMinima = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: _permiteSquads ? 'Permite squads' : 'Solo personas',
              icono: CupertinoIcons.person_3_fill,
              onTap: () => setState(() => _permiteSquads = !_permiteSquads),
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: 'Confirmar unión',
              icono: CupertinoIcons.checkmark_circle_fill,
              primario: true,
              onTap: _confirmarUnion,
            ),
          ],
        );
      case _PasoPlan.contacto:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _OpcionBarraPlan(
                    texto: 'Contactar',
                    icono: CupertinoIcons.chat_bubble_2,
                    primario: _contactoModo == 'contactar',
                    onTap: () => setState(() => _contactoModo = 'contactar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OpcionBarraPlan(
                    texto: 'Colaborar',
                    icono: CupertinoIcons.link,
                    primario: _contactoModo == 'colaborar',
                    onTap: () => setState(() => _contactoModo = 'colaborar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InputTextoPlan(
              controller: _input,
              focus: _focus,
              hint: _contactoModo == 'colaborar'
                  ? 'ej: link o alias'
                  : 'ej un whatsapp o instagram',
              onSend: _onTexto,
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: 'Saltear contacto',
              icono: CupertinoIcons.forward,
              skip: true,
              onTap: _saltearContacto,
            ),
          ],
        );
      case _PasoPlan.resumen:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResumenPlanCard(
              titulo: _titulo,
              descripcion: _descripcion,
              local: _local?['nombre_local']?.toString() ?? 'Local',
              ciudad: _local?['ciudad']?.toString() ?? '',
              fecha:
                  '${_fmt(_inicio)}${_fin == null ? '' : ' · fin ${_fmt(_fin!)}'}',
              ingreso: _modo == 'manual' ? 'Con aprobación' : 'Entrada libre',
              cupo: _cupo == null ? 'Sin cupo' : '${_cupo!} cupos',
              organizador: _nombreOrganizador,
              contacto: _contacto,
              contactoModo: _contactoModo,
            ),
            const SizedBox(height: 8),
            _OpcionBarraPlan(
              texto: 'Publicar plan',
              icono: CupertinoIcons.paperplane_fill,
              primario: true,
              onTap: _guardar,
            ),
          ],
        );
      case _PasoPlan.felicitacion:
        return _OpcionBarraPlan(
          texto: 'Ver cartelera',
          icono: CupertinoIcons.square_grid_2x2_fill,
          primario: true,
          onTap: () => Navigator.of(context).pop(true),
        );
      default:
        return const _InputDeshabilitadoPlan(texto: 'Un segundo…');
    }
  }
}

class _HeaderPlan extends StatelessWidget {
  const _HeaderPlan({required this.paso, required this.onClose});
  final int paso;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ColoresApp.principalMarca,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asistente de planes',
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Te ayudo a publicarlo sin vueltas',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onClose,
              child: Icon(
                CupertinoIcons.xmark,
                color: Colors.white.withValues(alpha: 0.72),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: paso / 10,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(ColoresApp.principalMarca),
          ),
        ),
      ],
    ),
  );
}

class _MensajePlan {
  const _MensajePlan._(this.child, this.esBot);
  factory _MensajePlan.bot(Widget child) => _MensajePlan._(child, true);
  factory _MensajePlan.usuario(Widget child) => _MensajePlan._(child, false);

  final Widget child;
  final bool esBot;

  Widget build() => Align(
    alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 310),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: esBot
            ? Colors.white.withValues(alpha: 0.08)
            : ColoresApp.principalMarca,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(17),
          topRight: const Radius.circular(17),
          bottomLeft: Radius.circular(esBot ? 5 : 17),
          bottomRight: Radius.circular(esBot ? 17 : 5),
        ),
      ),
      child: child,
    ),
  );
}

class _TextoBurbujaPlan extends StatelessWidget {
  const _TextoBurbujaPlan(this.texto, {required this.esBot});
  final String texto;
  final bool esBot;

  static final _boldRe = RegExp(r'\*\*(.+?)\*\*');

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: esBot ? 0.92 : 1);
    final base = GoogleFonts.baloo2(
      fontSize: 14.5,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: color,
    );
    final spans = <TextSpan>[];
    var rest = texto;
    while (rest.isNotEmpty) {
      final m = _boldRe.firstMatch(rest);
      if (m == null) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (m.start > 0) spans.add(TextSpan(text: rest.substring(0, m.start)));
      spans.add(
        TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.w900),
        ),
      );
      rest = rest.substring(m.end);
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

class _TypingPlan extends StatelessWidget {
  const _TypingPlan();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(17),
          topRight: Radius.circular(17),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(17),
        ),
      ),
      child: const _PuntosAnimadosPlan(),
    ),
  );
}

class _PuntosAnimadosPlan extends StatefulWidget {
  const _PuntosAnimadosPlan();

  @override
  State<_PuntosAnimadosPlan> createState() => _PuntosAnimadosPlanState();
}

class _PuntosAnimadosPlanState extends State<_PuntosAnimadosPlan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
            final op = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(
              0.3,
              1.0,
            );
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.principalMarca.withValues(alpha: op),
              ),
            );
          }),
        );
      },
    );
  }
}

class _InputDeshabilitadoPlan extends StatelessWidget {
  const _InputDeshabilitadoPlan({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ColoresApp.principalMarca,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _AreaInputPlan extends StatelessWidget {
  const _AreaInputPlan({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, keyboardAbierto ? 6 : safe + 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151515).withValues(alpha: 0.98),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InputTextoPlan extends StatelessWidget {
  const _InputTextoPlan({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.onSend,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final VoidCallback onSend;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: CupertinoTextField(
          controller: controller,
          focusNode: focus,
          placeholder: hint,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          placeholderStyle: TextStyle(
            color: ColoresApp.textoSecundario.withValues(alpha: 0.72),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(17),
          ),
          onSubmitted: (_) => onSend(),
        ),
      ),
      const SizedBox(width: 8),
      CupertinoButton(
        padding: const EdgeInsets.all(12),
        color: ColoresApp.principalMarca,
        borderRadius: BorderRadius.circular(16),
        onPressed: onSend,
        child: const Icon(
          CupertinoIcons.arrow_up,
          color: Colors.white,
          size: 18,
        ),
      ),
    ],
  );
}

class _ChipRespuesta extends StatelessWidget {
  const _ChipRespuesta({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, color: Colors.white, size: 16),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          texto,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.baloo2(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );
}

class _LocalTilePlan extends StatelessWidget {
  const _LocalTilePlan({required this.local, required this.onTap});
  final Map<String, dynamic> local;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = ServicioSupabase().urlAvatar(
      local['foto_perfil_url']?.toString(),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 36,
                height: 36,
                child: url != null && url.isNotEmpty
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
                    : const ColoredBox(color: Color(0xFF303030)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    local['nombre_local']?.toString() ?? 'Local',
                    style: GoogleFonts.baloo2(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    [
                          local['ciudad']?.toString(),
                          local['provincia']?.toString(),
                        ]
                        .where((e) => e != null && e.trim().isNotEmpty)
                        .join(' · '),
                    style: GoogleFonts.baloo2(
                      fontSize: 11.5,
                      color: ColoresApp.textoSecundario,
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
}

class _OpcionBarraPlan extends StatelessWidget {
  const _OpcionBarraPlan({
    required this.texto,
    required this.icono,
    required this.onTap,
    this.primario = false,
    this.skip = false,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  final bool primario;
  final bool skip;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (primario) {
      bg = ColoresApp.principalMarca;
      fg = Colors.white;
    } else if (skip) {
      bg = Colors.transparent;
      fg = ColoresApp.textoSecundario;
    } else {
      bg = Colors.white.withValues(alpha: 0.08);
      fg = Colors.white;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icono, color: fg, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: GoogleFonts.baloo2(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoicePlan extends StatelessWidget {
  const _ChoicePlan({
    required this.texto,
    required this.selected,
    required this.onTap,
  });
  final String texto;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: selected
            ? ColoresApp.principalMarca
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _StepperPlan extends StatelessWidget {
  const _StepperPlan({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
  });

  final String label;
  final int? value;
  final int min;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${value ?? 'no'}',
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (value == null || value! <= min) {
              onChanged(null);
            } else {
              onChanged(value! - 1);
            }
          },
          child: const Icon(CupertinoIcons.minus_circle, color: Colors.white),
        ),
        const SizedBox(width: 9),
        GestureDetector(
          onTap: () => onChanged((value ?? (min - 1)) + 1),
          child: const Icon(
            CupertinoIcons.plus_circle_fill,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _ResumenPlanCard extends StatelessWidget {
  const _ResumenPlanCard({
    required this.titulo,
    required this.descripcion,
    required this.local,
    required this.ciudad,
    required this.fecha,
    required this.ingreso,
    required this.cupo,
    required this.organizador,
    this.contacto,
    this.contactoModo = 'contactar',
  });

  final String titulo;
  final String descripcion;
  final String local;
  final String ciudad;
  final String fecha;
  final String ingreso;
  final String cupo;
  final String organizador;
  final String? contacto;
  final String contactoModo;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: GoogleFonts.baloo2(
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          descripcion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.baloo2(
            fontSize: 12.5,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _PillPlan('Organiza: $organizador'),
            _PillPlan('$local · $ciudad'),
            _PillPlan(fecha),
            _PillPlan(ingreso),
            _PillPlan(cupo),
            if ((contacto ?? '').trim().isNotEmpty)
              _PillPlan(
                contactoModo == 'colaborar'
                    ? 'Colaborar: ${contacto!.trim()}'
                    : 'Contactar: ${contacto!.trim()}',
              ),
          ],
        ),
      ],
    ),
  );
}

class _PillPlan extends StatelessWidget {
  const _PillPlan(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE5E7EB).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      texto,
      style: GoogleFonts.baloo2(
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    ),
  );
}

String _fmt(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month} ${two(d.hour)}:${two(d.minute)}';
}
