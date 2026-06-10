/// Pantalla Notificaciones — Mis novedades Fernecito.
/// Lee de `notificaciones_usuarios` (Supabase) vía ServicioNotificacionesUsuarios.
/// Estética heredada de la app de locales (cards/botones), pero con los colores
/// dinámicos del tema del usuario (TemaFernecito.colorActual).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/tema_fernecito.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/servicio_notificaciones_usuarios.dart';
import '../core/rompehielo_navegacion.dart';
import '../core/servicio_rompehielo.dart';
import '../core/servicio_squads.dart';
import '../core/squad_helpers.dart';
import '../core/supabase_client.dart';
import '../models/notificacion.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import 'pantalla_social.dart';
import 'pantalla_actividad.dart';
import 'pantalla_mis_squads.dart';
import 'pantalla_perfil_squads.dart';
import 'pantalla_perfil_usuarios.dart';
import 'pantalla_rompehielo.dart' show TipoContraparte;

class PantallaNotificaciones extends StatefulWidget {
  /// Se incrementa desde el Home al entrar al tab Novedades para forzar recarga
  /// (IndexedStack mantiene viva esta pantalla y no la recrea).
  final int reloadTick;

  /// 0 = Amigos, 1 = Squads. Si viene del Home, cambia el tab Social sin apilar rutas.
  final void Function(int socialTabIndex)? onIrATabSocial;

  const PantallaNotificaciones({
    super.key,
    this.reloadTick = 0,
    this.onIrATabSocial,
  });

  @override
  State<PantallaNotificaciones> createState() => _PantallaNotificacionesState();
}

