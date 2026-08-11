/// URLs, mensajes y acción de compartir planes (espejo de eventos).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_redirect.dart';

/// URL pública con preview (OG) para WhatsApp / redes.
String urlPreviewCompartirPlan(String idPlan) {
  final id = Uri.encodeComponent(idPlan);
  const shareBaseDefine = String.fromEnvironment('URL_SHARE_PLAN');
  final shareBase = shareBaseDefine.isNotEmpty
      ? shareBaseDefine
      : (dotenv.env['URL_SHARE_PLAN'] ?? '').trim();
  if (shareBase.isNotEmpty) {
    return '${shareBase.replaceAll(RegExp(r'/$'), '')}?id=$id&v=1';
  }
  final app = kAuthRedirectWebProduccion.replaceAll(RegExp(r'/$'), '');
  return '$app/share-plan?id=$id&v=1';
}

/// Deep link web → [PantallaVerPlan].
String urlAppPlan(String idPlan) {
  final base = kAuthRedirectWebProduccion.replaceAll(RegExp(r'/$'), '');
  return '$base/?plan=${Uri.encodeComponent(idPlan)}';
}

String mensajeCompartirPlan({
  required String titulo,
  String? nombreLocal,
  String? ciudad,
  DateTime? fechaInicio,
}) {
  final tituloLimpio = titulo.trim().isEmpty ? 'este plan' : titulo.trim();
  final local = (nombreLocal ?? '').trim();
  final ciu = (ciudad ?? '').trim();
  String fecha = '';
  if (fechaInicio != null) {
    final f = fechaInicio.toLocal();
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    fecha = '${f.day}/${f.month} $hh:$mm';
  }
  final detalle = [local, fecha, ciu].where((p) => p.isNotEmpty).join(' · ');
  final buf = StringBuffer()
    ..writeln('Mirá este plan que encontré en Fernecitoapp:')
    ..writeln('')
    ..writeln('🍻 $tituloLimpio');
  if (detalle.isNotEmpty) buf.writeln(detalle);
  buf.writeln('');
  buf.write('Abrilo y sumate al plan');
  return buf.toString().trim();
}

Future<void> _esperarFrameUi() {
  final completer = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) => completer.complete());
  return completer.future;
}

Future<void> compartirPlan({
  required String idPlan,
  required String titulo,
  String? nombreLocal,
  String? ciudad,
  DateTime? fechaInicio,
  Rect? sharePositionOrigin,
  BuildContext? feedbackContext,
}) async {
  final id = idPlan.trim();
  if (id.isEmpty) {
    _avisar(feedbackContext, 'No se pudo compartir: plan sin id.');
    return;
  }

  HapticFeedback.mediumImpact();
  await _esperarFrameUi();

  final previewUrl = urlPreviewCompartirPlan(id);
  final cuerpo = mensajeCompartirPlan(
    titulo: titulo,
    nombreLocal: nombreLocal,
    ciudad: ciudad,
    fechaInicio: fechaInicio,
  );
  final payload = '$cuerpo\n\n$previewUrl';
  final subject = titulo.trim().isEmpty ? 'Plan' : titulo.trim();

  try {
    await SharePlus.instance.share(
      ShareParams(
        text: payload,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } on MissingPluginException {
    await _copiar(payload, feedbackContext);
  } on PlatformException {
    if (sharePositionOrigin != null) {
      try {
        await SharePlus.instance.share(
          ShareParams(text: payload, subject: subject),
        );
        return;
      } catch (_) {}
    }
    await _copiar(payload, feedbackContext);
  } catch (_) {
    await _copiar(payload, feedbackContext);
  }
}

Future<void> _copiar(String payload, BuildContext? ctx) async {
  try {
    await Clipboard.setData(ClipboardData(text: payload));
    _avisar(ctx, 'Link copiado al portapapeles.');
  } catch (_) {
    _avisar(ctx, 'No se pudo compartir el plan.');
  }
}

void _avisar(BuildContext? context, String mensaje) {
  if (context == null || !context.mounted) return;
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      content: Text(mensaje),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Ok'),
        ),
      ],
    ),
  );
}
