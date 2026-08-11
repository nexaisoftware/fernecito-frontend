/// Fernecito Match — lista de matches y chats.
///
/// Cada fila: avatar + "Match con {nombre}" + plan del match (el que recibió
/// el "me interesa" que lo completó) + último mensaje. Desde acá: abrir chat,
/// ver perfil del otro, o bloquear.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_match.dart';
import '../widgets/avatar_bordes.dart';
import '../widgets/avatar_usuario.dart';
import 'pantalla_match_chat.dart';
import 'pantalla_perfil_squads.dart';
import 'pantalla_perfil_usuarios.dart';

/// Azul del "Me re pinta" 🥂 (mismo del deck).
const _kAzulRePinta = Color(0xFF3B82F6);

class PantallaMatchChats extends StatefulWidget {
  const PantallaMatchChats({super.key});

  @override
  State<PantallaMatchChats> createState() => _PantallaMatchChatsState();
}

class _PantallaMatchChatsState extends State<PantallaMatchChats> {
  final _srv = ServicioMatch();
  bool _cargando = true;
  List<MatchItem> _matches = const [];
  List<MatchPendiente> _pendientes = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final resultados = await Future.wait([
      _srv.misMatches(),
      _srv.pendientes(),
    ]);
    if (!mounted) return;
    setState(() {
      _matches = resultados[0] as List<MatchItem>;
      _pendientes = resultados[1] as List<MatchPendiente>;
      _cargando = false;
    });
  }

  Future<void> _verPerfil(MatchItem m) async {
    final otro = m.otro;
    if (otro.esSquad) {
      if (otro.idGrupo == null) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => PantallaPerfilSquads(
            squad: {
              'id_grupo': otro.idGrupo,
              'nombre_grupo': otro.nombre,
              'url_portada': otro.fotoPath,
            },
            estadoRelacion: EstadoRelacionSquad.ninguno,
          ),
        ),
      );
    } else {
      if (otro.idUsuario == null) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => PantallaPerfilUsuarios(
            usuario: {
              'id_usuario': otro.idUsuario,
              'username': otro.username,
              'perfil_publico': otro.perfilPublico,
              if (otro.fotoUrl != null) 'avatar': otro.fotoUrl,
            },
            estadoRelacion: EstadoRelacionUsuario.ninguno,
          ),
        ),
      );
    }
  }

  Future<void> _bloquear(MatchItem m) async {
    final confirmar = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('¿Bloquear a ${m.otro.nombre}?'),
        content: const Text(
          'No van a volver a cruzarse en Match y este chat se cierra. Podés desbloquear más adelante desde soporte.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final ok = await _srv.bloquear(
      idUsuario: m.otro.esSquad ? null : m.otro.idUsuario,
      idGrupo: m.otro.esSquad ? m.otro.idGrupo : null,
    );
    if (ok && mounted) {
      setState(() => _matches =
          _matches.where((x) => x.idMatch != m.idMatch).toList());
    }
  }

  void _menuFila(MatchItem m) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          'Match con ${m.otro.nombre}',
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
        ),
        message: Text(
          m.planResumen,
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _abrirChat(m);
            },
            child: const Text('💬 Abrir chat'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _verPerfil(m);
            },
            child: Text(m.otro.esSquad ? '👥 Ver squad' : '👤 Ver perfil'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelarMatch(m);
            },
            child: const Text('✋ Cancelar match'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _bloquear(m);
            },
            child: const Text('🚫 Bloquear'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  /// Cancela el match: borra chat y match, pero pueden volver a cruzarse en
  /// las cards (a diferencia del bloqueo, que es definitivo).
  Future<void> _cancelarMatch(MatchItem m) async {
    final confirmar = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('¿Cancelar el match con ${m.otro.nombre}?'),
        content: const Text(
          'Se borra este chat y el match. Igual pueden volver a cruzarse en las cards: capaz este plan no pintó, pero otro sí 😉',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar match'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final ok = await _srv.cancelarMatch(m.idMatch);
    if (ok && mounted) {
      setState(
        () => _matches = _matches.where((x) => x.idMatch != m.idMatch).toList(),
      );
    }
  }

  Future<void> _abrirChat(MatchItem m) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => PantallaMatchChat(match: m)),
    );
    _cargar(); // refrescar último mensaje al volver
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: ColoresApp.principalMarca,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Text(
          'Mis matches 💜',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
      ),
      child: SafeArea(
        child: _cargando
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : RefreshIndicator(
                onRefresh: _cargar,
                child: Builder(
                  builder: (_) {
                    // Pendientes (likes entrantes) = miniaturas arriba.
                    // Matches aceptados = lista de chats.
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                      children: [
                        if (_pendientes.isNotEmpty) _tiraPendientes(_pendientes),
                        _filaBienvenida(),
                        ..._matches.map(_fila),
                        if (_matches.isEmpty && _pendientes.isEmpty)
                          _sinMatches(),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  /// Tira horizontal de likes entrantes pendientes de aceptar.
  Widget _tiraPendientes(List<MatchPendiente> pendientes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            pendientes.length == 1
                ? '1 pendiente · tocá para matchear'
                : '${pendientes.length} pendientes · tocá para matchear',
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoSecundario,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pendientes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _miniaturaPendiente(pendientes[i]),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _miniaturaPendiente(MatchPendiente p) {
    final foto = p.otro.fotoUrl;
    final recopa = p.esRecopa;
    return GestureDetector(
      onTap: () => _abrirTarjetaPendiente(p),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: recopa ? _kAzulRePinta : ColoresApp.principalMarca,
                  width: 2.4,
                ),
                boxShadow: recopa
                    ? [
                        BoxShadow(
                          color: _kAzulRePinta.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Container(
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
                        p.otro.esSquad ? '👥' : '🙋',
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              p.otro.nombre.split(RegExp(r'\s+')).first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirTarjetaPendiente(MatchPendiente p) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'pendiente',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, _) {
        final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.88 + 0.12 * curva.value.clamp(0.0, 1.0),
            child: _TarjetaMatchPendiente(
              pendiente: p,
              onMatchear: () {
                Navigator.pop(ctx);
                _matchearYChatear(p);
              },
              onVerPerfil: () {
                Navigator.pop(ctx);
                _verPerfilPendiente(p);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _verPerfilPendiente(MatchPendiente p) async {
    final otro = p.otro;
    if (otro.esSquad) {
      if (otro.idGrupo == null) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => PantallaPerfilSquads(
            squad: {
              'id_grupo': otro.idGrupo,
              'nombre_grupo': otro.nombre,
              'url_portada': otro.fotoPath,
            },
            estadoRelacion: EstadoRelacionSquad.ninguno,
          ),
        ),
      );
    } else {
      if (otro.idUsuario == null) return;
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => PantallaPerfilUsuarios(
            usuario: {
              'id_usuario': otro.idUsuario,
              'username': otro.username,
              'perfil_publico': otro.perfilPublico,
              if (otro.fotoUrl != null) 'avatar': otro.fotoUrl,
            },
            estadoRelacion: EstadoRelacionUsuario.ninguno,
          ),
        ),
      );
    }
  }

  Future<void> _matchearYChatear(MatchPendiente p) async {
    try {
      final idMatch = await _srv.aceptarInteres(p.idPlanOrigen);
      if (!mounted) return;
      if (idMatch == null || idMatch.isEmpty) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('No se pudo matchear'),
            content: const Text('Probá de nuevo en un momento.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      final match = MatchItem(
        idMatch: idMatch,
        tipo: p.tipo,
        otro: p.otro,
        planPrincipal: p.planPrincipal ?? p.miPlan,
        miPlan: p.miPlan,
        otroTeRecopo: p.esRecopa,
        sinChat: true,
      );
      setState(() {
        _pendientes =
            _pendientes.where((x) => x.idPlanOrigen != p.idPlanOrigen).toList();
        _matches = [match, ..._matches.where((m) => m.idMatch != idMatch)];
      });
      await _abrirChat(match);
      _cargar();
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('No se pudo matchear'),
          content: Text(
            e.toString().contains('sin_interes')
                ? 'Ese interés ya no está disponible.'
                : 'Probá de nuevo en un momento.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _cargar();
    }
  }

  Widget _sinMatches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Column(
        children: [
          const Text('💌', style: TextStyle(fontSize: 42)),
          const SizedBox(height: 10),
          Text(
            'Todavía no hay matches',
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoPrincipal,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Cuando a alguien le pintó tu plan, aparece arriba. Tocá el avatar, matcheá y chateá.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoSecundario,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Chat demo fijo de Fernecito: explica cómo funcionan los matches.
  Widget _filaBienvenida() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const _PantallaChatBienvenida()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.principalMarca,
                border: Border.all(
                  color: AvatarBordes.blanco,
                  width: AvatarBordes.ancho(),
                ),
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fernecito',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    '¡Bienvenido a Matchs! Tocá para saber cómo funciona 💜',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 17,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(MatchItem m) {
    final foto = m.otro.fotoUrl;
    return GestureDetector(
      onTap: () => _abrirChat(m),
      onLongPress: () => _menuFila(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // Avatar
            AvatarUsuario(
              avatar: foto ?? '',
              size: 54,
              borderColor: AvatarBordes.blanco,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match con ${m.otro.nombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    m.planResumen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: const Color(0xFFB79CF0),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  if (m.ultimoMensaje != null)
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          if (m.ultimoMensajeAutor == _srv.miUid)
                            TextSpan(
                              text: 'Vos: ',
                              style: GoogleFonts.baloo2(
                                color: _kAzulRePinta,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          TextSpan(
                            text: m.ultimoMensaje,
                            style: GoogleFonts.baloo2(
                              // No leídos → más blanco y en negrita.
                              color: m.noLeidos > 0
                                  ? ColoresApp.textoPrincipal
                                  : ColoresApp.textoSecundario,
                              fontWeight: m.noLeidos > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '¡Rompé el hielo! 🧊',
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.textoSecundario,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Globo con la cantidad de mensajes sin leer
            if (m.noLeidos > 0)
              Container(
                margin: const EdgeInsets.only(right: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  m.noLeidos > 9 ? '9+' : '${m.noLeidos}',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: () => _menuFila(m),
              child: const Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat de bienvenida (solo lectura): explica Matchs con onda + seguridad.
class _PantallaChatBienvenida extends StatelessWidget {
  const _PantallaChatBienvenida();

  static const _mensajes = [
    '¡Hola! 👋 Bienvenido a Matchs 💜\n\nAcá van a aparecer las personas y squads con los que matcheás para salir.',
    '¿Cómo funciona?\n\n1) Armás tu plan (qué querés hacer, cuándo y dónde).\n2) Deslizás planes de otros.\n3) Si a alguien le pintó TU plan, te aparece arriba como pendiente.',
    'Cuando te llega un pendiente, tocás el avatar, ves su card y si te cierra: "Matchear y chatear" 💜\n\nSi le re pintó tu plan, el avatar viene en azul 🥂',
    'Un consejito de seguridad 🛡️\n\nJuntate siempre en lugares públicos, avisale a alguien de confianza a dónde vas, y si algo no te cierra, confiá en tu instinto. Podés bloquear a cualquiera desde el chat.',
    '¡Eso es todo! Armá tu plan y a deslizar 🔥',
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: ColoresApp.principalMarca,
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.principalMarca,
                border: Border.all(
                  color: AvatarBordes.blanco,
                  width: 1.4,
                ),
              ),
              child: const Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Fernecito',
              style: GoogleFonts.baloo2(
                fontWeight: FontWeight.w900,
                color: ColoresApp.textoPrincipal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          itemCount: _mensajes.length,
          itemBuilder: (context, i) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.82,
              ),
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: ColoresApp.fondoSuperficie,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(i == _mensajes.length - 1 ? 5 : 17),
                  bottomRight: const Radius.circular(17),
                ),
              ),
              child: Text(
                _mensajes[i],
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoPrincipal,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card grande de un like entrante pendiente: foto, nombre, plan propio
/// que le copó + "Matchear y chatear".
class _TarjetaMatchPendiente extends StatelessWidget {
  const _TarjetaMatchPendiente({
    required this.pendiente,
    required this.onMatchear,
    required this.onVerPerfil,
  });

  final MatchPendiente pendiente;
  final VoidCallback onMatchear;
  final VoidCallback onVerPerfil;

  String get _genero => switch (pendiente.otro.sexo) {
    'hombre' => 'Hombre',
    'mujer' => 'Mujer',
    'otro' => 'Otrx',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final otro = pendiente.otro;
    final foto = otro.fotoUrl;
    final ancho = MediaQuery.sizeOf(context).width * 0.86;
    final recopa = pendiente.esRecopa;
    final plan = pendiente.planPrincipal ?? pendiente.miPlan;
    final subtitulos = [
      if (otro.edad != null) '${otro.edad} años',
      if (_genero.isNotEmpty) _genero,
      if (otro.esSquad && otro.miembros != null) '${otro.miembros} personas',
    ].join(' · ');

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: ancho,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: MediaQuery.sizeOf(context).height * 0.42,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(26),
                  border: recopa
                      ? Border.all(color: _kAzulRePinta, width: 2.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: (recopa ? _kAzulRePinta : Colors.black)
                          .withValues(alpha: recopa ? 0.45 : 0.5),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (foto != null)
                      Image.network(
                        foto,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _ph(),
                      )
                    else
                      _ph(),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.55, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (recopa)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _kAzulRePinta,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '🥂 ¡Le re pinta tu plan!',
                            style: GoogleFonts.baloo2(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otro.nombre.split(RegExp(r'\s+')).first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                          if (subtitulos.isNotEmpty)
                            Text(
                              subtitulos,
                              style: GoogleFonts.baloo2(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recopa
                          ? 'Le re pintó tu propuesta de'
                          : 'Le pintó tu propuesta de',
                      style: GoogleFonts.baloo2(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan == null
                          ? 'tu plan'
                          : '${plan.planEtiqueta} en ${plan.lugarTexto}',
                      style: GoogleFonts.baloo2(
                        color: const Color(0xFF16161A),
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: recopa ? _kAzulRePinta : ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 46),
                  onPressed: onMatchear,
                  child: Text(
                    'Matchear y chatear 💬',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              CupertinoButton(
                onPressed: onVerPerfil,
                child: Text(
                  otro.esSquad ? 'Ver squad' : 'Ver perfil',
                  style: GoogleFonts.baloo2(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ph() => Container(
    color: const Color(0xFF2A2A2A),
    alignment: Alignment.center,
    child: Text(
      pendiente.otro.esSquad ? '👥' : '🙋',
      style: const TextStyle(fontSize: 64),
    ),
  );
}
