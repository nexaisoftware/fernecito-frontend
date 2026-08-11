/// Carga un plan por id y navega a [PantallaVerPlan].
library;

import 'package:flutter/cupertino.dart';

import '../PANTALLAS/pantalla_ver_plan.dart';
import 'servicio_planes.dart';

Future<void> abrirPlanCompartidoPorId(
  BuildContext context,
  String idPlan,
) async {
  final id = idPlan.trim();
  if (id.isEmpty || !context.mounted) return;

  final res = await ServicioPlanes().detalle(id);
  if (!context.mounted) return;
  if (res.detalle == null) {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(res.error ?? 'Este plan ya no está disponible.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => PantallaVerPlan(
        idPlan: id,
        inicial: res.detalle!.plan,
      ),
    ),
  );
}
