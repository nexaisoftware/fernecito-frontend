/// URLs, mensajes y acción de compartir planes (espejo de eventos).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_redirect.dart';
import '../widgets/dialogo_fernecito.dart';

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

  // En web NO esperamos frames: navigator.share exige el gesto del tap.
  // Si se pierde, share_plus cae a mailto (Gmail/Outlook) — eso no queremos.
  HapticFeedback.selectionClick();
  if (!kIsWeb) {
    await _esperarFrameUi();
  }

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
        // subject en web termina como title del Share API (ok).
        // mailToFallbackEnabled: false → nunca abrir Gmail/Outlook.
        subject: subject,
        sharePositionOrigin: kIsWeb ? null : sharePositionOrigin,
        mailToFallbackEnabled: false,
        downloadFallbackEnabled: false,
      ),
    );
  } on MissingPluginException {
    await _copiar(payload, feedbackContext);
  } on PlatformException {
    if (!kIsWeb && sharePositionOrigin != null) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: payload,
            subject: subject,
            mailToFallbackEnabled: false,
            downloadFallbackEnabled: false,
          ),
        );
        return;
      } catch (_) {}
    }
    await _copiar(payload, feedbackContext);
  } catch (_) {
    // Desktop / navegador sin Web Share API → portapapeles, nunca mailto.
    await _copiar(payload, feedbackContext);
  }
}

Future<void> _copiar(String payload, BuildContext? ctx) async {
  try {
    await Clipboard.setData(ClipboardData(text: payload));
    _avisar(
      ctx,
      kIsWeb
          ? 'Link copiado. Pegalo donde quieras compartirlo.'
          : 'Link copiado al portapapeles.',
    );
  } catch (_) {
    _avisar(ctx, 'No se pudo compartir el plan.');
  }
}

void _avisar(BuildContext? context, String mensaje) {
  if (context == null || !context.mounted) return;
  showFernecitoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => DialogoFernecito(
      content: Text(mensaje),
      actions: [
        AccionDialogoFernecito(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Ok'),
        ),
      ],
    ),
  );
}
