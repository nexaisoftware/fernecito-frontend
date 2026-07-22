/// Widgets reutilizables del mapa explorar.

library;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart'
    show Colors, HSLColor, Icons, Tween, TweenSequence;

import 'package:flutter_map/flutter_map.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

import '../core/servicio_mapa_explorar.dart';

import '../core/tema_fernecito.dart';

import 'avatar_local.dart';

import 'fernecito_loader.dart';

export 'fernecito_loader.dart' show LoaderIconosAnimado, LoaderMapaIconosAnimado;

import 'social_ui.dart';

const _calculadorDistancia = Distance();

String? textoDistanciaDesdeUsuario(LatLng? usuario, LatLng destino) {
  if (usuario == null) return null;
  final metros = _calculadorDistancia(usuario, destino);
  if (metros < 50) return 'Muy cerca tuyo';
  if (metros < 1000) return 'A ${metros.round()} m de ti';
  final km = metros / 1000;
  if (km < 10) {
    final txt = km.toStringAsFixed(1).replaceAll('.', ',');
    return 'A $txt km de ti';
  }
  return 'A ${km.round()} km de ti';
}

/// Tinte de calles: color del tema legible, sin el neón de BlendMode.color puro.
Color _colorTinteCallesMapa(Color tema) {
  final hsl = HSLColor.fromColor(tema);
  final sat = (hsl.saturation * 0.68 + 0.10).clamp(0.24, 0.70);
  final light = (hsl.lightness * 0.82 + 0.10).clamp(0.44, 0.58);
  return hsl.withSaturation(sat).withLightness(light).toColor();
}

ColorFilter _filtroCallesMapaTematizado(Color tema) {
  final tinte = _colorTinteCallesMapa(tema);
  return ColorFilter.mode(
    tinte.withValues(alpha: 0.40),
    BlendMode.overlay,
  );
}

/// Tiles oscuros con calles y vías teñidas al color del tema activo.
class CapaTilesMapaConTema extends StatelessWidget {
  const CapaTilesMapaConTema({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, accent, _) {
        return ColorFiltered(
          colorFilter: _filtroCallesMapaTematizado(accent),
          child: TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            retinaMode: RetinaMode.isHighDensity(context),
            userAgentPackageName: 'com.nexaisoftware.fernecitoapp',
          ),
        );
      },
    );
  }
}

/// Punto de la ubicación del usuario en el mapa.
class PinUbicacionUsuario extends StatelessWidget {
  const PinUbicacionUsuario({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, accent, _) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ícono de mapa con pulso suave (misma idea que el like del perfil local).

class IconoMapaCarteleraAnimado extends StatefulWidget {

  const IconoMapaCarteleraAnimado({

    super.key,

    this.size = 24,

    this.onTap,

  });

  final double size;

  final VoidCallback? onTap;

  @override

  State<IconoMapaCarteleraAnimado> createState() =>

      _IconoMapaCarteleraAnimadoState();

}

class _IconoMapaCarteleraAnimadoState extends State<IconoMapaCarteleraAnimado>

    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  late final Animation<double> _scale;

  bool _pulsoArmado = false;

  @override

  void initState() {

    super.initState();

    _controller = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 360),

    );

    _scale = TweenSequence<double>([

      TweenSequenceItem(tween: Tween(begin: 1, end: 1.18), weight: 30),

      TweenSequenceItem(tween: Tween(begin: 1.18, end: 0.94), weight: 24),

      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.08), weight: 22),

      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1), weight: 24),

    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarPulso());

  }

  Future<void> _iniciarPulso() async {

    if (_pulsoArmado) return;

    _pulsoArmado = true;

    while (mounted) {

      await Future<void>.delayed(const Duration(seconds: 3));

      if (!mounted || _controller.isAnimating) continue;

      await _controller.forward(from: 0);

    }

  }

  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }

  @override

  Widget build(BuildContext context) {

    final icono = ValueListenableBuilder<Color>(

      valueListenable: TemaFernecito.instancia.colorActual,

      builder: (context, accent, _) {

        return ScaleTransition(

          scale: _scale,

          child: Icon(

            CupertinoIcons.map,

            size: widget.size,

            color: accent,

            shadows: [

              Shadow(

                color: accent.withValues(alpha: 0.35),

                blurRadius: 10,

              ),

            ],

          ),

        );

      },

    );

    final onTap = widget.onTap;

    if (onTap == null) return icono;

    return GestureDetector(

      onTap: onTap,

      behavior: HitTestBehavior.opaque,

      child: icono,

    );

  }
}

