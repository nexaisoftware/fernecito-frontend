/// Valores canónicos de `perfiles_usuarios.sexo` (alineados con push owner).
library;

import 'package:flutter/cupertino.dart';

import '../widgets/dialogo_fernecito.dart';

class SexoPerfil {
  SexoPerfil._();

  static const hombre = 'hombre';
  static const mujer = 'mujer';
  static const otro = 'otro';

  static const List<String> opciones = [hombre, mujer, otro];

  static String etiqueta(String valor) => switch (valor) {
    hombre => 'Hombre',
    mujer => 'Mujer',
    otro => 'Otro',
    _ => 'Género',
  };

  static String? normalizar(dynamic raw) {
    final v = raw?.toString().trim().toLowerCase() ?? '';
    if (v.isEmpty) return null;
    if (opciones.contains(v)) return v;
    if (v == 'femenino' || v == 'f') return mujer;
    if (v == 'masculino' || v == 'm') return hombre;
    return null;
  }

  static bool esValido(String? valor) =>
      valor != null && opciones.contains(valor);
}

/// Modal con menú Hombre / Mujer / Otro (+ Después).
/// Devuelve el valor canónico o `null` si eligió Después / cerró.
Future<String?> mostrarDialogoPedirSexo(
  BuildContext context, {
  String titulo = 'Agregá tu género para mejores recomendaciones',
  String mensaje =
      'Nos ayuda a personalizar Match y recomendaciones. Podés cambiarlo después en Mi perfil.',
  bool permitirDespues = true,
}) {
  return showFernecitoDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DialogoFernecito(
      title: Text(titulo),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(mensaje),
      ),
      actions: [
        for (final valor in SexoPerfil.opciones)
          AccionDialogoFernecito(
            onPressed: () => Navigator.of(ctx).pop(valor),
            child: Text(SexoPerfil.etiqueta(valor)),
          ),
        if (permitirDespues)
          AccionDialogoFernecito(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Después'),
          ),
      ],
    ),
  );
}
