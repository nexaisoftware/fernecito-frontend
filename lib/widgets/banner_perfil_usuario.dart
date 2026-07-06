/// Banner hero para perfiles de usuario (más bajo que el de locales).
library;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

/// Altura del banner según pantalla, safe area y si hay redes visibles.
double alturaBannerPerfilUsuario(
  Size screenSize,
  EdgeInsets padding, {
  bool conRedes = false,
}) {
  var nucleo = 228.0;
  if (conRedes) nucleo += 36.0;
  final minima = padding.top + nucleo + 20.0;
  final proporcional = screenSize.height * (conRedes ? 0.41 : 0.38);
  return proporcional.clamp(minima, 450.0);
}

/// Badge «Amigos» para el banner de perfil.
class BadgeAmigosPerfil extends StatelessWidget {
  const BadgeAmigosPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: ColoresApp.principalMarca.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.checkmark_seal_fill,
            size: 13,
            color: ColoresApp.principalMarca,
          ),
          const SizedBox(width: 5),
          Text(
            'Amigos',
            style: GoogleFonts.baloo2(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: ColoresApp.principalMarca,
            ),
          ),
        ],
      ),
    );
  }
}

/// Iconos de redes sociales con glow para el banner (estilo local).
class RedesSocialesBannerPerfil extends StatelessWidget {
  final String? instagramUrl;
  final String? tiktokUrl;
  final VoidCallback? onInstagram;
  final VoidCallback? onTikTok;

  const RedesSocialesBannerPerfil({
    super.key,
    this.instagramUrl,
    this.tiktokUrl,
    this.onInstagram,
    this.onTikTok,
  });

  @override
  Widget build(BuildContext context) {
    final igOk = (instagramUrl ?? '').trim().isNotEmpty;
    final ttOk = (tiktokUrl ?? '').trim().isNotEmpty;

    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 400;
    final sz = isNarrow ? 20.0 : 22.0;
    final sep = SizedBox(width: isNarrow ? 18 : 22);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconoRedBanner(
          icon: FontAwesomeIcons.instagram,
          useFontAwesome: true,
          size: sz,
          activo: igOk,
          onTap: igOk ? onInstagram : null,
        ),
        sep,
        _IconoRedBanner(
          icon: FontAwesomeIcons.tiktok,
          useFontAwesome: true,
          size: sz,
          activo: ttOk,
          onTap: ttOk ? onTikTok : null,
        ),
      ],
    );
  }
}

class _IconoRedBanner extends StatefulWidget {
  final IconData icon;
  final bool useFontAwesome;
  final double size;
  final bool activo;
  final VoidCallback? onTap;

  const _IconoRedBanner({
    required this.icon,
    this.useFontAwesome = false,
    this.size = 22,
    this.activo = true,
    this.onTap,
  });

  @override
  State<_IconoRedBanner> createState() => _IconoRedBannerState();
}

class _IconoRedBannerState extends State<_IconoRedBanner> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tam = widget.size + 4;

    if (!widget.activo) {
      return SizedBox(
        width: tam,
        height: tam,
        child: Center(
          child: Opacity(
            opacity: 0.25,
            child: widget.useFontAwesome
                ? FaIcon(
                    widget.icon,
                    size: widget.size,
                    color: Colors.white,
                  )
                : Icon(
                    widget.icon,
                    size: widget.size,
                    color: Colors.white,
                  ),
          ),
        ),
      );
    }

    return SizedBox(
      width: tam,
      height: tam,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.88 : 1.0,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ColoresApp.principalMarca.withValues(
                      alpha: _pressed ? 0.65 : 0.45,
                    ),
                    blurRadius: _pressed ? 14 : 10,
                    spreadRadius: _pressed ? 1.2 : 0.6,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.useFontAwesome
                  ? FaIcon(
                      widget.icon,
                      size: widget.size,
                      color: Colors.white,
                    )
                  : Icon(
                      widget.icon,
                      size: widget.size,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner con foto de fondo (avatar blur), degradado inferior y slots de contenido.
class BannerPerfilUsuario extends StatelessWidget {
  final String imagenFondo;
  final Widget avatar;
  final Widget nombre;
  final Widget? debajoNombre;
  final Widget estado;
  final Widget? redesSociales;
  final bool conRedesSociales;
  final Widget? leading;
  final Widget? trailing;
  final Widget? accionBanner;

  const BannerPerfilUsuario({
    super.key,
    required this.imagenFondo,
    required this.avatar,
    required this.nombre,
    required this.estado,
    this.debajoNombre,
    this.redesSociales,
    this.conRedesSociales = false,
    this.leading,
    this.trailing,
    this.accionBanner,
  });

  static bool _esAsset(String url) => url.startsWith('assets/');

  Widget _fondoReserva(String urlBlur) {
    if (urlBlur.isNotEmpty && !_esAsset(urlBlur)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: ColoresApp.fondoPrincipal),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Opacity(
              opacity: 0.5,
              child: CachedNetworkImage(
                imageUrl: urlBlur,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const SizedBox.expand(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      );
    }
    return const ColoredBox(color: ColoresApp.fondoPrincipal);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bannerHeight = alturaBannerPerfilUsuario(
      size,
      padding,
      conRedes: conRedesSociales,
    );
    final isNarrow = size.width < 400;
    final horizontalPadding = isNarrow ? 16.0 : 24.0;
    final fondo = imagenFondo.trim().isNotEmpty ? imagenFondo.trim() : '';
    final reservaPie = conRedesSociales ? 38.0 : 0.0;

    return SizedBox(
      width: double.infinity,
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 0.82, 1.0],
                colors: [
                  Colors.white,
                  Colors.white,
                  Color(0x4DFFFFFF),
                  Colors.transparent,
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fondo.isEmpty
                      ? _fondoReserva('')
                      : _esAsset(fondo)
                          ? Image.asset(
                              fondo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _fondoReserva(''),
                            )
                          : CachedNetworkImage(
                              imageUrl: fondo,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(
                                milliseconds: 280,
                              ),
                              placeholder: (_, __) => _fondoReserva(fondo),
                              errorWidget: (_, __, ___) => _fondoReserva(fondo),
                            ),
                  Container(
                    color: Colors.black.withValues(alpha: 0.58),
                  ),
                ],
              ),
            ),
          ),
          if (leading != null)
            Positioned(
              top: padding.top + 4,
              left: horizontalPadding - 6,
              child: leading!,
            ),
          if (trailing != null)
            Positioned(
              top: padding.top + 4,
              right: horizontalPadding - 10,
              child: trailing!,
            ),
          if (accionBanner != null)
            Positioned(
              top: padding.top + 4,
              right: horizontalPadding - 10,
              child: accionBanner!,
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                padding.top + 36,
                horizontalPadding,
                10 + reservaPie,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: size.width - horizontalPadding * 2,
                        maxHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          avatar,
                          const SizedBox(height: 9),
                          nombre,
                          if (debajoNombre != null) ...[
                            const SizedBox(height: 4),
                            debajoNombre!,
                          ],
                          const SizedBox(height: 5),
                          estado,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (conRedesSociales && redesSociales != null)
            Positioned(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: 12,
              child: Center(child: redesSociales!),
            ),
        ],
      ),
    );
  }
}
