library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import 'stack_avatares_squad.dart';

/// App bar unificada para chats: back + avatar/nombre touchable + trailing opcional.
class EncabezadoChat extends StatelessWidget {
  const EncabezadoChat({
    super.key,
    required this.nombre,
    required this.onBack,
    this.subtitulo,
    this.fotoUrl,
    this.avataresSquad = const [],
    this.miembrosExtraStack = 0,
    this.esSquad = false,
    this.onTapPerfil,
    this.trailing,
    this.mostrarBadgeSquad = false,
  });

  final String nombre;
  final String? subtitulo;
  final String? fotoUrl;
  final List<String> avataresSquad;
  final int miembrosExtraStack;
  final bool esSquad;
  final VoidCallback onBack;
  final VoidCallback? onTapPerfil;
  final Widget? trailing;
  final bool mostrarBadgeSquad;

  static const _avatarSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final urlsSquad = avataresSquad.where((u) => u.trim().isNotEmpty).toList();
    final esSquadStack = esSquad && urlsSquad.isNotEmpty;
    final foto = fotoUrl?.trim();

    Widget avatar;
    if (esSquadStack) {
      avatar = StackAvataresSquad(
        avatares: urlsSquad,
        totalExtra: miembrosExtraStack,
        size: _avatarSize,
        paddingExterno: 0,
      );
    } else {
      avatar = Container(
        width: _avatarSize,
        height: _avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2A2A),
          image: foto != null && foto.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(foto),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: foto == null || foto.isEmpty
            ? Text(esSquad ? '👥' : '🙋', style: const TextStyle(fontSize: 20))
            : null,
      );
    }

    final perfil = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapPerfil,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                              fontSize: 17,
                              height: 1.12,
                            ),
                          ),
                        ),
                        if (mostrarBadgeSquad) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Squads',
                              style: GoogleFonts.baloo2(
                                color: const Color(0xFFD4C4F7),
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((subtitulo ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitulo!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.principalMarca.withValues(alpha: 0.88),
                          fontSize: 13,
                          height: 1.18,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTapPerfil != null) ...[
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Container(
      color: ColoresApp.fondoPrincipal,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: onBack,
            child: Icon(
              CupertinoIcons.chevron_back,
              color: ColoresApp.principalMarca,
              size: 28,
            ),
          ),
          Expanded(child: perfil),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
