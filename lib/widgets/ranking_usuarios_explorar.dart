/// Podio semanal de usuarios para Explorar — mismo lenguaje visual que las
/// tendencias de locales del hub Social (oro / plata / bronce), con el
/// primer nombre abajo y la burbuja de estado.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_ranking_usuarios.dart';

class RankingUsuariosExplorar extends StatelessWidget {
  const RankingUsuariosExplorar({
    super.key,
    required this.usuarios,
    required this.onTapUsuario,
    this.cargando = false,
  });

  final List<UsuarioRanking> usuarios;
  final void Function(UsuarioRanking) onTapUsuario;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CupertinoActivityIndicator(radius: 10)),
      );
    }
    if (usuarios.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                'Personas populares',
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoPrincipal,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: usuarios.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _UsuarioRankingItem(
              posicion: i + 1,
              usuario: usuarios[i],
              onTap: () => onTapUsuario(usuarios[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsuarioRankingItem extends StatelessWidget {
  const _UsuarioRankingItem({
    required this.posicion,
    required this.usuario,
    required this.onTap,
  });

  static const _oro = Color(0xFFFFD54A);
  static const _plata = Color(0xFFC9CED6);
  static const _bronce = Color(0xFFD08A45);

  final int posicion;
  final UsuarioRanking usuario;
  final VoidCallback onTap;

  Color get _acento => switch (posicion) {
    1 => _oro,
    2 => _plata,
    3 => _bronce,
    _ => ColoresApp.principalMarca,
  };

  @override
  Widget build(BuildContext context) {
    final foto = usuario.fotoUrl;
    final acento = _acento;
    final esPodio = posicion <= 3;
    final estado = usuario.estado?.trim();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            SizedBox(
              height: 53,
              width: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 14,
                    top: 1,
                    child: Container(
                      width: 52,
                      height: 52,
                      padding: EdgeInsets.all(esPodio ? 2.5 : 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: acento,
                        boxShadow: [
                          BoxShadow(
                            color: acento.withValues(
                              alpha: esPodio ? 0.36 : 0.24,
                            ),
                            blurRadius: esPodio ? 9 : 7,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: ColoresApp.fondoSuperficie,
                          child: foto != null && foto.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: foto,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _avatarVacio(),
                                  placeholder: (_, _) => _avatarVacio(),
                                )
                              : _avatarVacio(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(
                      '$posicion',
                      style: GoogleFonts.baloo2(
                        fontSize: 28,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        color: acento,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              usuario.nombreCorto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            if (estado != null && estado.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  estado,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    color: ColoresApp.textoSecundario,
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatarVacio() => const Center(
    child: Icon(CupertinoIcons.person_fill, size: 22, color: Colors.white38),
  );
}
