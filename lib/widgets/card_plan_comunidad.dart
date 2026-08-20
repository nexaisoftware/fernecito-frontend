/// Card de plan de comunidad — misma UI en Social (Mis planes) y Mi Actividad.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_planes.dart';

class CardPlanComunidad extends StatelessWidget {
  const CardPlanComunidad({
    super.key,
    required this.plan,
    required this.onTap,
    required this.onUnirse,
    required this.onReportar,
    this.onCompartir,
    this.uniendo = false,
  });

  final PlanComunidad plan;
  final VoidCallback onTap;
  final VoidCallback onUnirse;
  final VoidCallback onReportar;
  final VoidCallback? onCompartir;
  final bool uniendo;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(plan.colorHex);
    final portada = plan.portadaUrl;
    final desactivada = plan.estaFinalizado;

    return Opacity(
      opacity: desactivada ? 0.52 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 188),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: desactivada ? 0.06 : 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: portada != null && portada.isNotEmpty
                    ? _FondoPlan(path: portada, fallback: color)
                    : ColoredBox(color: color),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.48),
                        Colors.black.withValues(alpha: 0.78),
                        Colors.black.withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _AutoresPlanLine(plan: plan)),
                        const SizedBox(width: 8),
                        if (plan.soyModerador)
                          const _MiniBadge('Sos admin')
                        else
                          _EstadoBadge(plan: plan),
                      ],
                    ),
                    if (plan.soyMiembro) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Estoy adentro',
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      plan.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 21,
                        height: 0.98,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                    if (plan.descripcion.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        plan.descripcion.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 11.8,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.88),
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _MiniBadgePersonas(plan.personasAceptadas),
                        _MiniBadge(
                          'inicio ${_fmtFechaCorta(plan.fechaInicio)}',
                        ),
                        if (plan.fechaFin != null)
                          _MiniBadge('fin ${_fmtFechaCorta(plan.fechaFin!)}'),
                        _MiniBadge(
                          plan.modoLista == 'manual'
                              ? 'con aprobación'
                              : 'entrada libre',
                        ),
                        if (plan.cupoMax != null)
                          _MiniBadge(
                            '${plan.cupoUsados}/${plan.cupoMax} cupos',
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _AccionesPlan(
                      plan: plan,
                      desactivada: desactivada,
                      uniendo: uniendo,
                      onTap: onTap,
                      onUnirse: onUnirse,
                      onCompartir: onCompartir,
                      onReportar: onReportar,
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

class _AccionesPlan extends StatelessWidget {
  const _AccionesPlan({
    required this.plan,
    required this.desactivada,
    required this.uniendo,
    required this.onTap,
    required this.onUnirse,
    required this.onReportar,
    this.onCompartir,
  });

  final PlanComunidad plan;
  final bool desactivada;
  final bool uniendo;
  final VoidCallback onTap;
  final VoidCallback onUnirse;
  final VoidCallback onReportar;
  final VoidCallback? onCompartir;

  @override
  Widget build(BuildContext context) {
    final acciones = <Widget>[
      if (onCompartir != null) ...[
        _IconoAccionPlan(
          icon: Icons.share_rounded,
          tooltip: 'Compartir plan',
          onTap: desactivada ? null : onCompartir,
        ),
        const SizedBox(width: 8),
      ],
      _IconoAccionPlan(
        icon: Icons.more_horiz_rounded,
        tooltip: 'Reportar plan',
        onTap: onReportar,
      ),
    ];

    if (desactivada) {
      return Row(
        children: [
          const Expanded(child: _BotonGlassDeshabilitado(texto: 'Finalizado')),
          const SizedBox(width: 10),
          ...acciones,
        ],
      );
    }

    if (plan.soyMiembro) {
      return Row(
        children: [
          Expanded(
            child: _BotonGlass(texto: 'Ver plan', onTap: onTap),
          ),
          const SizedBox(width: 10),
          ...acciones,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _BotonGlass(texto: 'Ver más', onTap: onTap),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _BotonPlan(plan: plan, uniendo: uniendo, onTap: onUnirse),
        ),
        const SizedBox(width: 9),
        ...acciones,
      ],
    );
  }
}

class _IconoAccionPlan extends StatelessWidget {
  const _IconoAccionPlan({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Icon(
          icon,
          size: 20,
          color: Colors.white.withValues(alpha: habilitado ? 0.92 : 0.36),
        ),
      ),
    );
  }
}

class _FondoPlan extends StatelessWidget {
  const _FondoPlan({required this.path, required this.fallback});
  final String path;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: path,
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(color: fallback),
      errorWidget: (_, _, _) => ColoredBox(color: fallback),
    );
  }
}

