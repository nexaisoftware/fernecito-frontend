/// Sheet de recorte circular para foto de perfil (pan + zoom).
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:profile_image_cropper/profile_image_cropper.dart';

import '../core/constants.dart';
import 'fernecito_loader.dart';

/// Muestra vista previa circular con pan/zoom. Devuelve los bytes recortados
/// o `null` si el usuario cancela.
Future<Uint8List?> mostrarRecorteAvatarSheet(
  BuildContext context,
  Uint8List imageBytes,
) async {
  final cropperKey = GlobalKey();
  var recortando = false;

  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        final bottom = MediaQuery.paddingOf(context).bottom;
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (_, __) => Container(
            decoration: SuperficiesApp.bottomSheet(topRadius: 22),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Encuadrá tu foto',
                              style: GoogleFonts.baloo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: ColoresApp.textoPrincipal,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Mové y hacé zoom. Así se verá en tu perfil.',
                              style: GoogleFonts.baloo2(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: ColoresApp.textoSecundario,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed:
                            recortando ? null : () => Navigator.pop(ctx),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        color: ColoresApp.principalMarca,
                        borderRadius: BorderRadius.circular(22),
                        onPressed: recortando
                            ? null
                            : () async {
                                setModalState(() => recortando = true);
                                try {
                                  final result = await ProfileImageCropper.crop(
                                    imageCropperKey: cropperKey,
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx, result);
                                } catch (_) {
                                  if (ctx.mounted) {
                                    setModalState(() => recortando = false);
                                  }
                                }
                              },
                        child: recortando
                            ? const FernecitoLoader.inline(size: 16, color: Colors.white)
                            : Text(
                                'Listo',
                                style: GoogleFonts.baloo2(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ColoredBox(
                        color: ColoresApp.fondoPrincipal,
                        child: ProfileImageCropper(
                          imageCropperKey: cropperKey,
                          image: Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                          ),
                          aspectRatio: 1,
                          overlayType: OverlayType.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
