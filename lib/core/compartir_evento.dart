/// URLs, mensajes y acción de compartir eventos (WhatsApp, IG, etc.).
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';

import 'auth_redirect.dart';

/// URL pública con Open Graph para preview rica (flyer + título) en WhatsApp.
String urlPreviewCompartirEvento(String idEvento) {
  final id = Uri.encodeComponent(idEvento);
  final shareBase = (dotenv.env['URL_SHARE_EVENTO'] ?? '').trim();
  if (shareBase.isNotEmpty) {
    return '${shareBase.replaceAll(RegExp(r'/$'), '')}?id=$id&v=916';
  }

  final supabaseBase = (dotenv.env['URL_SUPABASE'] ?? '').replaceAll(
    RegExp(r'/$'),
    '',
  );
  if (supabaseBase.isEmpty) return urlAppEvento(idEvento);
  return '$supabaseBase/functions/v1/share_evento?id=$id&v=916';
}

/// Deep link web que abre la app Flutter en [PantallaVerEvento].
String urlAppEvento(String idEvento) {
  final base = kAuthRedirectWebProduccion.replaceAll(RegExp(r'/$'), '');
  return '$base/?evento=${Uri.encodeComponent(idEvento)}';
}

/// Esquema nativo (futuro App Links / Universal Links).
String urlDeepLinkNativoEvento(String idEvento) =>
    'fernecito://evento/$idEvento';

String _formatearFechaCompartir(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '';
  try {
    final f = DateTime.parse(iso).toLocal();
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    return '${dias[f.weekday - 1]} ${f.day} ${meses[f.month - 1]} · $hh:$mm';
  } catch (_) {
    return '';
  }
}

/// Texto que acompaña el link al compartir (estilo invitación).
String mensajeCompartirEvento({
  required String titulo,
  String? nombreLocal,
  String? fechaIso,
  String? ciudad,
}) {
  final tituloLimpio = titulo.trim().isEmpty ? 'este evento' : titulo.trim();
  final local = (nombreLocal ?? '').trim();
  final fecha = _formatearFechaCompartir(fechaIso);
  final ciu = (ciudad ?? '').trim();

  final detalle = [local, fecha, ciu].where((p) => p.isNotEmpty).join(' · ');

  final buf = StringBuffer()
    ..writeln('Mirá este evento que encontré en Fernecitoapp:')
    ..writeln('')
    ..writeln('🎉 $tituloLimpio');
  if (detalle.isNotEmpty) {
    buf.writeln(detalle);
  }
  buf.writeln('');
  buf.write('Abrilo y reservá tu lugar 🥃');
  return buf.toString().trim();
}

/// Rect de anclaje para el share sheet en iOS/iPadOS (requerido desde iOS 26).
Rect origenCompartirDesdeContexto(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  const minSide = 44.0;

  final render = context.findRenderObject();
  if (render is RenderBox && render.hasSize) {
    var rect = render.localToGlobal(Offset.zero) & render.size;
    if (rect.width >= minSide && rect.height >= minSide) {
      return _clampRect(rect, size, padding);
    }
  }

  final center = Offset(size.width * 0.5, size.height - padding.bottom - 80);
  return _clampRect(
    Rect.fromCenter(center: center, width: minSide, height: minSide),
    size,
    padding,
  );
}

Rect _clampRect(Rect rect, Size screen, EdgeInsets padding) {
  final minX = padding.left;
  final minY = padding.top;
  final maxX = screen.width - padding.right;
  final maxY = screen.height - padding.bottom;

  var left = rect.left.clamp(minX, maxX - rect.width);
  var top = rect.top.clamp(minY, maxY - rect.height);
  var w = rect.width.clamp(44.0, maxX - minX);
  var h = rect.height.clamp(44.0, maxY - minY);

  if (left + w > maxX) left = maxX - w;
  if (top + h > maxY) top = maxY - h;

  return Rect.fromLTWH(left, top, w, h);
}

Future<void> _esperarFrameUi() {
  final completer = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) => completer.complete());
  return completer.future;
}

/// Abre el sheet nativo de compartir con mensaje + URL con preview OG.
Future<void> compartirEvento({
  required String idEvento,
  required String titulo,
  String? nombreLocal,
  String? fechaIso,
  String? ciudad,
  Rect? sharePositionOrigin,
  BuildContext? feedbackContext,
}) async {
  final id = idEvento.trim();
  if (id.isEmpty) {
    _avisar(feedbackContext, 'No se pudo compartir: evento sin identificador.');
    return;
  }

  HapticFeedback.mediumImpact();
  await _esperarFrameUi();

  final previewUrl = urlPreviewCompartirEvento(id);
  final cuerpo = mensajeCompartirEvento(
    titulo: titulo.trim().isEmpty ? 'Evento' : titulo.trim(),
    nombreLocal: nombreLocal,
    fechaIso: fechaIso,
    ciudad: ciudad,
  );

  final payload = '$cuerpo\n\n$previewUrl';
  final subject = titulo.trim().isEmpty ? 'Evento' : titulo.trim();

  try {
    await SharePlus.instance.share(
      ShareParams(
        text: payload,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } on MissingPluginException catch (e) {
    debugPrint('⚠️ compartirEvento MissingPlugin: $e');
    // ignore: use_build_context_synchronously
    await _fallbackPortapapeles(payload, feedbackContext, esPluginNativo: true);
  } on PlatformException catch (e) {
    debugPrint('⚠️ compartirEvento PlatformException: ${e.code} ${e.message}');
    // Reintento sin origin por si el rect falló en iPad/simulador.
    if (sharePositionOrigin != null) {
      try {
        await SharePlus.instance.share(
          ShareParams(text: payload, subject: subject),
        );
        return;
      } catch (retry) {
        debugPrint('⚠️ compartirEvento retry: $retry');
      }
    }
    // ignore: use_build_context_synchronously
    await _fallbackPortapapeles(payload, feedbackContext);
  } catch (e, st) {
    debugPrint('⚠️ compartirEvento: $e\n$st');
    // ignore: use_build_context_synchronously
    await _fallbackPortapapeles(payload, feedbackContext);
  }
}

Future<void> _fallbackPortapapeles(
  String payload,
  BuildContext? feedbackContext, {
  bool esPluginNativo = false,
}) async {
  try {
    await Clipboard.setData(ClipboardData(text: payload));
    if (feedbackContext == null || !feedbackContext.mounted) return;
    _avisar(
      feedbackContext,
      esPluginNativo
          ? 'Falta el plugin nativo de compartir. '
                'Detené la app, corré `cd ios && pod install` y volvé a compilar.'
          : 'No se abrió el menú de compartir. Copiamos el link al portapapeles.',
    );
  } catch (_) {
    if (feedbackContext != null && feedbackContext.mounted) {
      _avisar(feedbackContext, 'No se pudo compartir el evento.');
    }
  }
}

void _avisar(BuildContext? context, String mensaje) {
  if (context == null || !context.mounted) return;
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Compartir'),
      content: Text(mensaje),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