/// Ícono estilo Google Maps (anillo + punto central).
class IconoCentrarUbicacionMapa extends StatelessWidget {
  const IconoCentrarUbicacionMapa({
    super.key,
    required this.activo,
    this.size = 22,
  });

  final bool activo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, accent, _) {
        final color =
            activo ? accent : ColoresApp.textoSecundario;
        return Icon(Icons.my_location, size: size, color: color);
      },
    );
  }
}

/// Botón glass para centrar en la ubicación del usuario.
class BotonUbicacionMapa extends StatelessWidget {
  const BotonUbicacionMapa({
    super.key,
    required this.activo,
    required this.cargando,
    this.onTap,
  });

  final bool activo;
  final bool cargando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: FernecitoLoader.inline(size: 18),
                    )
                  : IconoCentrarUbicacionMapa(activo: activo, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Switch flotante Locales / Eventos.

class MapaSwitchModo extends StatelessWidget {

  const MapaSwitchModo({

    super.key,

    required this.indice,

    required this.onChanged,

  });

  final int indice;

  final ValueChanged<int> onChanged;

  static const _ancho = 300.0;

  static const _radio = 50.0;

  @override

  Widget build(BuildContext context) {

    return ValueListenableBuilder<Color>(

      valueListenable: TemaFernecito.instancia.colorActual,

      builder: (context, accent, _) {

        return DecoratedBox(

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(_radio),

            boxShadow: [

              BoxShadow(

                color: accent.withValues(alpha: 0.16),

                blurRadius: 16,

                spreadRadius: 0,

              ),

              BoxShadow(

                color: Colors.black.withValues(alpha: 0.38),

                blurRadius: 14,

                offset: const Offset(0, 5),

              ),

            ],

          ),

          child: ToggleSegmentadoSocial(

            opciones: const ['Locales', 'Eventos'],

            indice: indice,

            onChanged: onChanged,

            anchoMaximo: _ancho,

            anchoMinimo: _ancho,

            paddingVertical: 7,

            fontSize: 13.5,

            sinBorde: true,

            centrar: false,

          ),

        );

      },

    );

  }

}

/// Pin circular con avatar de local.

class PinAvatarLocalMapa extends StatelessWidget {

  const PinAvatarLocalMapa({

    super.key,

    required this.imageUrl,

    required this.esPionero,

    required this.seleccionado,

    this.size = 52,

  });

  final String? imageUrl;

  final bool esPionero;

  final bool seleccionado;

  final double size;

  @override

  Widget build(BuildContext context) {

    return AnimatedScale(

      scale: seleccionado ? 1.12 : 1.0,

      duration: const Duration(milliseconds: 220),

      curve: Curves.easeOutCubic,

      child: AvatarLocal(

        imageUrl: imageUrl,

        size: size,

        esPionero: esPionero,

        placeholderIcon: CupertinoIcons.building_2_fill,

        borderWidth: seleccionado ? 2.6 : null,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: seleccionado ? 0.45 : 0.30),

            blurRadius: seleccionado ? 14 : 8,

            offset: const Offset(0, 3),

          ),

        ],

      ),

    );

  }

}

/// Pin rectangular con flyer de evento.

class PinFlyerEventoMapa extends StatelessWidget {

  const PinFlyerEventoMapa({

    super.key,

    required this.flyerUrl,

    required this.seleccionado,

    this.tienePromo = false,

    this.ancho = 48,

    this.alto = 64,

  });

  final String? flyerUrl;

  final bool seleccionado;

  final bool tienePromo;

  final double ancho;

  final double alto;

  @override

