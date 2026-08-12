/// Cards de locales para rellenar secciones de cartelera (mismas dimensiones que eventos).
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../models/local_cartelera_card.dart';
import 'avatar_local.dart';
import 'cards_cartelera.dart';

enum VarianteCardLocalCartelera { grande, mediano, grid }

/// Card de local con avatar protagonista, rating y texto IA semanal.
class CardLocalCartelera extends StatefulWidget {
  const CardLocalCartelera({
    super.key,
    required this.local,
    required this.onTap,
    this.variante = VarianteCardLocalCartelera.mediano,
    this.ancho,
  });

  final LocalCarteleraCard local;
  final VoidCallback onTap;
  final VarianteCardLocalCartelera variante;
  final double? ancho;

  @override
  State<CardLocalCartelera> createState() => _CardLocalCarteleraState();
}

class _CardLocalCarteleraState extends State<CardLocalCartelera> {
  static const _intervaloFade = Duration(seconds: 5);
  Timer? _timer;
  int _indiceFoto = 0;

  @override
  void initState() {
    super.initState();
    _arrancarFadeSiCorresponde();
  }

  @override
  void didUpdateWidget(covariant CardLocalCartelera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.local.imagenesUrls != widget.local.imagenesUrls) {
      _timer?.cancel();
      _indiceFoto = 0;
      _arrancarFadeSiCorresponde();
    }
  }

  void _arrancarFadeSiCorresponde() {
    final fotos = widget.local.imagenesUrls;
    if (fotos.length <= 1) return;
    _timer = Timer.periodic(_intervaloFade, (_) {
      if (!mounted) return;
      setState(() => _indiceFoto = (_indiceFoto + 1) % fotos.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get _ancho {
    if (widget.ancho != null) return widget.ancho!;
    switch (widget.variante) {
      case VarianteCardLocalCartelera.grande:
        return 240;
      case VarianteCardLocalCartelera.mediano:
        return 175;
      case VarianteCardLocalCartelera.grid:
        return double.infinity;
    }
  }

  double get _alto {
    switch (widget.variante) {
      case VarianteCardLocalCartelera.grande:
        return _ancho * (14 / 9);
      case VarianteCardLocalCartelera.mediano:
        return _ancho * (13 / 9);
      case VarianteCardLocalCartelera.grid:
        return double.infinity;
    }
  }

  double get _radio {
    switch (widget.variante) {
      case VarianteCardLocalCartelera.grande:
        return 20;
      case VarianteCardLocalCartelera.mediano:
        return 16;
      case VarianteCardLocalCartelera.grid:
        return 14;
    }
  }

  bool get _estiloGrande => widget.variante == VarianteCardLocalCartelera.grande;

  @override
  Widget build(BuildContext context) {
    final l = widget.local;
    final fotos = l.imagenesUrls;
    final fotoActual = fotos.isNotEmpty
        ? fotos[_indiceFoto % fotos.length]
        : '';

    final avatarSize = _estiloGrande ? 52.0 : 44.0;
    final nombreSize = _estiloGrande ? 18.0 : 15.5;
    final textoSize = _estiloGrande ? 12.5 : 11.0;

    Widget contenido = ClipRRect(
      borderRadius: BorderRadius.circular(_radio),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _FondoLocal(
              key: ValueKey(fotoActual),
              url: fotoActual,
            ),
          ),
          _GradienteLocal(),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AvatarLocal(
                      imageUrl: l.avatarUrl,
                      size: avatarSize,
                      esPionero: l.esPionero,
                      placeholderIcon: CupertinoIcons.house_fill,
                      borderWidth: l.esPionero ? 2.4 : 2.0,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              text: l.nombreLocal,
                              style: GoogleFonts.baloo2(
                                color: Colors.white,
                                fontSize: nombreSize,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                              children: [
                                if (l.esPionero || l.esVerificado)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 3),
                                      child: Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: _estiloGrande ? 15 : 13,
                                        color: l.esPionero
                                            ? CardLocalPopular.doradoPionero
                                            : ColoresApp.principalMarca,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (l.tieneResenas) ...[
                            const SizedBox(height: 4),
                            _RatingLocal(
                              promedio: l.ratingPromedio!,
                              compacto: !_estiloGrande,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (l.textoIa.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.textoIa.trim(),
                    maxLines: _estiloGrande ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: textoSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (l.esPionero || l.tienePlanActivo)
            Positioned(
              top: 10,
              right: 10,
              child: _BadgeLocalRecomendado(esPionero: l.esPionero),
            ),
        ],
      ),
    );

    if (widget.variante == VarianteCardLocalCartelera.grid) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AspectRatio(
          aspectRatio: 9 / 13,
          child: contenido,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _ancho,
        height: _alto,
        child: contenido,
      ),
    );
  }
}

class _FondoLocal extends StatelessWidget {
  const _FondoLocal({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: ColoresApp.fondoSuperficie,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.building_2_fill,
          color: ColoresApp.textoSecundario,
          size: 42,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => Container(color: ColoresApp.fondoSuperficie),
      errorWidget: (_, __, ___) => Container(
        color: ColoresApp.fondoSuperficie,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.photo,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}

class _GradienteLocal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.18),
              Colors.black.withOpacity(0.04),
              Colors.black.withOpacity(0.42),
              Colors.black.withOpacity(0.94),
            ],
            stops: const [0, 0.34, 0.62, 1.0],
          ),
        ),
      ),
    );
  }
}

class _RatingLocal extends StatelessWidget {
  const _RatingLocal({
    required this.promedio,
    this.compacto = false,
  });

  final double promedio;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final estrellas = promedio.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = estrellas >= i + 1 - 0.25;
          return Icon(
            filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
            size: compacto ? 11 : 12,
            color: filled ? const Color(0xFFFFD54F) : Colors.white38,
          );
        }),
        const SizedBox(width: 4),
        Text(
          promedio.toStringAsFixed(1),
          style: GoogleFonts.baloo2(
            color: Colors.white.withOpacity(0.9),
            fontSize: compacto ? 10.5 : 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BadgeLocalRecomendado extends StatelessWidget {
  const _BadgeLocalRecomendado({required this.esPionero});
  final bool esPionero;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: esPionero
            ? CardLocalPopular.doradoPionero.withOpacity(0.92)
            : ColoresApp.principalMarca.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        esPionero ? 'Pionero' : 'Recomendado',
        style: GoogleFonts.baloo2(
          color: Colors.black,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
