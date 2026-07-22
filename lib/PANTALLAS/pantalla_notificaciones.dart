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
import '../core/servicio_notificaciones_usuarios.dart';
import '../core/servicio_push.dart';
import '../core/navegacion_notificaciones.dart';
import '../core/squad_helpers.dart';
import '../models/notificacion.dart';
import '../widgets/fernecito_loader.dart';

class PantallaNotificaciones extends StatefulWidget {
  /// Se incrementa desde el Home al entrar al tab Novedades para forzar recarga
  /// (IndexedStack mantiene viva esta pantalla y no la recrea).
  final int reloadTick;

  /// Cambia tab del home (actividad / social / cartelera) sin apilar rutas duplicadas.
  final NotifIrATab? onIrATab;

  const PantallaNotificaciones({super.key, this.reloadTick = 0, this.onIrATab});

  @override
  State<PantallaNotificaciones> createState() => _PantallaNotificacionesState();
}

class _PantallaNotificacionesState extends State<PantallaNotificaciones> {
  final _servicio = ServicioNotificacionesUsuarios();
  List<Notificacion> _notifs = const [];
  bool _cargando = true;
  String? _error;
  String? _accionProcesandoId;
  bool _pushRevisado = false;
  bool _pushPermitido = false;
  bool _pushActivando = false;

  @override
  void initState() {
    super.initState();
    if (_servicio.tieneCache) {
      _notifs = List<Notificacion>.from(_servicio.cache);
      _cargando = false;
    }
    _revisarPush();
    _cargar();
  }

