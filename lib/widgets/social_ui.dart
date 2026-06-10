/// Componentes UI compartidos para Social y perfiles (estilo notificaciones).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

/// Encabezado de sección (título + opcional subtítulo).
class EncabezadoSeccionSocial extends StatelessWidget {
  final String titulo;
  final String? subtitulo;

  const EncabezadoSeccionSocial({
    super.key,
    required this.titulo,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.baloo2(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
              height: 1.2,
            ),
          ),
          if (subtitulo != null && subtitulo!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Superficie tipo card de notificaciones.
class CardSuperficieSocial extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool destacada;
  final EdgeInsetsGeometry padding;

  const CardSuperficieSocial({
    super.key,
    required this.child,
    this.onTap,
    this.destacada = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    final leida = !destacada;

    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ColoresApp.fondoSuperficie.withValues(alpha: 0.95),
          Color.lerp(
            ColoresApp.fondoSuperficie,
            accent.withValues(alpha: 0.14),
            leida ? 0.10 : 0.28,
          )!,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: leida
            ? accent.withValues(alpha: 0.12)
            : accent.withValues(alpha: 0.38),
        width: leida ? 1 : 1.5,
      ),
      boxShadow: leida
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: decoration,
        child: content,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: decoration,
        child: content,
      ),
    );
  }
}

/// Botón primario de acción en pantallas sociales.
class BotonAccionSocial extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback? onTap;
  final bool secundario;

  const BotonAccionSocial({
    super.key,
    required this.texto,
    required this.icono,
    this.onTap,
    this.secundario = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: secundario
              ? ColoresApp.fondoSuperficie.withValues(alpha: 0.9)
              : ColoresApp.principalMarca,
          borderRadius: BorderRadius.circular(50),
          border: secundario
              ? Border.all(color: ColoresApp.principalMarca.withValues(alpha: 0.35))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 18,
              color: secundario ? ColoresApp.principalMarca : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              texto,
              style: GoogleFonts.baloo2(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: secundario ? ColoresApp.textoPrincipal : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar circular con borde de marca.
class AvatarSocial extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback? onTap;

  const AvatarSocial({
    super.key,
    required this.url,
    this.size = 52,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? Icon(CupertinoIcons.person_fill,
                color: ColoresApp.textoSecundario, size: size * 0.45)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => const CupertinoActivityIndicator(),
                errorWidget: (_, __, ___) => Icon(CupertinoIcons.person_fill,
                    color: ColoresApp.textoSecundario, size: size * 0.45),
              ),
      ),
    );

    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// Candado sobre el avatar (perfil privado, no amigo).
class InsigniaCandadoPrivado extends StatelessWidget {
  final double avatarSize;

  const InsigniaCandadoPrivado({super.key, required this.avatarSize});

  @override
  Widget build(BuildContext context) {
    final badge = (avatarSize * 0.34).clamp(14.0, 22.0);
    final icon = badge * 0.52;
    return Positioned(
      right: -2,
      bottom: -1,
      child: Container(
        width: badge,
        height: badge,
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie,
          shape: BoxShape.circle,
          border: Border.all(
            color: ColoresApp.principalMarca.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          CupertinoIcons.lock_fill,
          size: icon,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }
}

/// Avatar social con candado opcional (perfil privado visible pero restringido).
class AvatarSocialPrivacidad extends StatelessWidget {
  final String url;
  final double size;
  final bool mostrarCandado;
  final VoidCallback? onTap;

  const AvatarSocialPrivacidad({
    super.key,
    required this.url,
    this.size = 52,
    this.mostrarCandado = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarSocial(url: url, size: size, onTap: onTap),
        if (mostrarCandado) InsigniaCandadoPrivado(avatarSize: size),
      ],
    );
  }
}

/// Métrica compacta (actividad, ubicación, etc.) en grid del perfil.
class ChipMetricaPerfil extends StatelessWidget {
  final Widget icono;
  final String etiqueta;
  final String valor;

  const ChipMetricaPerfil({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColoresApp.principalMarca.withValues(alpha: 0.14),
            ),
            child: IconTheme(
              data: IconThemeData(
                size: 16,
                color: ColoresApp.principalMarca,
              ),
              child: icono,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                    height: 1.1,
                  ),
                ),
                Text(
                  etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar con glow de marca (sin borde duro). Para explorar y listas.
class AvatarSocialGlow extends StatelessWidget {
  final String url;
  final double size;

  const AvatarSocialGlow({
    super.key,
    required this.url,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.42),
            blurRadius: size * 0.22,
            spreadRadius: size * 0.02,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: size * 0.38,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: url.isEmpty
            ? ColoredBox(
                color: ColoresApp.fondoSuperficie,
                child: Icon(
                  CupertinoIcons.person_fill,
                  color: ColoresApp.textoSecundario,
                  size: size * 0.42,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: ColoresApp.fondoSuperficie,
                  child: CupertinoActivityIndicator(radius: size * 0.12),
                ),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: ColoresApp.fondoSuperficie,
                  child: Icon(
                    CupertinoIcons.person_fill,
                    color: ColoresApp.textoSecundario,
                    size: size * 0.42,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Toggle segmentado compacto (estilo minimalista de cartelera/notificaciones).
class ToggleSegmentadoSocial extends StatelessWidget {
  final List<String> opciones;
  final int indice;
  final ValueChanged<int> onChanged;

  const ToggleSegmentadoSocial({
    super.key,
    required this.opciones,
    required this.indice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: accent.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: List.generate(opciones.length, (i) {
              final activo = i == indice;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: activo ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: activo
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      opciones[i],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: activo ? Colors.white : ColoresApp.textoSecundario,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Barra de búsqueda compacta (pill). Por defecto es "tap para abrir";
/// si se pasa [controller] funciona como campo de texto inline.
class BarraBusquedaSocial extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final Widget? trailing;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const BarraBusquedaSocial({
    super.key,
    required this.hint,
    this.onTap,
    this.trailing,
    this.controller,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    final esCampo = controller != null;

    final pill = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 19, color: ColoresApp.textoPrincipal),
          const SizedBox(width: 10),
          Expanded(
            child: esCampo
                ? CupertinoTextField(
                    controller: controller,
                    autofocus: autofocus,
                    onSubmitted: onSubmitted,
                    onChanged: onChanged,
                    placeholder: hint,
                    placeholderStyle: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: ColoresApp.textoSecundario,
                    ),
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ColoresApp.textoPrincipal,
                    ),
                    cursorColor: accent,
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(),
                  )
                : Text(
                    hint,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
          ),
        ],
      ),
    );

    final tappable = (onTap != null && !esCampo)
        ? GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: pill)
        : pill;

    if (trailing == null) return tappable;
    return Row(
      children: [
        Expanded(child: tappable),
        const SizedBox(width: 10),
        trailing!,
      ],
    );
  }
}

/// Botón circular compacto (ej: crear squad) con relleno de marca.
class BotonCircularSocial extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final double size;
  final bool relleno;

  const BotonCircularSocial({
    super.key,
    required this.icono,
    this.onTap,
    this.size = 44,
    this.relleno = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColoresApp.principalMarca;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: relleno ? accent : ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
          border: relleno ? null : Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Icon(
          icono,
          size: size * 0.5,
          color: relleno ? Colors.white : accent,
        ),
      ),
    );
  }
}

/// Chip compacto de username, estado o etiquetas.
class ChipSocial extends StatelessWidget {
  final String texto;
  final Color? color;

  const ChipSocial({super.key, required this.texto, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? ColoresApp.principalMarca;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.baloo2(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}
