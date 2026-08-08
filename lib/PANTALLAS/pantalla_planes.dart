library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_planes.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/social_ui.dart';

/// Hub scroll de Planes: juntadas de la comunidad en locales de Fernecito.
class PantallaPlanes extends StatefulWidget {
  const PantallaPlanes({super.key});

  @override
  State<PantallaPlanes> createState() => _PantallaPlanesState();
}

class _PantallaPlanesState extends State<PantallaPlanes> {
  final _srv = ServicioPlanes();
  final _scroll = ScrollController();

  List<PlanComunidad> _planes = const [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = false;
  String? _uniendoId;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    PreferenciasCartelera.instancia.cambios.addListener(_onUbicacion);
    _scroll.addListener(_onScroll);
    _cargar(reset: true);
  }

  @override
  void dispose() {
    PreferenciasCartelera.instancia.cambios.removeListener(_onUbicacion);
    _scroll.dispose();
    super.dispose();
  }

  void _onUbicacion() => _cargar(reset: true);

  void _onScroll() {
    if (!_hayMas || _cargandoMas || _cargando) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 280) {
      _cargar(reset: false);
    }
  }

  Future<void> _cargar({required bool reset}) async {
    if (reset) {
      setState(() => _cargando = true);
    } else {
      if (_cargandoMas) return;
      setState(() => _cargandoMas = true);
    }

    await PreferenciasCartelera.instancia.cargar();
    final prefs = PreferenciasCartelera.instancia;
    final offset = reset ? 0 : _planes.length;

    var res = await _srv.hub(
      ciudades: prefs.ciudadesActivas,
      provincia: prefs.provinciaActiva,
      limit: _pageSize,
      offset: offset,
    );

    // Si en la zona exacta no hay nada, ampliamos a provincia / general
    // para que el hub no quede vacío por un mismatch de nombre de ciudad.
    if (reset && res.items.isEmpty && prefs.ciudadesActivas.isNotEmpty) {
      res = await _srv.hub(
        ciudades: const {},
        provincia: prefs.provinciaActiva,
        limit: _pageSize,
        offset: 0,
      );
      if (res.items.isEmpty) {
        res = await _srv.hub(
          ciudades: const {},
          provincia: null,
          limit: _pageSize,
          offset: 0,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _planes = reset ? res.items : [..._planes, ...res.items];
      _hayMas = res.hayMas;
      _cargando = false;
      _cargandoMas = false;
    });
  }

  Future<void> _unirse(PlanComunidad plan) async {
    if (plan.soyMiembro || plan.soyPendiente || plan.cupoLleno) return;
    setState(() => _uniendoId = plan.id);
    try {
      final estado = await _srv.solicitarUnirse(plan.id);
      if (!mounted) return;
      if (estado == null) {
        _toast('No se pudo sumar. Probá de nuevo.');
        return;
      }
      setState(() {
        _planes = _planes
            .map(
              (p) => p.id == plan.id
                  ? PlanComunidad(
                      id: p.id,
                      titulo: p.titulo,
                      descripcion: p.descripcion,
                      ciudad: p.ciudad,
                      provincia: p.provincia,
                      fechaInicio: p.fechaInicio,
                      fechaFin: p.fechaFin,
                      modoLista: p.modoLista,
                      cupoMax: p.cupoMax,
                      cupoUsados: estado == 'aceptado'
                          ? p.cupoUsados + 1
                          : p.cupoUsados,
                      idLocal: p.idLocal,
                      nombreLocal: p.nombreLocal,
                      fotoLocal: p.fotoLocal,
                      idOrganizador: p.idOrganizador,
                      nombreOrganizador: p.nombreOrganizador,
                      fotoOrganizador: p.fotoOrganizador,
                      tipoOrganizador: p.tipoOrganizador,
                      idSquad: p.idSquad,
                      nombreSquad: p.nombreSquad,
                      miEstado: estado,
                    )
                  : p,
            )
            .toList(growable: false);
      });
      _toast(
        estado == 'aceptado'
            ? '¡Adentro! Ya podés chatear cuando abramos el chat.'
            : 'Pedido enviado. Te avisan si te aceptan.',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cupo_lleno')) {
        _toast('Se llenó el cupo.');
      } else if (msg.contains('bloqueado')) {
        _toast('No podés sumarte a este plan.');
      } else {
        _toast('No se pudo sumar.');
      }
    } finally {
      if (mounted) setState(() => _uniendoId = null);
    }
  }

  void _toast(String texto) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(texto),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  void _abrirDetalle(PlanComunidad plan) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _DetallePlanSheet(
        plan: plan,
        uniendo: _uniendoId == plan.id,
        onUnirse: () {
          Navigator.pop(ctx);
          _unirse(plan);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferenciasCartelera.instancia;
    final zona = prefs.ciudadesActivas.isEmpty
        ? 'cerca tuyo'
        : prefs.ciudadesActivas.length == 1
            ? prefs.ciudadesActivas.first
            : '${prefs.ciudadesActivas.length} ciudades';

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
          'Planes',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
      ),
      child: SafeArea(
        child: _cargando
            ? const Center(child: FernecitoLoader.inline(size: 28))
            : RefreshIndicator(
                color: ColoresApp.principalMarca,
                backgroundColor: const Color(0xFF1E1E1E),
                onRefresh: () => _cargar(reset: true),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Juntadas para salir',
                              style: GoogleFonts.baloo2(
                                fontSize: 26,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                color: ColoresApp.textoPrincipal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Planes en $zona · sumate y conocé gente antes',
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_planes.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _VacioPlanes(onReintentar: () => _cargar(reset: true)),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                        sliver: SliverList.separated(
                          itemCount: _planes.length + (_cargandoMas ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            if (i >= _planes.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: FernecitoLoader.inline(size: 22),
                                ),
                              );
                            }
                            final plan = _planes[i];
                            return _CardPlan(
                              plan: plan,
                              uniendo: _uniendoId == plan.id,
                              onTap: () => _abrirDetalle(plan),
                              onUnirse: () => _unirse(plan),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CardPlan extends StatelessWidget {
  const _CardPlan({
    required this.plan,
    required this.onTap,
    required this.onUnirse,
    this.uniendo = false,
  });

  final PlanComunidad plan;
  final VoidCallback onTap;
  final VoidCallback onUnirse;
  final bool uniendo;

  @override
  Widget build(BuildContext context) {
    final marca = ColoresApp.principalMarca;
    final foto = plan.fotoLocalUrl ?? plan.fotoOrganizadorUrl;
    final organizador = plan.tipoOrganizador == 'squad' &&
            (plan.nombreSquad?.trim().isNotEmpty ?? false)
        ? plan.nombreSquad!
        : plan.nombreOrganizador;

    return CardSuperficieSocial(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarLocal(url: foto, letra: plan.nombreLocal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.nombreLocal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: marca,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ChipEstado(plan: plan),
            ],
          ),
          if (plan.descripcion.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              plan.descripcion.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                height: 1.25,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaChip(
                icono: CupertinoIcons.calendar,
                texto: _fmtFecha(plan.fechaInicio),
              ),
              _MetaChip(
                icono: CupertinoIcons.location_solid,
                texto: plan.ciudad,
              ),
              _MetaChip(
                icono: CupertinoIcons.person_2_fill,
                texto: plan.cupoMax == null
                    ? '${plan.cupoUsados} van'
                    : '${plan.cupoUsados}/${plan.cupoMax}',
              ),
              _MetaChip(
                icono: plan.modoLista == 'manual'
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.lock_open_fill,
                texto: plan.modoLista == 'manual' ? 'Con aprobación' : 'Libre',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Por $organizador',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ),
              if (!plan.soyMiembro && !plan.soyPendiente)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  color: plan.cupoLleno
                      ? const Color(0xFF3A3A3A)
                      : marca.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  onPressed: (uniendo || plan.cupoLleno) ? null : onUnirse,
                  child: uniendo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CupertinoActivityIndicator(radius: 7),
                        )
                      : Text(
                          plan.cupoLleno ? 'Lleno' : 'Sumarme',
                          style: GoogleFonts.baloo2(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                )
              else
                Text(
                  plan.soyMiembro ? 'Ya estás dentro' : 'Pedido enviado',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: plan.soyMiembro ? marca : ColoresApp.textoSecundario,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.plan});
  final PlanComunidad plan;

  @override
  Widget build(BuildContext context) {
    final (label, color) = plan.soyMiembro
        ? ('Voy', ColoresApp.principalMarca)
        : plan.soyPendiente
            ? ('Pendiente', const Color(0xFFF5A623))
            : plan.cupoLleno
                ? ('Lleno', const Color(0xFF888888))
                : (
                    plan.modoLista == 'manual' ? 'Pedir' : 'Abierto',
                    const Color(0xFF4ADE80),
                  );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.baloo2(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: ColoresApp.textoSecundario),
          const SizedBox(width: 5),
          Text(
            texto,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarLocal extends StatelessWidget {
  const _AvatarLocal({required this.url, required this.letra});
  final String? url;
  final String letra;

  @override
  Widget build(BuildContext context) {
    final limpia = letra.trim();
    final inicial = limpia.isEmpty ? '?' : limpia.substring(0, 1).toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 56,
        height: 56,
        color: const Color(0xFF2A2A2A),
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Color(0xFF2A2A2A)),
                errorWidget: (_, _, _) => _fallback(inicial),
              )
            : _fallback(inicial),
      ),
    );
  }

  Widget _fallback(String inicial) => Center(
        child: Text(
          inicial,
          style: GoogleFonts.baloo2(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: ColoresApp.textoSecundario,
          ),
        ),
      );
}

class _VacioPlanes extends StatelessWidget {
  const _VacioPlanes({required this.onReintentar});
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.calendar_badge_plus,
            size: 42,
            color: ColoresApp.principalMarca.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            'Todavía no hay planes acá',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando alguien arme una juntada en un local de tu zona, aparece acá.',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: ColoresApp.principalMarca.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            onPressed: onReintentar,
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
    );
  }
}

class _DetallePlanSheet extends StatelessWidget {
  const _DetallePlanSheet({
    required this.plan,
    required this.onUnirse,
    this.uniendo = false,
  });

  final PlanComunidad plan;
  final VoidCallback onUnirse;
  final bool uniendo;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final organizador = plan.tipoOrganizador == 'squad' &&
            (plan.nombreSquad?.trim().isNotEmpty ?? false)
        ? plan.nombreSquad!
        : plan.nombreOrganizador;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.fromLTRB(10, 0, 10, bottom + 10),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              plan.titulo,
              style: GoogleFonts.baloo2(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.nombreLocal} · ${plan.ciudad}',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ColoresApp.principalMarca,
              ),
            ),
            const SizedBox(height: 10),
            if (plan.descripcion.trim().isNotEmpty)
              Text(
                plan.descripcion.trim(),
                style: GoogleFonts.baloo2(
                  fontSize: 14.5,
                  height: 1.3,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '${_fmtFecha(plan.fechaInicio)} · por $organizador',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textoSecundario,
              ),
            ),
            const SizedBox(height: 16),
            if (!plan.soyMiembro && !plan.soyPendiente)
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: plan.cupoLleno
                      ? const Color(0xFF3A3A3A)
                      : ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: (uniendo || plan.cupoLleno) ? null : onUnirse,
                  child: Text(
                    plan.cupoLleno ? 'Cupo lleno' : 'Sumarme al plan',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              Text(
                plan.soyMiembro
                    ? 'Ya sos parte de este plan.'
                    : 'Tu pedido está pendiente de aprobación.',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _fmtFecha(DateTime d) {
  const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final local = d.toLocal();
  final dia = dias[local.weekday - 1];
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$dia ${local.day} ${meses[local.month - 1]} · $hh:$mm';
}
