/// Cards reusables para la cartelera de usuarios.
///
/// 4 variantes:
/// - [CardEventoGrande]    → para top y top_ultra (carrusel principal)
/// - [CardEventoMediano]   → para recomendado_fernecito y normal
/// - [CardEventoGrid]      → para jerarquía gratis (grid 2 columnas)
/// - [CardLocalPopular]    → sección "Lugares populares" (round avatar)
///
/// Todas comparten paleta (`ColoresApp`) y tipografía Baloo2.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

class EventoCartelera {
  const EventoCartelera({
    required this.idEvento,
    required this.titulo,
    required this.urlFlyer,
    required this.nombreLocal,
    this.avatarLocal,
    this.fechaTexto,
    this.fechaCorta,
    this.jerarquia,
    this.tienePromo = false,
    this.cupoMax,
    this.cuposLibres,
    this.localVerificado = false,
  });

  final String idEvento;
  final String titulo;
  final String urlFlyer;
  final String nombreLocal;
  final String? avatarLocal;

  /// Versión completa ("Vie 10 Sep · 21:00"). Usada en cards grandes.
  final String? fechaTexto;

  /// Versión compacta ("Vie 10"). Usada en cards medianas y grid para no chocar
  /// con el badge de promo en top-right.
  final String? fechaCorta;

  final String? jerarquia;
  final bool tienePromo;
  final int? cupoMax;
  final int? cuposLibres;
  final bool localVerificado;
}

/// Card grande (top / top_ultra). Aspect ratio ~9:14, flyer protagonista.
class CardEventoGrande extends StatelessWidget {
  const CardEventoGrande({
    super.key,
    required this.evento,
    required this.onTap,
    this.ancho = 240,
  });

  final EventoCartelera evento;
  final VoidCallback onTap;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final alto = ancho * (14 / 9);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: ancho,
        height: alto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Flyer(url: evento.urlFlyer),
              _GradienteSobreFlyer(),
              // Badge fecha completa (esquina sup izq)
              if (evento.fechaTexto != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _BadgeFecha(fechaTexto: evento.fechaTexto!),
                ),
              // Badge promo (esquina sup der)
              if (evento.tienePromo)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: _BadgePromo(),
                ),
              // Info al pie con badge "Quedan N 🔥" arriba del título si aplica
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _InfoEventoPie(
                  titulo: evento.titulo,
                  nombreLocal: evento.nombreLocal,
                  avatarLocal: evento.avatarLocal,
                  localVerificado: evento.localVerificado,
                  estiloGrande: true,
                  badgeCupos: _mostrarFomo()
                      ? _BadgeCuposFomo(
                          cuposLibres: evento.cuposLibres!,
                          compacto: false,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _mostrarFomo() {
    final c = evento.cuposLibres;
    if (c == null) return false;
    final max = evento.cupoMax;
    if (max == null || max <= 0) return false;
    return c > 0 && c <= 10;
  }
}

/// Card mediana (recomendado_fernecito / normal). Aspect ~9:13.
class CardEventoMediano extends StatelessWidget {
  const CardEventoMediano({
    super.key,
    required this.evento,
    required this.onTap,
    this.ancho = 175,
  });
  final EventoCartelera evento;
  final VoidCallback onTap;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final alto = ancho * (13 / 9);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: ancho,
        height: alto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Flyer(url: evento.urlFlyer),
              _GradienteSobreFlyer(),
              // Badge fecha CORTA (solo "Vie 10") para no chocar con promo
              if (evento.fechaCorta != null || evento.fechaTexto != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _BadgeFecha(
                    fechaTexto: evento.fechaCorta ?? evento.fechaTexto!,
                    compacto: true,
                  ),
                ),
              if (evento.tienePromo)
                const Positioned(top: 8, right: 8, child: _BadgePromo(compacto: true)),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _InfoEventoPie(
                  titulo: evento.titulo,
                  nombreLocal: evento.nombreLocal,
                  avatarLocal: evento.avatarLocal,
                  localVerificado: evento.localVerificado,
                  estiloGrande: false,
                  badgeCupos: _mostrarFomoMediano()
                      ? _BadgeCuposFomo(
                          cuposLibres: evento.cuposLibres!,
                          compacto: true,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _mostrarFomoMediano() {
    final c = evento.cuposLibres;
    if (c == null) return false;
    final max = evento.cupoMax;
    if (max == null || max <= 0) return false;
    return c > 0 && c <= 10;
  }
}

/// Card para grid (jerarquía gratis). Compacta, sin tanta info encima del flyer.
class CardEventoGrid extends StatelessWidget {
  const CardEventoGrid({super.key, required this.evento, required this.onTap});
  final EventoCartelera evento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 9 / 13,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Flyer(url: evento.urlFlyer),
              _GradienteSobreFlyer(),
              if (evento.tienePromo)
                const Positioned(top: 6, right: 6, child: _BadgePromo(compacto: true)),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      evento.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      evento.nombreLocal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
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

/// Card de local en la sección "Lugares populares".
class CardLocalPopular extends StatelessWidget {
  const CardLocalPopular({
    super.key,
    required this.idLocal,
    required this.nombreLocal,
    this.urlAvatar,
    this.rubro,
    this.verificado = false,
    required this.onTap,
  });
  final String idLocal;
  final String nombreLocal;
  final String? urlAvatar;
  final String? rubro;
  final bool verificado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: verificado
                      ? ColoresApp.principalMarca
                      : ColoresApp.textoSecundario.withOpacity(0.25),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: (urlAvatar != null && urlAvatar!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: urlAvatar!,
                        fit: BoxFit.cover,
                        placeholder: (c, _) =>
                            Container(color: ColoresApp.fondoSuperficie),
                        errorWidget: (c, _, __) => Container(
                          color: ColoresApp.fondoSuperficie,
                          child: const Icon(CupertinoIcons.house_fill,
                              color: ColoresApp.textoSecundario, size: 28),
                        ),
                      )
                    : Container(
                        color: ColoresApp.fondoSuperficie,
                        child: const Icon(CupertinoIcons.house_fill,
                            color: ColoresApp.textoSecundario, size: 28),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    nombreLocal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (verificado) ...[
                  const SizedBox(width: 3),
                  Icon(CupertinoIcons.checkmark_seal_fill,
                      size: 11, color: ColoresApp.principalMarca),
                ],
              ],
            ),
            if (rubro != null && rubro!.isNotEmpty)
              Text(
                rubro!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoSecundario,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== Sub-widgets internos =====

class _Flyer extends StatelessWidget {
  const _Flyer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: ColoresApp.fondoSuperficie,
        alignment: Alignment.center,
        child: const Icon(CupertinoIcons.photo,
            color: ColoresApp.textoSecundario, size: 28),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (c, _) => Container(color: ColoresApp.fondoSuperficie),
      errorWidget: (c, _, __) => Container(
        color: ColoresApp.fondoSuperficie,
        alignment: Alignment.center,
        child: const Icon(CupertinoIcons.photo,
            color: ColoresApp.textoSecundario, size: 28),
      ),
    );
  }
}

class _GradienteSobreFlyer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.30),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.82),
            ],
            stops: const [0, 0.25, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}


