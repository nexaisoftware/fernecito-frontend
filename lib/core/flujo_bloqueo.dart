import 'package:flutter/cupertino.dart';

import '../widgets/dialogo_fernecito.dart';
import 'servicio_bloqueos.dart';

/// Flujo simple de bloqueo (perfiles de usuario y locales), en el mismo estilo
/// que el flujo de reporte: CONFIRMAR → bloquear → aviso.
///
/// [entidad]: sustantivo para los textos ('este perfil', 'este local',
/// 'este squad').
/// [targetTipo]: 'usuario' | 'local' | 'squad'.
/// Devuelve true si el bloqueo se concretó (para que la pantalla oculte/retroceda).
Future<bool> mostrarFlujoBloqueo({
  required BuildContext context,
  required String entidad,
  required String targetTipo,
  required String targetId,
}) async {
  if (targetId.trim().isEmpty) return false;

  // 1) Confirmar
  final confirmado = await showFernecitoDialog<bool>(
    context: context,
    builder: (ctx) => DialogoFernecito(
      title: const Text('¿Bloquear?'),
      content: Text(
        'Si bloqueás $entidad, no van a poder contactarte ni interactuar con vos, '
        'y dejarás de ver su contenido.',
      ),
      actions: [
        AccionDialogoFernecito(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        AccionDialogoFernecito(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return false;

  // 2) Bloquear (capturamos errores para no romper con excepción)
  bool ok = false;
  String? error;
  try {
    final res = await ServicioBloqueos().bloquearCuenta(
      targetTipo: targetTipo,
      targetId: targetId,
    );
    ok = res['ok'] == true;
    error = res['error']?.toString();
  } catch (e) {
    final s = e.toString().toLowerCase();
    final noAuth =
        s.contains('no_auth') ||
        s.contains('401') ||
        s.contains('unauthorized');
    error = noAuth
        ? 'Iniciá sesión para poder bloquear.'
        : 'No se pudo bloquear. Revisá tu conexión e intentá de nuevo.';
  }
  if (!context.mounted) return ok;

  // 3) Aviso final
  await showFernecitoDialog<void>(
    context: context,
    builder: (ctx) => DialogoFernecito(
      title: Text(ok ? 'Cuenta bloqueada' : 'No se pudo bloquear'),
      content: Text(
        ok
            ? 'Ya no vas a ver ni recibir interacciones de $entidad.'
            : (error ?? 'Intentá de nuevo en unos momentos.'),
      ),
      actions: [
        AccionDialogoFernecito(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
  return ok;
}