  Widget build(BuildContext context) {

    return ValueListenableBuilder<Color>(

      valueListenable: TemaFernecito.instancia.colorActual,

      builder: (context, accent, _) {

        return AnimatedScale(

          scale: seleccionado ? 1.1 : 1.0,

          duration: const Duration(milliseconds: 220),

          curve: Curves.easeOutCubic,

          child: Stack(

            clipBehavior: Clip.none,

            children: [

              Container(

                width: ancho,

                height: alto,

                decoration: BoxDecoration(

                  borderRadius: BorderRadius.circular(10),

                  boxShadow: [

                    if (seleccionado)

                      BoxShadow(

                        color: accent.withValues(alpha: 0.35),

                        blurRadius: 14,

                        spreadRadius: 1,

                      ),

                    BoxShadow(

                      color: Colors.black.withValues(alpha: 0.42),

                      blurRadius: 10,

                      offset: const Offset(0, 4),

                    ),

                  ],

                ),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(10),

                  child: _imagenFlyer(flyerUrl),

                ),

              ),

              if (tienePromo)

                const Positioned(

                  top: -5,

                  right: -5,

                  child: _BadgePromoMapa(),

                ),

            ],

          ),

        );

      },

    );

  }

  Widget _imagenFlyer(String? url) {

    final u = url?.trim() ?? '';

    if (u.isEmpty) {

      return ColoredBox(

        color: ColoresApp.fondoSuperficie,

        child: Icon(

          CupertinoIcons.ticket_fill,

          color: ColoresApp.textoSecundario,

          size: alto * 0.38,

        ),

      );

    }

    if (u.startsWith('assets/')) {

      return Image.asset(u, fit: BoxFit.cover);

    }

    return CachedNetworkImage(

      imageUrl: u,

      fit: BoxFit.cover,

      placeholder: (_, __) => const ColoredBox(

        color: ColoresApp.fondoSuperficie,

        child: FernecitoLoaderCentro(size: 16),

      ),

      errorWidget: (_, __, ___) => ColoredBox(

        color: ColoresApp.fondoSuperficie,

        child: Icon(

          CupertinoIcons.ticket_fill,

          color: ColoresApp.textoSecundario,

          size: alto * 0.38,

        ),

      ),

    );

  }

}

class _BadgePromoMapa extends StatelessWidget {

  const _BadgePromoMapa();

  @override

  Widget build(BuildContext context) {

    return Container(

      width: 20,

      height: 20,

      decoration: BoxDecoration(

        color: ColoresApp.flashPromo,

        shape: BoxShape.circle,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.35),

            blurRadius: 6,

            offset: const Offset(0, 2),

          ),

        ],

      ),

      child: const Icon(

        CupertinoIcons.gift_fill,

        size: 11,

        color: Color(0xFF1A1A1A),

      ),

    );

  }

}

/// Card glass flotante con info del pin seleccionado.

class MapaCardInfoFlotante extends StatelessWidget {

  const MapaCardInfoFlotante({

    super.key,

    required this.visible,

    this.local,

    this.evento,

    this.posicionUsuario,

    this.onVerDetalle,

  });

  final bool visible;

  final MapaLocalItem? local;

  final MapaEventoItem? evento;

  final LatLng? posicionUsuario;

  final VoidCallback? onVerDetalle;

  @override