class _BadgePromo extends StatelessWidget {
  const _BadgePromo({this.compacto = false});
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final pad = compacto
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 9, vertical: 4);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: ColoresApp.flashPromo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.gift_fill, size: 12, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            'Promo',
            style: GoogleFonts.baloo2(
              color: Colors.black,
              fontSize: compacto ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCuposFomo extends StatelessWidget {
  const _BadgeCuposFomo({required this.cuposLibres, this.compacto = false});
  final int cuposLibres;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compacto
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ColoresApp.peligroMarca.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.flame_fill,
              color: Colors.white, size: compacto ? 11 : 12),
          const SizedBox(width: 3),
          Text(
            compacto ? '$cuposLibres' : 'Quedan $cuposLibres',
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: compacto ? 10 : 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge compacto de fecha (top-left de las cards). Mismo tono que los demás badges
/// para mantener consistencia con cupos/promo.
class _BadgeFecha extends StatelessWidget {
  const _BadgeFecha({required this.fechaTexto, this.compacto = false});
  final String fechaTexto;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final pad = compacto
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 9, vertical: 4);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.calendar,
              size: compacto ? 11 : 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            fechaTexto,
            style: GoogleFonts.baloo2(
              color: Colors.white,
              fontSize: compacto ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoEventoPie extends StatelessWidget {
  const _InfoEventoPie({
    required this.titulo,
    required this.nombreLocal,
    required this.avatarLocal,
    required this.localVerificado,
    required this.estiloGrande,
    this.badgeCupos,
  });
  final String titulo;
  final String nombreLocal;
  final String? avatarLocal;
  final bool localVerificado;
  final bool estiloGrande;

  /// Badge opcional que se renderiza arriba del título (donde antes iba la fecha).
  /// Hoy se usa para el FOMO de cupos.
  final Widget? badgeCupos;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badgeCupos != null) ...[
          badgeCupos!,
          const SizedBox(height: 6),
        ],
        Text(
          titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.baloo2(
            color: Colors.white,
            fontSize: estiloGrande ? 17 : 14.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarLocal != null && avatarLocal!.isNotEmpty)
              Container(
                width: estiloGrande ? 18 : 14,
                height: estiloGrande ? 18 : 14,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: avatarLocal!,
                    fit: BoxFit.cover,
                    errorWidget: (c, _, __) =>
                        Container(color: Colors.white24),
                  ),
                ),
              ),
            Flexible(
              child: Text(
                nombreLocal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: estiloGrande ? 13 : 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (localVerificado) ...[
              const SizedBox(width: 4),
              Icon(CupertinoIcons.checkmark_seal_fill,
                  size: estiloGrande ? 13 : 11,
                  color: ColoresApp.principalMarca),
            ],
          ],
        ),
      ],
    );
  }
}