  @override
  void didUpdateWidget(PantallaNotificaciones oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick && widget.reloadTick > 0) {
      _cargar();
    }
  }

  Future<void> _cargar({bool forzarCompleto = false}) async {
    if (!mounted) return;
    final desdeCache = _servicio.tieneCache;
    setState(() {
      _cargando = !desdeCache;
      _error = null;
      if (desdeCache) _notifs = List<Notificacion>.from(_servicio.cache);
    });
    try {
      final lista = await _servicio.sincronizar(forzarCompleto: forzarCompleto);
      if (!mounted) return;
      setState(() {
        _notifs = List<Notificacion>.from(lista);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!desdeCache) {
          _error = 'No se pudieron cargar las notificaciones.';
        }
        _cargando = false;
      });
    }
  }

  Future<void> _marcarLeida(Notificacion n) async {
    if (n.leida) return;
    final ahora = DateTime.now().toUtc();
    setState(() {
      _notifs = _notifs
          .map(
            (x) =>
                x.id == n.id ? n.copyWith(leida: true, fechaLectura: ahora) : x,
          )
          .toList();
    });
    final ok = await _servicio.marcarLeida(n.id);
    if (!ok && mounted) {
      setState(() {
        _notifs = _notifs.map((x) => x.id == n.id ? n : x).toList();
      });
      _servicio.sincronizarDesdeLista(_notifs);
    }
  }

  Future<void> _marcarTodas() async {
    if (_notifs.every((n) => n.leida)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _notifs = _notifs
          .map(
            (n) => n.leida
                ? n
                : n.copyWith(leida: true, fechaLectura: DateTime.now().toUtc()),
          )
          .toList();
    });
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

  Future<void> _navegar(Notificacion n) async {
    try {
      final abierta = await navegarDesdeNotificacion(
        n,
        onIrATab: widget.onIrATab,
      );
      if (!mounted) return;
      if (abierta) {
        await _marcarLeida(n);
      } else {
        _mostrarError('No se pudo abrir esta novedad.');
      }
    } catch (e) {
      debugPrint('⚠️ navegar notif ${n.tipo}: $e');
      _mostrarError('No se pudo abrir esta novedad.');
    }
  }

  Future<void> _accionCta(Notificacion n) async {
    if (_accionProcesandoId != null) return;
    setState(() => _accionProcesandoId = n.id);
    try {
      switch (n.tipo) {
        case 'solicitud_amistad':
          final ok = await aceptarAmistadDesdeNotificacion(n);
          if (!ok && mounted) {
            _mostrarError('No se pudo aceptar la solicitud.');
          } else if (mounted) {
            await _marcarLeida(n);
            await _cargar();
          }
          break;
        case 'solicitud_squad':
          if (notifEsInvitacionSquad(n)) {
            final ok = await aceptarInvitacionSquadDesdeNotificacion(n);
            if (!ok && mounted) {
              _mostrarError('No se pudo aceptar la invitación al squad.');
            } else if (mounted) {
              await _marcarLeida(n);
              await _cargar();
            }
          } else {
            await _navegar(n);
          }
          break;
        default:
          await _navegar(n);
      }
    } finally {
      if (mounted) setState(() => _accionProcesandoId = null);
    }
  }

  int get _sinLeer => _notifs.where((n) => !n.leida).length;

  Future<void> _revisarPush() async {
    final permitido = await ServicioPush.instancia.tienePermiso();
    if (!mounted) return;
    setState(() {
      _pushPermitido = permitido;
      _pushRevisado = true;
    });
  }

  Future<void> _activarPush() async {
    if (_pushActivando) return;
    HapticFeedback.lightImpact();
    setState(() => _pushActivando = true);
    final ok = await ServicioPush.instancia.registrarParaUsuario();
    if (!mounted) return;
    setState(() {
      _pushPermitido = ok;
      _pushRevisado = true;
      _pushActivando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, _, _) {
        return CupertinoPageScaffold(
          backgroundColor: ColoresApp.fondoPrincipal,
          child: FernecitoRefreshScrollView(
            onRefresh: () => _cargar(forzarCompleto: true),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(padding)),
              if (_cargando)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: FernecitoLoaderCentro(size: 34),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (_notifs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
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
        );
      },
    );
  }

  Widget _buildHeader(EdgeInsets padding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, padding.top + 8, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.bell_fill,
                size: 26,
                color: ColoresApp.principalMarca,
              ),
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
              if (_pushRevisado &&
                  !_pushPermitido &&
                  ServicioPush.instancia.soportado) ...[
                const SizedBox(width: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  onPressed: _pushActivando ? null : _activarPush,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _pushActivando
                        ? const CupertinoActivityIndicator(radius: 9)
                        : Icon(
                            CupertinoIcons.bell,
                            color: ColoresApp.principalMarca,
                            size: 24,
                          ),
                  ),
                ),
              ],
            ],
          ),
          if (_sinLeer > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
            Icon(
              CupertinoIcons.bell,
              size: 56,
              color: ColoresApp.principalMarca.withValues(alpha: 0.35),
            ),
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
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 56,
              color: Colors.red.shade300,
            ),
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
              child: Text(
                'Reintentar',
                style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
              ),
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
    case 'lista_aceptada':
      return 'Ver evento';
    case 'pase_canjeado':
      return 'Ver actividad';
    case 'recordatorio_evento':
      return 'Ver evento';
    case 'rompehielo_recibido':
    case 'rompehielo_respondido':
    case 'rompehielo_replicado':
      return 'Ver mensaje';
  }
  return n.ctaTexto ?? 'Ver';
}

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
          color: leida
              ? ColoresApp.fondoSuperficie
              : Color.lerp(
                  ColoresApp.fondoSuperficie,
                  colorAccent.withValues(alpha: 0.14),
                  0.55,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: leida ? 0.12 : 0.18),
              blurRadius: leida ? 6 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  notif.icono,
                  color: leida ? ColoresApp.textoSecundario : colorAccent,
                  size: 22,
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
                              fontWeight: leida
                                  ? FontWeight.w600
                                  : FontWeight.w900,
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
                            color: ColoresApp.textoSecundario.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          onPressed: procesando ? null : onBoton,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: leida
                                  ? ColoresApp.fondoPrincipal
                                  : colorAccent,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: procesando
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: FernecitoLoader.inline(
                                      size: 14,
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