class _PantallaNotificacionesState extends State<PantallaNotificaciones> {
  final _servicio = ServicioNotificacionesUsuarios();
  final _srvAmigos = ServicioAmigos();
  final _srvPerfil = ServicioPerfilUsuario();
  final _srvSquads = ServicioSquads();
  List<Notificacion> _notifs = const [];
  bool _cargando = true;
  String? _error;
  String? _accionProcesandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(PantallaNotificaciones oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick && widget.reloadTick > 0) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _servicio.listar();
      await _servicio.refrescarContador();
      if (!mounted) return;
      setState(() {
        _notifs = lista;
        _cargando = false;
      });
      _servicio.sincronizarDesdeLista(lista);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las notificaciones.';
        _cargando = false;
      });
    }
  }

  Future<void> _marcarLeida(Notificacion n) async {
    if (n.leida) return;
    setState(() {
      final idx = _notifs.indexWhere((x) => x.id == n.id);
      if (idx >= 0) {
        _notifs[idx] = n.copyWith(leida: true, fechaLectura: DateTime.now().toUtc());
      }
    });
    _servicio.sincronizarDesdeLista(_notifs);
    final ok = await _servicio.marcarLeida(n.id);
    if (!ok && mounted) {
      setState(() {
        final idx = _notifs.indexWhere((x) => x.id == n.id);
        if (idx >= 0) _notifs[idx] = n;
      });
      _servicio.sincronizarDesdeLista(_notifs);
    }
  }

  Future<void> _marcarTodas() async {
    if (_notifs.every((n) => n.leida)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _notifs = _notifs.map((n) => n.copyWith(leida: true)).toList();
    });
    _servicio.contadorNoLeidas.value = 0;
    await _servicio.marcarTodasLeidas();
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
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

  Future<void> _irASocial(int tabIndex) async {
    final tab = tabIndex.clamp(0, 1);
    if (widget.onIrATabSocial != null) {
      widget.onIrATabSocial!(tab);
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaSocial(initialTabIndex: tab),
      ),
    );
  }

  Future<void> _navegar(Notificacion n) async {
    await _marcarLeida(n);
    if (!mounted) return;
    switch (n.tipo) {
      case 'solicitud_amistad':
        final idEmisor = n.ctaIdRef;
        if (idEmisor != null && idEmisor.isNotEmpty) {
          final det = await _srvPerfil.detalle(idEmisor);
          if (!mounted) return;
          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => PantallaPerfilUsuarios(
                usuario: {
                  'id_usuario': idEmisor,
                  'perfil_publico': det?['perfil_publico'] == true,
                  if (det?['foto_perfil_url'] != null)
                    'avatar': ServicioSupabase()
                        .urlAvatar(det!['foto_perfil_url']?.toString()),
                  'username': det?['username'],
                },
                estadoRelacion: EstadoRelacionUsuario.solicitudRecibida,
              ),
            ),
          );
        } else {
          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => const PantallaSocial(initialTabIndex: 0),
            ),
          );
        }
        break;
      case 'amistad_aceptada':
        await _irASocial(0);
        break;
      case 'solicitud_squad':
        await _abrirSquadDesdeNotif(n);
        break;
      case 'squad_aceptada':
        await _irASocial(1);
        break;
      case 'cuenta_pausada':
      case 'cuenta_reactivada':
        break;
      case 'rompehielo_recibido':
      case 'rompehielo_respondido':
      case 'rompehielo_replicado':
        await _abrirRompehieloDesdeNotif(n);
        break;
      default:
        await Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const PantallaActividad()),
        );
    }
  }

  Future<void> _abrirRompehieloDesdeNotif(Notificacion n) async {
    final payload = n.payload;
    final otroTipo = payload?['lado_otro_tipo'] as String?;
    final otroId = payload?['lado_otro_id']?.toString();
    if (otroTipo == null || otroId == null || otroId.isEmpty) {
      _mostrarError('No se pudo abrir el rompehielo.');
      return;
    }
    var idGrupoActor = payload?['id_grupo']?.toString();
    final srv = ServicioRompehielo();
    final estado = await srv.estado(
      otroTipo: otroTipo,
      otroId: otroId,
      idGrupoActor: idGrupoActor,
    );
    if (!mounted) return;

    idGrupoActor ??= estado.idGrupoActorMio;

    Map<String, dynamic> contraparte;
    TipoContraparte tipo;
    if (otroTipo == 'usuario') {
      tipo = TipoContraparte.usuario;
      final det = await _srvPerfil.detalle(otroId);
      if (!mounted) return;
      contraparte = {
        'id_usuario': otroId,
        'username': det?['username'] ?? '@usuario',
        'avatar': ServicioSupabase().urlAvatar(det?['foto_perfil_url']?.toString()),
      };
    } else {
      tipo = TipoContraparte.squad;
      final det = await _srvSquads.detalle(otroId);
      if (!mounted) return;
      if (det == null) {
        _mostrarError('No se pudo abrir el squad.');
        return;
      }
      contraparte = mapNavegacionDesdeDetalle(det);
    }

    Map<String, dynamic>? squadActor;
    if (idGrupoActor != null && idGrupoActor.isNotEmpty) {
      final detSquad = await _srvSquads.detalle(idGrupoActor);
      if (detSquad != null) {
        squadActor = mapNavegacionDesdeDetalle(detSquad);
      }
    }

    if (!mounted) return;
    await abrirRompehieloDesdeNotificacion(
      context,
      tipoContraparte: tipo,
      contraparte: contraparte,
      estadoInicial: estado,
      idGrupoActor: idGrupoActor,
      squadActor: squadActor,
    );
  }

  Future<void> _abrirSquadDesdeNotif(Notificacion n) async {
    final idGrupo = n.ctaIdRef;
    if (idGrupo == null || idGrupo.isEmpty) {
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => const PantallaSocial(initialTabIndex: 1)),
      );
      return;
    }
    final det = await _srvSquads.detalle(idGrupo);
    if (!mounted) return;
    if (det == null) {
      _mostrarError('No se pudo abrir el squad.');
      return;
    }
    final map = mapNavegacionDesdeDetalle(det);
    if (notifEsPedidoUnionSquad(n) &&
        det.puedeAdministrar(ServicioSupabase().usuarioActual?.id)) {
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => PantallaMisSquads(squad: map)),
      );
      return;
    }
    final estado = det.miEstado == 'pendiente'
        ? EstadoRelacionSquad.solicitudPendiente
        : (det.miEstado == 'aceptado'
            ? EstadoRelacionSquad.miembro
            : EstadoRelacionSquad.ninguno);
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilSquads(
          squad: map,
          estadoRelacion: estado,
        ),
      ),
    );
  }

  Future<void> _accionCta(Notificacion n) async {
    if (_accionProcesandoId != null) return;
    setState(() => _accionProcesandoId = n.id);
    try {
      await _marcarLeida(n);
      switch (n.tipo) {
        case 'solicitud_amistad':
          await _aceptarAmistadDesdeNotif(n);
          break;
        case 'solicitud_squad':
          if (notifEsInvitacionSquad(n)) {
            await _aceptarInvitacionSquadDesdeNotif(n);
          } else {
            await _abrirSquadDesdeNotif(n);
          }
          break;
        default:
          await _navegar(n);
      }
    } finally {
      if (mounted) setState(() => _accionProcesandoId = null);
    }
  }

  Future<void> _aceptarAmistadDesdeNotif(Notificacion n) async {
    final idEmisor = n.ctaIdRef;
    if (idEmisor == null || idEmisor.isEmpty) {
      await _navegar(n);
      return;
    }
    var ok = false;
    final data = await _srvAmigos.listar();
    final recibida =
        data.recibidas.where((a) => a.idUsuario == idEmisor).toList();
    if (recibida.isNotEmpty) {
      final rel = recibida.first.idRelacion?.toString();
      if (rel != null && rel.isNotEmpty) {
        ok = await _srvAmigos.responder(rel, aceptar: true);
      }
    }
    if (!ok) {
      final estado = await _srvAmigos.solicitar(idEmisor);
      ok = estado == 'aceptada' || estado == 'aceptado';
    }
    if (!mounted) return;
    if (ok) {
      await _cargar();
      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => PantallaPerfilUsuarios(
            usuario: {
              'id_usuario': idEmisor,
              'perfil_publico': false,
            },
            estadoRelacion: EstadoRelacionUsuario.amigo,
          ),
        ),
      );
    } else {
      _mostrarError('No se pudo aceptar la solicitud.');
    }
  }

  Future<void> _aceptarInvitacionSquadDesdeNotif(Notificacion n) async {
    final idGrupo = n.ctaIdRef;
    if (idGrupo == null || idGrupo.isEmpty) {
      await _navegar(n);
      return;
    }
    final ok = await _srvSquads.responderInvitacion(idGrupo, aceptar: true);
    if (!mounted) return;
    if (ok) {
      await _cargar();
    } else {
      _mostrarError('No se pudo aceptar la invitación al squad.');
      await _abrirSquadDesdeNotif(n);
    }
  }

  int get _sinLeer => _notifs.where((n) => !n.leida).length;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    // Reconstruye al cambiar el color del tema del usuario.
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, _, _) {
        return CupertinoPageScaffold(
          backgroundColor: ColoresApp.fondoPrincipal,
          child: FondoGradienteFernecito(
            corto: true,
            child: RefreshIndicator(
              color: ColoresApp.principalMarca,
              backgroundColor: ColoresApp.fondoSuperficie,
              onRefresh: _cargar,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(padding)),
                  if (_cargando)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: ColoresApp.principalMarca,
                        ),
                      ),
                    )
                  else if (_error != null)
                    SliverFillRemaining(hasScrollBody: false, child: _buildErrorState())
                  else if (_notifs.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, padding.bottom + 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CardNotif(
                              notif: _notifs[i],
                              procesando: _accionProcesandoId == _notifs[i].id,
                              onTap: () => _navegar(_notifs[i]),
                              onBoton: () => _accionCta(_notifs[i]),
                            ),
                          ),
                          childCount: _notifs.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(EdgeInsets padding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, padding.top + 16, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.bell_fill, size: 26, color: ColoresApp.principalMarca),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mis novedades',
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ),
              if (_sinLeer > 0)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  onPressed: _marcarTodas,
                  child: Icon(
                    CupertinoIcons.checkmark_alt_circle,
                    color: ColoresApp.principalMarca,
                    size: 24,
                  ),
                ),
            ],
          ),
          if (_sinLeer > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ColoresApp.principalMarca.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '$_sinLeer sin leer',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.bell, size: 56,
                color: ColoresApp.principalMarca.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              'No tenés novedades',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Acá vas a ver tus listas, pases, promos y recordatorios de eventos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Error al cargar',
              textAlign: TextAlign.center,
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              color: ColoresApp.principalMarca,
              borderRadius: BorderRadius.circular(50),
              onPressed: _cargar,
              child: Text('Reintentar', style: GoogleFonts.baloo2(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

String _textoBotonCta(Notificacion n) {
  switch (n.tipo) {
    case 'solicitud_amistad':
      return 'Aceptar';
    case 'amistad_aceptada':
      return 'Ver amigos';
    case 'squad_aceptada':
      return 'Ver squads';
    case 'solicitud_squad':
      if (notifEsInvitacionSquad(n)) return 'Aceptar';
      if (notifEsPedidoUnionSquad(n)) return 'Ver squad';
      break;
    case 'rompehielo_recibido':
    case 'rompehielo_respondido':
    case 'rompehielo_replicado':
      return 'Ver mensaje';
  }
  return n.ctaTexto ?? 'Ver';
}

// ─── Card de notificación (estética app locales, colores del tema) ─────────────

class _CardNotif extends StatelessWidget {
  final Notificacion notif;
  final bool procesando;
  final VoidCallback onTap;
  final VoidCallback onBoton;

  const _CardNotif({
    required this.notif,
    this.procesando = false,
    required this.onTap,
    required this.onBoton,
  });

  // Todas las notificaciones se acoplan al color del tema activo de la app.
  // El estado leído/no leído se diferencia con la opacidad/gris en el build.
  Color _colorAccent() => ColoresApp.principalMarca;

  @override
  Widget build(BuildContext context) {
    final leida = notif.leida;
    final colorAccent = _colorAccent();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColoresApp.fondoSuperficie.withValues(alpha: 0.95),
              Color.lerp(
                ColoresApp.fondoSuperficie,
                colorAccent.withValues(alpha: 0.14),
                leida ? 0.10 : 0.30,
              )!,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: leida
                ? colorAccent.withValues(alpha: 0.10)
                : colorAccent.withValues(alpha: 0.40),
            width: leida ? 1 : 1.5,
          ),
          boxShadow: leida
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorAccent.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: leida
                      ? colorAccent.withValues(alpha: 0.10)
                      : colorAccent.withValues(alpha: 0.18),
                ),
                child: Icon(
                  notif.icono,
                  color: leida ? ColoresApp.textoSecundario : colorAccent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.titulo,
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              fontWeight: leida ? FontWeight.w600 : FontWeight.w900,
                              color: leida
                                  ? ColoresApp.textoSecundario
                                  : ColoresApp.textoPrincipal,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!leida) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: colorAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.descripcion,
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ColoresApp.textoSecundario,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          notif.fechaRelativa,
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            color: ColoresApp.textoSecundario.withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        if (notif.ctaTexto != null && notif.ctaTexto!.isNotEmpty)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            onPressed: procesando ? null : onBoton,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: leida ? Colors.transparent : colorAccent,
                                borderRadius: BorderRadius.circular(50),
                                border: leida
                                    ? Border.all(color: colorAccent.withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: procesando
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: leida
                                            ? ColoresApp.textoSecundario
                                            : Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _textoBotonCta(notif),
                                      style: GoogleFonts.baloo2(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: leida
                                            ? ColoresApp.textoSecundario
                                            : Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                      ],
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
}
