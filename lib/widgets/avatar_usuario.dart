/// Avatar circular reutilizable tipo Instagram/WhatsApp.
/// Imagen con center crop (BoxFit.cover), borde siempre visible y sombra.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../core/constants.dart';
import 'avatar_bordes.dart';
import 'fernecito_loader.dart';

/// Borde blanco estándar (rompehielo, stacks de squad, hero de perfil).
class AvatarBordeBlanco extends StatelessWidget {
  final String avatar;
  final double size;
  final VoidCallback? onTap;
  final bool esPionero;

  static const double bordeAncho = 2.5;

  const AvatarBordeBlanco({
    super.key,
    required this.avatar,
    required this.size,
    this.onTap,
    this.esPionero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AvatarUsuario(
        avatar: avatar,
        size: size,
        onTap: onTap,
        esPionero: esPionero,
        borderColor: AvatarBordes.blanco,
        borderWidth: bordeAncho,
      ),
    );
  }
}

/// Avatar circular con borde (siempre), sombra y center crop.
/// [avatar] puede ser URL de red o path asset (assets/...).
/// [size] diámetro del círculo. Por defecto 112.
/// [onTap] opcional para abrir visualizador o acción.
/// Pionero → borde dorado. Si no, [borderColor] o blanco por defecto.
class AvatarUsuario extends StatelessWidget {
  final String avatar;
  final double size;
  final VoidCallback? onTap;
  final bool esPionero;
  final Color? borderColor;
  final double? borderWidth;

  const AvatarUsuario({
    super.key,
    required this.avatar,
    this.size = 112,
    this.onTap,
    this.esPionero = false,
    this.borderColor,
    this.borderWidth,
  });

  static bool _esAsset(String url) => url.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final bc = AvatarBordes.color(
      esPionero: esPionero,
      preferido: borderColor ?? AvatarBordes.blanco,
    );
    final bw = AvatarBordes.ancho(
      esPionero: esPionero,
      preferido: borderWidth,
    );

    final content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: bc, width: bw),
        boxShadow: [
          BoxShadow(
            color: ColoresApp.principalMarca.withValues(alpha: 0.28),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
        color: ColoresApp.fondoSuperficie,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar.isEmpty
          ? Icon(
              CupertinoIcons.person_fill,
              size: size * 0.4,
              color: ColoresApp.textoSecundario,
            )
          : _esAsset(avatar)
              ? Image.asset(
                  avatar,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => _placeholder(size),
                )
              : CachedNetworkImage(
                  imageUrl: avatar,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  placeholder: (_, _) => const FernecitoLoaderCentro(),
                  errorWidget: (_, _, _) => _placeholder(size),
                ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  static Widget _placeholder(double size) => Icon(
        CupertinoIcons.person_fill,
        size: size * 0.4,
        color: ColoresApp.textoSecundario,
      );
}
