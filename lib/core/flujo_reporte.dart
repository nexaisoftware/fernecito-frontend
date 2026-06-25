import 'package:flutter/cupertino.dart';

import 'servicio_reportes.dart';

/// Flujo unificado de reporte para toda la app (perfiles de usuario, locales y
/// publicaciones). Pasos: elegir motivo → CONFIRMAR el envío → enviar → modal
/// de "Gracias por tu reporte".
///
/// [entidad]: sustantivo para los textos ('este perfil', 'este local',
/// 'este evento'). [targetTipo]: 'usuario' | 'local' | 'evento'.
Future<void> mostrarFlujoReporte({
  required BuildContext context,
  required String entidad,
  required String targetTipo,
  required String targetId,
  String reportanteTipo = 'usuario',
}) async {
  if (targetId.trim().isEmpty) return;

  // 1) Elegir motivo
  final motivo = await showCupertinoModalPopup<MotivoReporte>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text('Reportar $entidad'),
      message: const Text('Elegí el motivo principal del reporte.'),
      actions: motivosReporteCuenta
          .map(
            (m) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(m.label),
            ),
          )
          .toList(),
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancelar'),
      ),
    ),
  );
  if (motivo == null || !context.mounted) return;

  // 2) Confirmar el envío
  final confirmado = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Confirmar reporte'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Vas a reportar $entidad por "${motivo.label}".\n¿Querés enviar el reporte?',
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enviar reporte'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return;

  // 3) Enviar (capturamos errores de red / 401 para no romper con excepción)
  Map<String, dynamic> res;
  try {
    res = await ServicioReportes().reportarCuenta(
      reportanteTipo: reportanteTipo,
      targetTipo: targetTipo,
      targetId: targetId,
      motivo: motivo.codigo,
    );
  } catch (e) {
    final s = e.toString().toLowerCase();
    final noAuth =
        s.contains('not_authenticated') ||
        s.contains('401') ||
        s.contains('unauthorized');
    res = {
      'ok': false,
      'error': noAuth
          ? 'Iniciá sesión para poder reportar.'
          : 'No se pudo enviar el reporte. Revisá tu conexión e intentá de nuevo.',
    };
  }
  if (!context.mounted) return;

  // 4) Modal de gracias (o error)
  final ok = res['ok'] == true;
  await showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(ok ? 'Gracias por tu reporte' : 'No se pudo enviar'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          ok
              ? 'Analizaremos $entidad y tomaremos medidas para que Fernecito siga siendo una plataforma segura.'
              : (res['error']?.toString() ??
                    'Intentá de nuevo en unos momentos.'),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