class _BotonPlan extends StatelessWidget {
  const _BotonPlan({
    required this.plan,
    required this.uniendo,
    required this.onTap,
  });
  final PlanComunidad plan;
  final bool uniendo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = plan.estaFinalizado
        ? 'Finalizado'
        : plan.soyMiembro
        ? 'Ya estás'
        : plan.soyPendiente
        ? 'Pendiente'
        : plan.cupoLleno
        ? 'Lleno'
        : plan.modoLista == 'manual'
        ? 'Solicitar'
        : 'Unirme';
    return GestureDetector(
      onTap: plan.puedeUnirse && !uniendo ? onTap : null,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: plan.puedeUnirse
              ? ColoresApp.principalMarca
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: uniendo
            ? const CupertinoActivityIndicator(radius: 7, color: Colors.white)
            : Text(
                texto,
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _BotonGlass extends StatelessWidget {
  const _BotonGlass({required this.texto, required this.onTap});
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BotonGlassDeshabilitado extends StatelessWidget {
  const _BotonGlassDeshabilitado({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
    ),
    child: Text(
      texto,
      style: GoogleFonts.baloo2(
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        color: Colors.white70,
      ),
    ),
  );
}

class _AutoresPlanLine extends StatelessWidget {
  const _AutoresPlanLine({required this.plan});
  final PlanComunidad plan;

  @override
  Widget build(BuildContext context) {
    if (plan.esPlanLocal) {
      return Row(
        children: [
          _AvatarMini(url: plan.fotoLocalUrl, fallback: plan.nombreLocal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Plan del local · ${plan.nombreLocal}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 11.8,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        _AvatarMini(
          url: plan.fotoOrganizadorUrl,
          fallback: plan.nombreOrganizador,
        ),
        const SizedBox(width: 6),
        _AvatarMini(url: plan.fotoLocalUrl, fallback: plan.nombreLocal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Plan de ${plan.primerNombreOrganizador} en ${plan.nombreLocal}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.94),
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarMini extends StatelessWidget {
  const _AvatarMini({required this.url, required this.fallback});
  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final ini = fallback.trim().isEmpty
        ? '?'
        : fallback.trim().substring(0, 1).toUpperCase();
    return SizedBox(
      width: 30,
      height: 30,
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                memCacheWidth: 90,
                errorWidget: (_, _, _) => _fallback(ini),
                placeholder: (_, _) => ColoredBox(
                  color: const Color(0xFF252525),
                  child: _fallback(ini),
                ),
              )
            : ColoredBox(color: const Color(0xFF252525), child: _fallback(ini)),
      ),
    );
  }

  Widget _fallback(String ini) => Center(
    child: Text(
      ini,
      style: GoogleFonts.baloo2(
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.plan});
  final PlanComunidad plan;

  @override
  Widget build(BuildContext context) {
    final texto = plan.esPlanLocal
        ? 'Plan del local'
        : plan.estaFinalizado
        ? 'Finalizado'
        : plan.soyPendiente
        ? 'Pendiente'
        : plan.soyMiembro
        ? 'Voy'
        : 'Abierto';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MiniBadgePersonas extends StatelessWidget {
  const _MiniBadgePersonas(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_2_fill,
            size: 11,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          const SizedBox(width: 4),
          Text(
            '$n',
            style: GoogleFonts.baloo2(
              fontSize: 10.5,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: GoogleFonts.baloo2(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

Color _parseColor(String hex) {
  final limpio = hex.replaceAll('#', '').trim();
  if (limpio.length != 6) return ColoresApp.principalMarca;
  return Color(int.parse('FF$limpio', radix: 16));
}

String _fmtFechaCorta(DateTime d) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final local = d.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${meses[local.month - 1]} · $hh:$mm';
}
