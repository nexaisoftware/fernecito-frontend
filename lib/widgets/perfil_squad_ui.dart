/// UI compartida para perfil squad (público) y mi squad (editable).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../models/social.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/social_ui.dart';
import '../widgets/stack_avatares_squad.dart';

/// Altura estándar del hero (70 % pantalla). Contenido + miembros viven acá.
double squadHeroAltura(BuildContext context) =>
    MediaQuery.sizeOf(context).height * 0.70;

/// Padding inferior para no tapar botones con la navbar.
double squadPaddingInferior(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 100;

/// Zona hero 70 %: banner + username + nombre + miembros (comprimido o grilla) + vibe.
class SquadHeroZona extends StatelessWidget {
  const SquadHeroZona({
    super.key,
    required this.height,
    this.imageUrl,
    required this.topBar,
    required this.title,
    this.usernameBadge,
    required this.miembros,
    required this.miembrosExpandidos,
    required this.onToggleMiembros,
    this.vibe,
    this.onMiembroTap,
    this.miembroMostrarCandado,
    this.trailingBuilder,
    this.subiendo = false,
    this.onBannerTap,
    this.imageCacheKey,
  });

  final double height;
  final String? imageUrl;
  /// Fuerza recarga si la URL pública no cambia (upsert en storage).
  final String? imageCacheKey;
  final Widget topBar;
  final Widget title;
  final Widget? usernameBadge;
  final List<MiembroSquad> miembros;
  final bool miembrosExpandidos;
  final VoidCallback onToggleMiembros;
  final Widget? vibe;
  final void Function(MiembroSquad)? onMiembroTap;
  final bool Function(MiembroSquad m)? miembroMostrarCandado;
  final Widget? Function(MiembroSquad m)? trailingBuilder;
  final bool subiendo;
  final VoidCallback? onBannerTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';

    return SizedBox(
      width: double.infinity,
      height: height,
      child: GestureDetector(
        onTap: onBannerTap,
        behavior:
            onBannerTap != null ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              CachedNetworkImage(
                imageUrl: url,
                cacheKey: imageCacheKey ?? url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
            else
              _placeholder(),
            Container(color: Colors.black.withValues(alpha: 0.40)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height * 0.28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.black.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: height * 0.38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      ColoresApp.fondoPrincipal.withValues(alpha: 0.45),
                      ColoresApp.fondoPrincipal.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
            if (subiendo)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: CupertinoActivityIndicator(color: Colors.white, radius: 18),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topBar,
                  if (usernameBadge != null) ...[
                    const SizedBox(height: 6),
                    Center(child: usernameBadge!),
                  ],
                  const SizedBox(height: 6),
                  title,
                  const SizedBox(height: 6),
                  Expanded(
                    child: _zonaMiembros(context),
                  ),
                  if (miembrosExpandidos) const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zonaMiembros(BuildContext context) {
    if (miembros.isEmpty) {
      return Center(
        child: Text(
          'Sin miembros todavía',
          style: GoogleFonts.baloo2(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      );
    }

    if (miembrosExpandidos) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Miembros',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: onToggleMiembros,
                  child: Text(
                    'Comprimir',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SquadGridMiembrosAlternado(
              miembros: miembros,
              scrollable: true,
              expandido: true,
              onMiembroTap: onMiembroTap,
              miembroMostrarCandado: miembroMostrarCandado,
              trailingBuilder: trailingBuilder,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onToggleMiembros,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SquadStackMiembrosComprimido(
            miembros: miembros,
            onTap: onToggleMiembros,
          ),
          if (vibe != null) vibe!,
          SquadStackMiembrosComprimido.leyendaCantidad(miembros.length),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: ColoresApp.fondoSuperficie,
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.person_3_fill,
        size: 72,
        color: ColoresApp.principalMarca.withValues(alpha: 0.35),
      ),
    );
  }
}

class SquadBotonVolver extends StatelessWidget {
  final VoidCallback onTap;
  final Widget? trailing;

  const SquadBotonVolver({super.key, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onTap,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class SquadBadgeUsername extends StatelessWidget {
  const SquadBadgeUsername({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    if (username.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        username.startsWith('@') ? username : '@$username',
        style: GoogleFonts.baloo2(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class SquadTituloHero extends StatelessWidget {
  final String texto;
  final Widget? editor;

  const SquadTituloHero({super.key, required this.texto, this.editor});

  static TextStyle estiloHero = GoogleFonts.baloo2(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    height: 1.08,
    shadows: const [
      Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (editor != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: editor,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: estiloHero,
      ),
    );
  }
}

/// Avatar de miembro en hero squad: borde blanco fijo (stack y grilla expandida).
class SquadAvatarHero extends StatelessWidget {
  const SquadAvatarHero({
    super.key,
    required this.url,
    required this.size,
  });

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AvatarBordeBlanco(avatar: url, size: size);
  }
}

class SquadStackMiembrosComprimido extends StatelessWidget {
  const SquadStackMiembrosComprimido({
    super.key,
    required this.miembros,
    required this.onTap,
  });

  final List<MiembroSquad> miembros;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 100.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StackAvataresSquad(
            avatares: miembros.map((m) => m.avatarUrl ?? '').toList(),
            totalExtra: miembros.length,
            size: size,
          ),
        ],
      ),
    );
  }

  /// Leyenda debajo del stack (separada para poder intercalar el vibe).
  static Widget leyendaCantidad(int cantidad) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$cantidad miembro${cantidad == 1 ? '' : 's'} · Ver todos',
        style: GoogleFonts.baloo2(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

/// Grilla 2-3-2-3 con celdas del mismo ancho (base 3 columnas).
class SquadGridMiembrosAlternado extends StatelessWidget {
  const SquadGridMiembrosAlternado({
    super.key,
    required this.miembros,
    this.onMiembroTap,
    this.miembroMostrarCandado,
    this.trailingBuilder,
    this.scrollable = false,
    this.expandido = false,
  });

  final List<MiembroSquad> miembros;
  final void Function(MiembroSquad)? onMiembroTap;
  final bool Function(MiembroSquad m)? miembroMostrarCandado;
  final Widget? Function(MiembroSquad m)? trailingBuilder;
  final bool scrollable;
  final bool expandido;

  static const double _hp = 16;
  static const double _gap = 12;

  static List<List<int>> _filasAlternadas(int n) {
    final filas = <List<int>>[];
    var i = 0;
    var cols = 2;
    while (i < n) {
      final fila = <int>[];
      for (var c = 0; c < cols && i < n; c++) {
        fila.add(i++);
      }
      filas.add(fila);
      cols = cols == 2 ? 3 : 2;
    }
    return filas;
  }

  @override
  Widget build(BuildContext context) {
    if (miembros.isEmpty) return const SizedBox.shrink();

    final w = MediaQuery.sizeOf(context).width;
    final cellW = (w - _hp * 2 - _gap * 2) / 3;
    final avatarSize = expandido
        ? (cellW * 0.88).clamp(72.0, 108.0)
        : (cellW * 0.72).clamp(48.0, 64.0);
    final fontUser = expandido ? 12.0 : 10.0;
    final filas = _filasAlternadas(miembros.length);
    final rowH = avatarSize + (expandido ? 36.0 : 28.0);

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: filas.map((indices) {
        return Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: indices.map((idx) {
              final m = miembros[idx];
              final trailing = trailingBuilder?.call(m);
              final extraH = trailing != null ? (expandido ? 26.0 : 22.0) : 0.0;
              return Padding(
                padding: EdgeInsets.only(
                  right: idx != indices.last ? _gap : 0,
                ),
                child: SizedBox(
                  width: cellW,
                  height: rowH + extraH,
                  child: _CeldaMiembroCompacta(
                    miembro: m,
                    avatarSize: avatarSize,
                    fontSizeUser: fontUser,
                    mostrarCandado: miembroMostrarCandado?.call(m) ?? false,
                    onTap: onMiembroTap == null ? null : () => onMiembroTap!(m),
                    trailing: trailing,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );

    if (scrollable) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: _hp),
        physics: const BouncingScrollPhysics(),
        child: grid,
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(horizontal: _hp), child: grid);
  }
}

class _CeldaMiembroCompacta extends StatelessWidget {
  const _CeldaMiembroCompacta({
    required this.miembro,
    required this.avatarSize,
    this.fontSizeUser = 10,
    this.mostrarCandado = false,
    this.onTap,
    this.trailing,
  });

  final MiembroSquad miembro;
  final double avatarSize;
  final double fontSizeUser;
  final bool mostrarCandado;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final user = miembro.username.startsWith('@')
        ? miembro.username
        : '@${miembro.username}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SquadAvatarHero(url: miembro.avatarUrl ?? '', size: avatarSize),
              if (mostrarCandado)
                InsigniaCandadoPrivado(avatarSize: avatarSize),
              if (miembro.esLider)
                Positioned(
                  top: -2,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.star_fill,
                          size: avatarSize > 80 ? 10 : 8,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Líder',
                          style: GoogleFonts.baloo2(
                            fontSize: avatarSize > 80 ? 9 : 7,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            user,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: fontSizeUser,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class SquadCardDescripcion extends StatelessWidget {
  const SquadCardDescripcion({
    super.key,
    required this.texto,
    this.editor,
    this.onEditar,
  });

  final String texto;
  final Widget? editor;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    return CardSuperficieSocial(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Descripción',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ),
              if (onEditar != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: onEditar,
                  child: Icon(
                    CupertinoIcons.pencil,
                    size: 16,
                    color: ColoresApp.principalMarca,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          editor ??
              Text(
                texto,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: ColoresApp.textoSecundario,
                  height: 1.4,
                ),
              ),
        ],
      ),
    );
  }
}

class SquadBadgeUbicacion extends StatelessWidget {
  const SquadBadgeUbicacion({super.key, required this.ubicacion});

  final String ubicacion;

  @override
  Widget build(BuildContext context) {
    if (ubicacion.trim().isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.location_solid,
              size: 12,
              color: ColoresApp.textoSecundario.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 5),
            Text(
              ubicacion,
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
    );
  }
}
