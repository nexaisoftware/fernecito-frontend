library;

import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import '../PANTALLAS/pantalla_local_perfil.dart';
import '../core/constants.dart';
import '../core/servicio_locales_megusta.dart';
import '../core/supabase_client.dart';
import 'avatar_local.dart';

/// Fila scrolleable de avatars de locales con me gusta (perfil de usuario).
class CarruselLugaresMegusta extends StatelessWidget {
  const CarruselLugaresMegusta({
    super.key,
    required this.items,
    this.vacioTexto = 'Todavía no marcó lugares con me gusta',
  });

  final List<LocalMegustaItem> items;
  final String vacioTexto;
  static const _doradoPionero = AvatarLocal.doradoPionero;

  String _avatarUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http')) return path;
    return ServicioSupabase().cliente.storage
        .from('avatars_locales')
        .getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.heart_fill,
                size: 15,
                color: const Color(0xFFE91E63),
              ),
              const SizedBox(width: 6),
              Text(
                'Lugares que le gusta',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                Text(
                  '${items.length}',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              vacioTexto,
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textoSecundario,
              ),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final avatar = _avatarUrl(item.fotoPerfilUrl);
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => PantallaLocalPerfil(
                            avatarUrl: avatar,
                            nombreLocal: item.nombreLocal,
                            idLocal: item.idLocal,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AvatarLocal(
                              imageUrl: avatar,
                              size: 52,
                              esPionero: item.esPionero,
                            ),
                            if (item.verificado)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: ColoresApp.fondoSuperficie,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    size: 12,
                                    color: item.esPionero
                                        ? _doradoPionero
                                        : ColoresApp.principalMarca,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(
                            item.nombreLocal,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