  Widget build(BuildContext context) {

    final hayLocal = local != null;

    final hayEvento = evento != null;

    final mostrar = visible && (hayLocal || hayEvento);

    return AnimatedSlide(

      duration: const Duration(milliseconds: 280),

      curve: Curves.easeOutCubic,

      offset: mostrar ? Offset.zero : const Offset(0, -0.12),

      child: AnimatedOpacity(

        duration: const Duration(milliseconds: 220),

        opacity: mostrar ? 1 : 0,

        child: IgnorePointer(

          ignoring: !mostrar,

          child: mostrar

              ? Column(

                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    GestureDetector(

                      onTap: onVerDetalle,

                      behavior: HitTestBehavior.opaque,

                      child: ClipRRect(

                        borderRadius: BorderRadius.circular(18),

                        child: BackdropFilter(

                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),

                          child: DecoratedBox(

                            decoration: BoxDecoration(

                              gradient: LinearGradient(

                                begin: Alignment.topLeft,

                                end: Alignment.bottomRight,

                                colors: [

                                  const Color(0xFF1E1E22)

                                      .withValues(alpha: 0.82),

                                  const Color(0xFF111114)

                                      .withValues(alpha: 0.92),

                                ],

                              ),

                              borderRadius: BorderRadius.circular(18),

                            ),

                            child: Padding(

                              padding: const EdgeInsets.fromLTRB(

                                12,

                                10,

                                12,

                                10,

                              ),

                              child: Row(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  _miniatura(),

                                  const SizedBox(width: 12),

                                  Expanded(child: _textos(context)),

                                ],

                              ),

                            ),

                          ),

                        ),

                      ),

                    ),

                    if (_textoDistancia() != null) ...[

                      const SizedBox(height: 8),

                      _BadgeDistanciaMapa(

                        texto: _textoDistancia()!,

                        grande: true,

                      ),

                    ],

                  ],

                )

              : const SizedBox.shrink(),

        ),

      ),

    );

  }

  Widget _miniatura() {

    if (evento != null) {

      return PinFlyerEventoMapa(

        flyerUrl: evento!.flyerUrl,

        seleccionado: true,

        tienePromo: evento!.tienePromo == true,

        ancho: 64,

        alto: 86,

      );

    }

    return PinAvatarLocalMapa(

      imageUrl: local?.avatarUrl,

      esPionero: local?.esPionero ?? false,

      seleccionado: true,

      size: 54,

    );

  }

  Widget _textos(BuildContext context) {

    if (evento != null) {

      final e = evento!;

      return Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            e.titulo,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.baloo2(

              fontSize: 15,

              fontWeight: FontWeight.w800,

              color: ColoresApp.textoPrincipal,

              height: 1.1,

            ),

          ),

          const SizedBox(height: 3),

          Text(

            e.nombreLocal,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.baloo2(

              fontSize: 12.5,

              fontWeight: FontWeight.w700,

              color: ColoresApp.principalMarca,

            ),

          ),

          if (e.fechaInicio != null) ...[

            const SizedBox(height: 4),

            Text(

              _formatearFecha(e.fechaInicio!),

              style: GoogleFonts.baloo2(

                fontSize: 11.5,

                fontWeight: FontWeight.w700,

                color: ColoresApp.textoSecundario,

              ),

            ),

          ],

          if (e.tienePromo == true) ...[

            const SizedBox(height: 6),

            const _ChipPromoCard(),

          ],

          if ((e.descripcion ?? '').trim().isNotEmpty) ...[

            const SizedBox(height: 5),

            Text(

              e.descripcion!.trim(),

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              style: GoogleFonts.baloo2(

                fontSize: 11.5,

                color: ColoresApp.textoSecundario,

                height: 1.2,

              ),

            ),

          ],

        ],

      );

    }

    if (local != null) {

      final l = local!;

      return Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            l.nombre,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.baloo2(

              fontSize: 15,

              fontWeight: FontWeight.w800,

              color: ColoresApp.textoPrincipal,

              height: 1.1,

            ),

          ),

          const SizedBox(height: 4),

          Text(

            [l.ciudad, l.provincia].where((s) => s.isNotEmpty).join(' · '),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: GoogleFonts.baloo2(

              fontSize: 11.5,

              color: ColoresApp.textoSecundario,

            ),

          ),

          if ((l.descripcion ?? '').trim().isNotEmpty) ...[

            const SizedBox(height: 5),

            Text(

              l.descripcion!.trim(),

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              style: GoogleFonts.baloo2(

                fontSize: 11.5,

                color: ColoresApp.textoSecundario,

                height: 1.2,

              ),

            ),

          ],

        ],

      );

    }

    return const SizedBox.shrink();

  }

  String? _textoDistancia() {
    final destino = evento?.coordenadas ?? local?.coordenadas;
    if (destino == null) return null;
    return textoDistanciaDesdeUsuario(posicionUsuario, destino);
  }

  String _formatearFecha(DateTime f) {

    final local = f.toLocal();

    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    final meses = [

      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',

      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',

    ];

    final dia = dias[local.weekday - 1];

    final mes = meses[local.month - 1];

    final hh = local.hour.toString().padLeft(2, '0');

    final mm = local.minute.toString().padLeft(2, '0');

    return '$dia ${local.day} $mes · $hh:$mm';

  }

}

class _BadgeDistanciaMapa extends StatelessWidget {
  const _BadgeDistanciaMapa({
    required this.texto,
    this.grande = false,
  });

  final String texto;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, accent, _) {
        return Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: grande ? 14 : 8,
              vertical: grande ? 8 : 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(grande ? 12 : 8),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.my_location,
                  size: grande ? 16 : 11,
                  color: accent,
                ),
                SizedBox(width: grande ? 8 : 4),
                Text(
                  texto,
                  style: GoogleFonts.baloo2(
                    fontSize: grande ? 14 : 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChipPromoCard extends StatelessWidget {

  const _ChipPromoCard();

  @override

  Widget build(BuildContext context) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        Icon(

          CupertinoIcons.gift_fill,

          size: 13,

          color: ColoresApp.flashPromo,

        ),

        const SizedBox(width: 5),

        Text(

          'Promo activa',

          style: GoogleFonts.baloo2(

            fontSize: 11.5,

            fontWeight: FontWeight.w800,

            color: ColoresApp.flashPromo,

          ),

        ),

      ],

    );

  }

}

