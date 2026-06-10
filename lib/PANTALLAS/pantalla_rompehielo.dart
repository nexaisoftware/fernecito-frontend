/// Pantalla Rompehielo — Persona↔Persona, Squad↔Squad.
/// Persona: siempre aparezco como "Yo" con avatar real de Supabase.
/// Squad: elijo con qué squad rompo/respondo (stack de avatares + nombre).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/servicio_rompehielo.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/card_contexto_rompehielo.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/stack_avatares_squad.dart';

// Rompe hielo persona → persona (5 mensajes)
const List<String> _iniciadorPersona = [
  '¿Hacemos previa? 😉',
  '¿Hacemos after? 🔥',
  '¿Te sumás al plan? 👀',
  '¿Nos vemos ahí? 🙌',
  '¿Qué te gusta tomar? 😏',
];
// Rompe hielo squad → squad (5 mensajes)
const List<String> _iniciadorSquad = [
  '¿Hacemos previa? 🙌',
  '¿Hacemos after todos? 🔥',
  '¿Se animan al plan? 👀',
  '¿Vamos todos juntos? 😎',
  '¿Armamos algo grande? 🥳',
];

// Chips predeterminados DENTRO de la burbuja cuando respondo (5 + "más")
const List<String> _chipsRespuestaDefault = [
  '👍 Sí, dale!',
  '👎 No gracias',
  '💬 ¡Hablame por IG!',
  '👀 Me interesa',
  '🍻 ¡Claro, vamos!',
  '❤️',
];
// "Más" mensajes para usuario (persona) — genéricos y simpáticos
const List<String> _masMensajesUsuario = [
  'Dale, nos vemos!',
  'Uh, no puedo esta vez',
  'Re copado, ahí estaré',
  'Te aviso si me sumo',
  'Gracias por la onda!',
];
// "Más" mensajes para squad — genéricos y simpáticos
const List<String> _masMensajesSquad = [
  'Los del squad dicen que sí!',
  'Con el grupo nos sumamos',
  'Paso esta vez, otra?',
  'Re buena la onda',
  'Nos vemos ahí!',
];

const int _maxChars = 100;
const double _avatarRompehielo = 76;
const double _bubbleFontSize = 18;
const Duration _durAnimRompehielo = Duration(milliseconds: 280);

/// Fade + slide suave para entradas/salidas del hilo.
Widget _transicionRompehielo(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

Widget _slotAnimado({
  required bool visible,
  required String slotId,
  required Widget Function() builder,
}) {
  return AnimatedSwitcher(
    duration: _durAnimRompehielo,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: _transicionRompehielo,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        ...previous,
        if (current != null) current,
      ],
    ),
    child: visible
        ? KeyedSubtree(key: ValueKey(slotId), child: builder())
        : SizedBox.shrink(key: ValueKey('$slotId-off')),
  );
}
const double _nombreFontSize = 17;

/// Contraparte: usuario individual o squad.
enum TipoContraparte { usuario, squad }

/// Datos para abrir la pantalla.
class RompehieloData {
  final TipoContraparte tipoContraparte;
  final Map<String, dynamic> contraparte;
  final RompehieloEstado? estadoInicial;
  final RompehieloOrigen origen;
  final String? idEvento;
  final String? nombreEvento;
  /// Squad con el que actúo (`null` = yo). Fijado al iniciar o al abrir fila existente.
  final String? idGrupoActorInicial;
  final Map<String, dynamic>? squadActorInicial;

  /// Si true, la identidad ya quedó en la fila — no se puede cambiar.
  final bool identidadFijada;

  const RompehieloData({
    required this.tipoContraparte,
    required this.contraparte,
    this.estadoInicial,
    this.origen = RompehieloOrigen.perfil,
    this.idEvento,
    this.nombreEvento,
    this.idGrupoActorInicial,
    this.squadActorInicial,
    this.identidadFijada = false,
  });

