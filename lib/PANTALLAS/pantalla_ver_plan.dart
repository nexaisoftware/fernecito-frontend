library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_planes.dart';
import '../widgets/fernecito_loader.dart';
import 'pantalla_chat_plan.dart';
import 'pantalla_local_perfil.dart';

class PantallaVerPlan extends StatefulWidget {
  const PantallaVerPlan({super.key, required this.idPlan, this.inicial});
  final String idPlan;
  final PlanComunidad? inicial;

  @override
  State<PantallaVerPlan> createState() => _PantallaVerPlanState();
}

class _PantallaVerPlanState extends State<PantallaVerPlan> {
  final _srv = ServicioPlanes();
  PlanDetalle? _detalle;
  bool _cargando = true;
  bool _uniendo = false;
  bool _changed = false;
  String? _error;

  PlanComunidad? get _plan => _detalle?.plan ?? widget.inicial;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final res = await _srv.detalle(widget.idPlan);
    if (!mounted) return;
    setState(() {
      _detalle = res.detalle;
      _error = res.detalle == null
          ? (res.error ?? 'Este plan ya no está disponible.')
          : null;
      _cargando = false;
    });
  }

  Future<void> _unirse() async {
    final plan = _plan;
    if (plan == null || !plan.puedeUnirse) return;
    String? idSquad;
    if (plan.permiteSquads) {
      idSquad = await _elegirIdentidadUnion(plan);
      if (idSquad == '__cancel__') return;
    }
    setState(() => _uniendo = true);
    try {
      final estado = await _srv.solicitarUnirse(
        plan.id,
        idSquad: idSquad?.isEmpty == true ? null : idSquad,
      );
      _changed = true;
      if (!mounted) return;
      if (estado == null) {
        _toast('No se pudo sumarte. Probá de nuevo.');
      } else {
        await _cargar();
        _toast(
          estado == 'aceptado'
              ? '¡Adentro! Ya podés chatear.'
              : 'Pedido enviado.',
        );
      }
    } catch (e) {
      if (mounted) _toast(_srv.mensajeError(e, accion: 'sumarte'));
    } finally {
      if (mounted) setState(() => _uniendo = false);
    }
  }

  Future<String?> _elegirIdentidadUnion(PlanComunidad plan) async {
    final squads = await _srv.misSquads();
    if (!mounted) return '__cancel__';
    final accion = plan.modoLista == 'manual' ? 'solicitar' : 'unirte';
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.paddingOf(ctx).bottom + 12,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                plan.modoLista == 'manual'
                    ? '¿Cómo querés solicitar unirte?'
                    : '¿Cómo te sumás?',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 10),
              _OpcionUnion(
                titulo: plan.modoLista == 'manual'
                    ? 'Solicitar solo'
                    : 'Voy solo',
                subtitulo: 'Vas a $accion con tu perfil.',
                icono: CupertinoIcons.person_fill,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final s in squads)
                _OpcionUnion(
                  titulo: plan.modoLista == 'manual'
                      ? 'Solicitar con ${s.nombre}'
                      : 'Ir con ${s.nombre}',
                  subtitulo:
                      '$accion con ${s.cantidadMiembros} miembros del squad',
                  icono: CupertinoIcons.person_3_fill,
                  onTap: () => Navigator.pop(ctx, s.idGrupo),
                ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(ctx, '__cancel__'),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.baloo2(color: ColoresApp.textoSecundario),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _gestionar(PlanMiembro miembro, String accion) async {
    final plan = _plan;
    if (plan == null) return;
    try {
      final ok = await _srv.gestionarMiembro(
        idPlan: plan.id,
        idUsuario: miembro.idUsuario,
        accion: accion,
      );
      if (!mounted) return;
      if (!ok) {
        _toast('No se pudo actualizar la solicitud.');
        return;
      }
      _changed = true;
      await _cargar();
    } catch (e) {
      if (mounted) {
        _toast(_srv.mensajeError(e, accion: 'gestionar la solicitud'));
      }
    }
  }

  Future<void> _cancelar() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cancelar plan'),
        content: const Text(
          'Se mostrará como cancelado y se avisará en el chat.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar plan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final plan = _plan;
    if (plan == null) return;
    final res = await _srv.cancelar(plan.id);
    if (res) {
      _changed = true;
      await _cargar();
    }
  }

  void _toast(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null) {
      if (_cargando) {
        return const CupertinoPageScaffold(
          backgroundColor: ColoresApp.fondoPrincipal,
          child: Center(child: FernecitoLoader.inline(size: 28)),
        );
      }
      return CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.transparent,
          border: null,
          leading: CupertinoNavigationBarBackButton(
            color: ColoresApp.principalMarca,
            onPressed: () => Navigator.pop(context, _changed),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'Este plan ya no está disponible.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 14),
                CupertinoButton(
                  color: ColoresApp.principalMarca.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: _cargar,
                  child: Text(
                    'Reintentar',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final portada = plan.portadaUrl;
    final color = _parseColor(plan.colorHex);
    final miembros = _detalle?.miembros ?? const <PlanMiembro>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  SizedBox(
                    height: 360,
                    width: double.infinity,
                    child: portada != null && portada.isNotEmpty
                        ? _FondoPlan(path: portada)
                        : ColoredBox(color: color),
                  ),
                  Container(
                    height: 380,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.52),
                          ColoresApp.fondoPrincipal,
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context, _changed),
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                          const SizedBox(height: 114),
                          Row(
                            children: [
                              _Avatar(
                                url: plan.fotoOrganizadorUrl,
                                fallback: plan.nombreOrganizador,
                              ),
                              const SizedBox(width: 8),
                              _Avatar(
                                url: plan.fotoLocalUrl,
                                fallback: plan.nombreLocal,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  plan.esPlanLocal
                                      ? 'Plan del local · ${plan.nombreLocal}'
                                      : 'Plan de ${plan.nombreOrganizador} en ${plan.nombreLocal}',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            plan.titulo,
                            style: GoogleFonts.baloo2(
                              fontSize: 34,
                              height: .92,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plan.descripcion,
                            style: GoogleFonts.baloo2(
                              fontSize: 15.5,
                              height: 1.2,
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge('${plan.personasAceptadas} personas'),
                      _Badge(_fmt(plan.fechaInicio)),
                      if (plan.fechaFin != null)
                        _Badge('fin ${_fmt(plan.fechaFin!)}'),
                      _Badge(
                        plan.modoLista == 'manual'
                            ? 'requiere aprobación'
                            : 'entrada libre',
                      ),
                      if (plan.cupoMax != null)
                        _Badge('${plan.cupoUsados}/${plan.cupoMax} cupos'),
                      if (plan.edadMinima != null)
                        _Badge('+${plan.edadMinima}'),
                    ],
                  ),
                  if ((plan.beneficioLocal ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PromoLocal(texto: plan.beneficioLocal!),
                  ],
                  if ((plan.contactoAnfitrion ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoBox(
                      titulo: 'Contacto del anfitrión',
                      texto: plan.contactoAnfitrion!,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          texto: 'Ver local',
                          secundario: true,
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => PantallaLocalPerfil(
                                avatarUrl: plan.fotoLocalUrl ?? '',
                                nombreLocal: plan.nombreLocal,
                                idLocal: plan.idLocal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          texto: plan.chatDisponible
                              ? 'Chat del plan'
                              : 'Chat bloqueado',
                          secundario: !plan.chatDisponible,
                          onTap: plan.chatDisponible
                              ? () => Navigator.of(context, rootNavigator: true)
                                    .push(
                                      CupertinoPageRoute(
                                        fullscreenDialog: true,
                                        builder: (_) =>
                                            PantallaChatPlan(plan: plan),
                                      ),
                                    )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (plan.puedeUnirse)
                    _ActionButton(
                      texto: plan.modoLista == 'manual'
                          ? 'Solicitar unirme'
                          : 'Unirme al plan',
                      cargando: _uniendo,
                      onTap: _unirse,
                    )
                  else
                    _InfoBox(
                      titulo: plan.estaFinalizado
                          ? 'Plan finalizado'
                          : plan.soyPendiente
                          ? 'Solicitud pendiente'
                          : plan.soyMiembro
                          ? 'Ya estás dentro'
                          : 'No disponible',
                      texto: plan.estaFinalizado
                          ? 'Este plan queda guardado como historial.'
                          : plan.soyMiembro
                          ? 'Podés entrar al chat y organizarte con el grupo.'
                          : 'Te avisamos cuando te acepten.',
                    ),
                  if (plan.soyModerador) ...[
                    const SizedBox(height: 10),
                    _ActionButton(
                      texto: 'Cancelar plan',
                      secundario: true,
                      danger: true,
                      onTap: _cancelar,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Participantes',
                    style: GoogleFonts.baloo2(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (miembros.isEmpty)
                    _InfoBox(
                      titulo: 'Todavía no hay gente',
                      texto: 'Sé de los primeros en sumarte.',
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 14,
                      children: miembros
                          .map(
                            (m) => _MiembroBubble(
                              m: m,
                              soyModerador: plan.soyModerador,
                              onAceptar: () => _gestionar(m, 'aceptar'),
                              onRechazar: () => _gestionar(m, 'rechazar'),
                            ),
                          )
                          .toList(),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});
  final String? url;
  final String fallback;
  @override
  Widget build(BuildContext context) {
    final ini = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
          : ColoredBox(
              color: const Color(0xFF2B2B2B),
              child: Center(
                child: Text(ini, style: const TextStyle(color: Colors.white)),
              ),
            ),
    );
  }
}

class _FondoPlan extends StatelessWidget {
  const _FondoPlan({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return CachedNetworkImage(imageUrl: path, fit: BoxFit.cover);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: GoogleFonts.baloo2(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: ColoresApp.textoSecundario,
      ),
    ),
  );
}

class _PromoLocal extends StatelessWidget {
  const _PromoLocal({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ColoresApp.principalMarca.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      'El local se puso la 10 con: $texto',
      style: GoogleFonts.baloo2(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.titulo, required this.texto});
  final String titulo;
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: ColoresApp.textoSecundario,
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.texto,
    this.onTap,
    this.secundario = false,
    this.danger = false,
    this.cargando = false,
  });
  final String texto;
  final VoidCallback? onTap;
  final bool secundario;
  final bool danger;
  final bool cargando;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 12),
    color: secundario
        ? Colors.white.withValues(alpha: 0.08)
        : (danger ? CupertinoColors.systemRed : ColoresApp.principalMarca),
    borderRadius: BorderRadius.circular(16),
    onPressed: cargando ? null : onTap,
    child: cargando
        ? const CupertinoActivityIndicator(color: Colors.white)
        : Text(
            texto,
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
  );
}

class _MiembroBubble extends StatelessWidget {
  const _MiembroBubble({
    required this.m,
    required this.soyModerador,
    required this.onAceptar,
    required this.onRechazar,
  });
  final PlanMiembro m;
  final bool soyModerador;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: m.estado == 'pendiente' && soyModerador ? 148 : 82,
    child: Column(
      children: [
        _Avatar(url: m.fotoUrl, fallback: m.nombre),
        const SizedBox(height: 5),
        Text(
          m.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (m.estado == 'pendiente')
          soyModerador
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniModerar(
                          texto: 'Aceptar',
                          color: ColoresApp.principalMarca,
                          onTap: onAceptar,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _MiniModerar(
                          texto: 'No',
                          color: CupertinoColors.systemRed,
                          onTap: onRechazar,
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  'pendiente',
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    color: const Color(0xFFF5A623),
                  ),
                ),
      ],
    ),
  );
}

class _MiniModerar extends StatelessWidget {
  const _MiniModerar({
    required this.texto,
    required this.color,
    required this.onTap,
  });
  final String texto;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _OpcionUnion extends StatelessWidget {
  const _OpcionUnion({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final String subtitulo;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icono, color: ColoresApp.principalMarca),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                Text(
                  subtitulo,
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: ColoresApp.textoSecundario,
          ),
        ],
      ),
    ),
  );
}

String _fmt(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm $hh:$mi';
}

Color _parseColor(String hex) {
  final clean = hex.replaceAll('#', '');
  return Color(int.tryParse('FF$clean', radix: 16) ?? 0xFFC084FC);
}