  String get otroTipo =>
      tipoContraparte == TipoContraparte.usuario ? 'usuario' : 'squad';

  String get otroId {
    if (tipoContraparte == TipoContraparte.usuario) {
      return contraparte['id_usuario']?.toString() ?? '';
    }
    return contraparte['id_grupo']?.toString() ??
        contraparte['id']?.toString() ??
        '';
  }
}

class PantallaRompehielo extends StatefulWidget {
  final RompehieloData data;

  const PantallaRompehielo({super.key, required this.data});

  @override
  State<PantallaRompehielo> createState() => _PantallaRompehieloState();
}

class _PantallaRompehieloState extends State<PantallaRompehielo> {
  String? _miMensaje;
  Map<String, dynamic>? _responderComo;
  String? _miAvatarUrl;
  bool _mensajeEnviado = false;
  bool _enviando = false;
  bool _replicaAbierta = false;
  RompehieloEstado? _estado;
  List<MiembroSquad> _miembrosContraparte = const [];
  final TextEditingController _controller = TextEditingController();
  final ServicioRompehielo _srv = ServicioRompehielo();

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _estado = d.estadoInicial;
    if (d.identidadFijada) {
      _responderComo = d.squadActorInicial;
    }
    _cargarMiAvatar();
    _cargarEstado();
    _cargarMiembrosContraparte();
  }

  Future<void> _cargarMiembrosContraparte() async {
    if (widget.data.tipoContraparte != TipoContraparte.squad) return;
    final id = widget.data.otroId;
    if (id.isEmpty) return;
    final det = await ServicioSquads().detalle(id);
    if (!mounted || det == null) return;
    setState(() {
      _miembrosContraparte = det.miembros;
    });
  }

  String? get _idGrupoActor =>
      widget.data.idGrupoActorInicial ??
      _responderComo?['id_grupo']?.toString();

  Future<void> _cargarEstado() async {
    final d = widget.data;
    final idGrupo = _idGrupoActor;
    final est = await _srv.estado(
      otroTipo: d.otroTipo,
      otroId: d.otroId,
      idGrupoActor: idGrupo,
    );
    if (!mounted) return;
    final modoNuevo = est.puedeActuar &&
        (est.accionSugerida == RompehieloAccion.replicar ||
            est.accionSugerida == RompehieloAccion.responder ||
            est.accionSugerida == RompehieloAccion.iniciar);

    setState(() {
      _estado = est;
      if (modoNuevo) {
        _miMensaje = '';
        _controller.clear();
        _mensajeEnviado = false;
        _replicaAbierta = false;
      } else if (est.mensajeMio != null && est.mensajeMio!.isNotEmpty) {
        _miMensaje = est.mensajeMio;
        _controller.text = est.mensajeMio!;
        _mensajeEnviado = true;
      } else {
        _mensajeEnviado = false;
      }
    });
  }

  bool get _replicaPendiente =>
      _estado?.accionSugerida == RompehieloAccion.replicar &&
      _estado?.puedeActuar == true &&
      !_mensajeEnviado;

  bool get _puedeEscribir {
    if (_estado?.puedeActuar != true || _mensajeEnviado || _enviando) {
      return false;
    }
    if (_replicaPendiente) return _replicaAbierta;
    return true;
  }

  bool get _esIniciador =>
      _estado == null ||
      _estado!.accionSugerida == RompehieloAccion.iniciar;

  bool get _esReplica => _replicaPendiente && _replicaAbierta;

  bool get _esResponder =>
      _estado?.accionSugerida == RompehieloAccion.responder && _puedeEscribir;

  /// Glow del otro: activo hasta que abrís réplica o enviás.
  bool get _contraparteEsNuevo =>
      !_replicaAbierta && (_replicaPendiente || _puedeEscribir);

  /// Glow del composer al escribir réplica (antes de enviar).
  bool get _composerEsFoco => _replicaAbierta && _puedeEscribir;

  /// Glow propio al enviar o mientras espero al otro.
  bool get _mioEsNuevo {
    final texto = (_miMensaje ?? '').trim();
    if (texto.isEmpty) return false;
    if (_enviando) return true;
    return _mensajeEnviado && !_puedeEscribir;
  }

  double get _opacityContraparte {
    if (_mioEsNuevo || _replicaAbierta) return 0.36;
    return _contraparteEsNuevo ? 1.0 : 0.72;
  }

  /// Burbuja propia anterior, visible atenuada antes de tocar «Replicar».
  bool get _mioEsViejo => _replicaPendiente && !_replicaAbierta;

  double get _opacityMio => _mioEsViejo ? 0.72 : 1.0;

  String get _placeholderComposer {
    if (_esReplica) return 'Escribí tu réplica...';
    if (_esResponder) return 'Escribí tu respuesta...';
    return 'Romper el hielo...';
  }

  String get _nombreContraparte {
    final d = widget.data;
    if (d.tipoContraparte == TipoContraparte.squad) {
      return d.contraparte['nombre'] as String? ?? 'Squad';
    }
    final u = d.contraparte['username'] as String? ?? '@contraparte';
    return u.startsWith('@') ? u : '@$u';
  }

  String? get _mensajeContraparte => _estado?.mensajeOtro;

  /// Burbuja propia visible abajo: anterior, enviando o ya enviada.
  String? get _mensajeMioVisible {
    if (_replicaPendiente && !_replicaAbierta && !_enviando) {
      final m = _estado?.mensajeMio;
      return (m != null && m.isNotEmpty) ? m : null;
    }
    final texto = (_miMensaje ?? '').trim();
    if (texto.isEmpty) return null;
    if (_enviando || (_mensajeEnviado && !_puedeEscribir)) {
      return _miMensaje;
    }
    return null;
  }

  void _abrirReplica() {
    setState(() {
      _replicaAbierta = true;
      _miMensaje = '';
      _controller.clear();
    });
  }

  Future<void> _cargarMiAvatar() async {
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null || !mounted) return;
      final respuesta = await supabase.cliente
          .from('perfiles_usuarios')
          .select('foto_perfil_url')
          .eq('id', usuario.id)
          .maybeSingle();
      if (!mounted) return;
      if (respuesta != null && respuesta['foto_perfil_url'] != null) {
        final path = respuesta['foto_perfil_url'] as String;
        final ts = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _miAvatarUrl = '${supabase.cliente.storage
              .from('avatars')
              .getPublicUrl(path)}?v=$ts';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cerrar() => Navigator.of(context).pop();

  Future<void> _ignorar() async {
    final d = widget.data;
    final confirmar = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Ignorar rompehielo'),
        content: const Text(
          'No vas a seguir esta conversación y le va a quedar claro que no '
          'querés continuar. ¿Seguro?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ignorar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final res = await _srv.ignorar(
      otroTipo: d.otroTipo,
      otroId: d.otroId,
      idGrupoActor: _idGrupoActor,
    );
    if (!mounted) return;
    if (res.error != null) {
      showCupertinoDialog<void>(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text('Rompehielo'),
          content: const Text('No se pudo ignorar. Intentá de nuevo.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  void _seleccionarMensaje(String msg) {
    setState(() {
      _miMensaje = msg;
      _controller.text = msg;
    });
  }

  Future<void> _onEnviarMensaje() async {
    final texto = (_miMensaje ?? '').trim();
    if (texto.isEmpty || _enviando) return;
    final d = widget.data;
    setState(() => _enviando = true);
    final res = await _srv.actuar(
      otroTipo: d.otroTipo,
      otroId: d.otroId,
      mensaje: texto,
      idGrupoActor: _idGrupoActor,
      idEvento: d.idEvento,
      origen: d.origen,
      nombreEvento: d.nombreEvento,
    );
    if (!mounted) return;
    if (res.error != null) {
      setState(() => _enviando = false);
      final msg = switch (res.error) {
        'no_es_tu_turno' => 'Todavía no es tu turno.',
        'rate_limit' => 'Llegaste al límite de mensajes por hoy.',
        'mensaje_invalido' => 'El mensaje debe tener entre 1 y 100 caracteres.',
        _ => 'No se pudo enviar. Intentá de nuevo.',
      };
      showCupertinoDialog(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text('Rompehielo'),
          content: Text(msg),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final nuevo = res.estado!;
    setState(() {
      _enviando = false;
      _estado = nuevo;
      _mensajeEnviado = true;
      _miMensaje = texto;
      _controller.text = texto;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final esIniciador = _esIniciador;
    final mensajeContra = _mensajeContraparte;
    final turnoLabel = _estado?.ignorado == true
        ? (_estado?.ignoradoPorMi == true
            ? 'Ignorado por vos'
            : 'No quiere seguir el rompehielo')
        : _replicaPendiente && !_replicaAbierta
            ? 'Tu réplica'
            : _estado?.puedeActuar == true
                ? (_esReplica
                    ? 'Tu réplica'
                    : _esResponder
                        ? 'Tu respuesta'
                        : 'Tu turno')
                : 'Esperando al otro';

    final composer = _puedeEscribir
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MensajeNuevoHighlight(
                activo: _composerEsFoco,
                child: _ComposerRompehielo(
                  controller: _controller,
                  placeholder: _placeholderComposer,
                  enviando: _enviando,
                  puedeEnviar: (_miMensaje ?? '').trim().isNotEmpty,
                  onChanged: (v) => setState(() => _miMensaje = v),
                  onEnviar: _onEnviarMensaje,
                  esReplica: _esReplica,
                ),
              ),
              const SizedBox(height: 8),
              _TemplatesChips(
                esIniciador: esIniciador,
                esReplica: _esReplica,
                tipoContraparte: d.tipoContraparte,
                onSelect: _seleccionarMensaje,
              ),
            ],
          )
        : null;

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SafeArea(
          child: Column(
            children: [
              _NavBarRompehielo(
                turnoLabel: turnoLabel,
                onBack: _cerrar,
                onIgnorar: _ignorar,
                puedeIgnorar: _estado?.puedeIgnorar == true,
              ),
              CardContextoRompehielo(
                estado: _estado,
                esSquad: d.tipoContraparte == TipoContraparte.squad,
                contraparte: d.contraparte,
                miembrosSquad: _miembrosContraparte,
              ),
              Expanded(
                child: _RompehieloHilo(
                  contraparteAvatar: d.tipoContraparte == TipoContraparte.usuario
                      ? AvatarBordeBlanco(
                          avatar: d.contraparte['avatar'] as String? ?? '',
                          size: _avatarRompehielo,
                        )
                      : StackAvataresSquad(
                          avatares: List<String>.from(
                              d.contraparte['miembrosAvatares'] as List? ?? []),
                          totalExtra: (d.contraparte['miembrosTotal'] as int?) ??
                              List<String>.from(
                                      d.contraparte['miembrosAvatares']
                                          as List? ??
                                      [])
                                  .length,
                          size: _avatarRompehielo,
                        ),
                  nombreContraparte: _nombreContraparte,
                  mensajeContraparte: mensajeContra,
                  opacityContraparte: _opacityContraparte,
                  contraparteEsNuevo: _contraparteEsNuevo,
                  esIniciador: esIniciador,
                  puedeEscribir: _puedeEscribir,
                  composerCentro: _esReplica ? null : composer,
                  composerAbajo: _esReplica ? composer : null,
                  mostrarBotonReplicar:
                      _replicaPendiente && !_replicaAbierta,
                  onReplicar: _abrirReplica,
                  mensajeMio: _mensajeMioVisible,
                  opacityMio: _opacityMio,
                  mioEsNuevo: _mioEsNuevo,
                  yoAvatar: _responderComo == null
                      ? AvatarBordeBlanco(
                          avatar: _miAvatarUrl ?? '',
                          size: _avatarRompehielo,
                        )
                      : StackAvataresSquad(
                          avatares: List<String>.from(
                              _responderComo!['miembrosAvatares'] as List? ??
                                  []),
                          totalExtra: (_responderComo!['miembrosTotal'] as int?) ??
                              List<String>.from(
                                      _responderComo!['miembrosAvatares']
                                          as List? ??
                                      [])
                                  .length,
                          size: _avatarRompehielo,
                        ),
                  yoEtiqueta: _responderComo == null
                      ? 'Yo'
                      : (_responderComo!['nombre'] as String? ?? 'Squad'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hilo vertical: contraparte arriba → gap corto → yo abajo. Sin Spacers.
class _RompehieloHilo extends StatelessWidget {
  const _RompehieloHilo({
    required this.contraparteAvatar,
    required this.nombreContraparte,
    this.mensajeContraparte,
    required this.opacityContraparte,
    required this.contraparteEsNuevo,
    required this.esIniciador,
    required this.puedeEscribir,
    this.composerCentro,
    this.composerAbajo,
    this.mostrarBotonReplicar = false,
    this.onReplicar,
    this.mensajeMio,
    this.opacityMio = 1.0,
    required this.mioEsNuevo,
    required this.yoAvatar,
    required this.yoEtiqueta,
  });

  final Widget contraparteAvatar;
  final String nombreContraparte;
  final String? mensajeContraparte;
  final double opacityContraparte;
  final bool contraparteEsNuevo;
  final bool esIniciador;
  final bool puedeEscribir;
  final Widget? composerCentro;
  final Widget? composerAbajo;
  final bool mostrarBotonReplicar;
  final VoidCallback? onReplicar;
  final String? mensajeMio;
  final double opacityMio;
  final bool mioEsNuevo;
  final Widget yoAvatar;
  final String yoEtiqueta;

  static const _gapBurbujas = 14.0;
  static const _gapAvatarBurbuja = 10.0;

  TextStyle get _estiloNombre => GoogleFonts.baloo2(
        fontSize: _nombreFontSize,
        fontWeight: FontWeight.w800,
        color: ColoresApp.textoPrincipal,
      );

  @override
  Widget build(BuildContext context) {
    final tieneBurbujaContra =
        mensajeContraparte != null && mensajeContraparte!.isNotEmpty;
    final tieneBurbujaMia =
        mensajeMio != null && mensajeMio!.trim().isNotEmpty;
    final mostrarEsperaContraparte =
        !tieneBurbujaContra && (esIniciador || tieneBurbujaMia);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Arriba: avatar → nombre → burbuja (cola ↑) ──
                Center(child: contraparteAvatar),
                const SizedBox(height: 4),
                Text(
                  nombreContraparte,
                  textAlign: TextAlign.center,
                  style: _estiloNombre,
                ),
                const SizedBox(height: _gapAvatarBurbuja),
                _slotAnimado(
                  visible: tieneBurbujaContra,
                  slotId: 'contra-${mensajeContraparte ?? ''}',
                  builder: () => AnimatedOpacity(
                    duration: _durAnimRompehielo,
                    curve: Curves.easeOut,
                    opacity: opacityContraparte,
                    child: _MensajeNuevoHighlight(
                      activo: contraparteEsNuevo,
                      child: _burbujaRompehielo(
                        texto: mensajeContraparte!,
                        esMio: false,
                        colaHaciaArriba: true,
                      ),
                    ),
                  ),
                ),
                _slotAnimado(
                  visible: !tieneBurbujaContra && mostrarEsperaContraparte,
                  slotId: 'contra-espera',
                  builder: () => AnimatedOpacity(
                    duration: _durAnimRompehielo,
                    curve: Curves.easeOut,
                    opacity: opacityContraparte,
                    child: _burbujaRompehielo(
                      texto: '',
                      esMio: false,
                      colaHaciaArriba: true,
                    ),
                  ),
                ),
                if (tieneBurbujaContra || mostrarEsperaContraparte)
                  const SizedBox(height: _gapBurbujas),
                AnimatedSize(
                    duration: _durAnimRompehielo,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _slotAnimado(
                          visible:
                              puedeEscribir && composerCentro != null,
                          slotId: 'composer-centro',
                          builder: () => composerCentro!,
                        ),
                        if (puedeEscribir && composerCentro != null)
                          const SizedBox(height: _gapBurbujas),
                        // ── Abajo: burbuja → replicar → composer → yo ──
                        _slotAnimado(
                          visible: tieneBurbujaMia,
                          slotId: 'mia-${mensajeMio ?? ''}',
                          builder: () => AnimatedOpacity(
                            duration: _durAnimRompehielo,
                            curve: Curves.easeOut,
                            opacity: opacityMio,
                            child: _MensajeNuevoHighlight(
                              activo: mioEsNuevo,
                              child: _burbujaRompehielo(
                                texto: mensajeMio!,
                                esMio: true,
                                colaHaciaArriba: false,
                              ),
                            ),
                          ),
                        ),
                        if (tieneBurbujaMia)
                          const SizedBox(height: _gapAvatarBurbuja),
                        _slotAnimado(
                          visible:
                              mostrarBotonReplicar && onReplicar != null,
                          slotId: 'btn-replicar',
                          builder: () => Center(
                            child: _BotonReplicar(onTap: onReplicar!),
                          ),
                        ),
                        if (mostrarBotonReplicar && onReplicar != null)
                          const SizedBox(height: 10),
                        _slotAnimado(
                          visible:
                              puedeEscribir && composerAbajo != null,
                          slotId: 'composer-abajo',
                          builder: () => composerAbajo!,
                        ),
                        if (puedeEscribir && composerAbajo != null)
                          const SizedBox(height: _gapBurbujas),
                      ],
                    ),
                  ),
                Text(
                    yoEtiqueta,
                    textAlign: TextAlign.center,
                    style: _estiloNombre,
                  ),
                  const SizedBox(height: 4),
                  Center(child: yoAvatar),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BotonReplicar extends StatelessWidget {
  const _BotonReplicar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: ColoresApp.principalMarca.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          'Replicar',
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: ColoresApp.principalMarca,
          ),
        ),
      ),
    );
  }
}

class _NavBarRompehielo extends StatelessWidget {
  const _NavBarRompehielo({
    required this.turnoLabel,
    required this.onBack,
    required this.onIgnorar,
    this.puedeIgnorar = false,
  });

  final String turnoLabel;
  final VoidCallback onBack;
  final VoidCallback onIgnorar;
  final bool puedeIgnorar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: onBack,
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 22,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Rompehielo',
                  style: GoogleFonts.baloo2(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                Text(
                  turnoLabel,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ],
            ),
          ),
          if (puedeIgnorar)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              onPressed: onIgnorar,
              child: Text(
                'Ignorar',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.peligroMarca,
                ),
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              onPressed: onBack,
              child: Text(
                'Cerrar',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Resalta el mensaje nuevo del otro: breath más rápido + brillo de marca.
class _MensajeNuevoHighlight extends StatefulWidget {
  const _MensajeNuevoHighlight({
    required this.child,
    required this.activo,
  });

  final Widget child;
  final bool activo;

  @override
  State<_MensajeNuevoHighlight> createState() => _MensajeNuevoHighlightState();
}

class _MensajeNuevoHighlightState extends State<_MensajeNuevoHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.18, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.activo) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _MensajeNuevoHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activo && !oldWidget.activo) {
      _controller.repeat(reverse: true);
    } else if (!widget.activo && oldWidget.activo) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activo) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ColoresApp.principalMarca
                      .withValues(alpha: _glow.value),
                  blurRadius: 18 + _glow.value * 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Burbuja del hilo rompehielo (delega en [BurbujaEstado] unificado).
Widget _burbujaRompehielo({
  required String texto,
  required bool esMio,
  required bool colaHaciaArriba,
}) =>
    BurbujaEstado(
      texto: texto,
      esMio: esMio,
      colaHaciaArriba: colaHaciaArriba,
      fontSize: _bubbleFontSize,
      maxLines: 6,
      ajustarAnchoAlTexto: true,
      minWidth: 136,
      maxWidth: 318,
    );

class _ComposerRompehielo extends StatelessWidget {
  const _ComposerRompehielo({
    required this.controller,
    required this.placeholder,
    required this.enviando,
    required this.puedeEnviar,
    required this.onChanged,
    required this.onEnviar,
    required this.esReplica,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool enviando;
  final bool puedeEnviar;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnviar;
  final bool esReplica;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (esReplica)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Respondé a lo nuevo',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ColoresApp.principalMarca,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: ColoresApp.principalMarca.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  onChanged: onChanged,
                  maxLength: _maxChars,
                  maxLines: 3,
                  minLines: 1,
                  style: GoogleFonts.baloo2(
                    fontSize: _bubbleFontSize,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoPrincipal,
                  ),
                  placeholder: placeholder,
                  placeholderStyle: GoogleFonts.baloo2(
                    fontSize: _bubbleFontSize,
                    fontWeight: FontWeight.w500,
                    color: ColoresApp.textoSecundario.withValues(alpha: 0.65),
                  ),
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                onPressed: enviando || !puedeEnviar ? null : onEnviar,
                child: enviando
                    ? const CupertinoActivityIndicator(radius: 10)
                    : Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: puedeEnviar
                              ? ColoresApp.principalMarca
                              : ColoresApp.fondoSuperficie,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ColoresApp.principalMarca
                                .withValues(alpha: puedeEnviar ? 1 : 0.25),
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_up,
                          size: 18,
                          color: puedeEnviar
                              ? Colors.white
                              : ColoresApp.textoSecundario,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplatesChips extends StatefulWidget {
  final bool esIniciador;
  final bool esReplica;
  final TipoContraparte tipoContraparte;
  final void Function(String) onSelect;

  const _TemplatesChips({
    required this.esIniciador,
    this.esReplica = false,
    required this.tipoContraparte,
    required this.onSelect,
  });

  @override
  State<_TemplatesChips> createState() => _TemplatesChipsState();
}

class _TemplatesChipsState extends State<_TemplatesChips> {
  bool _mostrarMas = false;

  List<String> get _listaBase {
    if (widget.esIniciador) {
      return widget.tipoContraparte == TipoContraparte.usuario
          ? _iniciadorPersona
          : _iniciadorSquad;
    }
    return _chipsRespuestaDefault.take(5).toList();
  }

  List<String> get _listaExtra {
    return widget.tipoContraparte == TipoContraparte.squad
        ? _masMensajesSquad
        : _masMensajesUsuario;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> items;
    if (widget.esIniciador) {
      items = _listaBase;
    } else if (_mostrarMas) {
      items = [..._listaBase, ..._listaExtra, 'menos'];
    } else {
      items = [..._listaBase, 'más'];
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items.map((msg) {
        final esToggle = msg == 'más' || msg == 'menos';
        return GestureDetector(
          onTap: () {
            if (esToggle) {
              setState(() => _mostrarMas = msg == 'más');
              return;
            }
            widget.onSelect(msg);
            if (_mostrarMas) setState(() => _mostrarMas = false);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: esToggle
                  ? ColoresApp.principalMarca.withValues(alpha: 0.14)
                  : ColoresApp.fondoSuperficie.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ColoresApp.principalMarca
                    .withValues(alpha: esToggle ? 0.55 : 0.28),
              ),
            ),
            child: Text(
              msg,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: esToggle ? FontWeight.w700 : FontWeight.w600,
                color: esToggle
                    ? ColoresApp.principalMarca
                    : ColoresApp.textoPrincipal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
