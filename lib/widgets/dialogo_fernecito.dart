/// Diálogos Fernecito: fondo sólido de la app, Baloo 2, barrier oscuro,
/// acciones sin contenedor (solo color).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

class AccionDialogoFernecito extends StatelessWidget {
  const AccionDialogoFernecito({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDestructiveAction = false,
    this.isDefaultAction = false,
  });

  final VoidCallback onPressed;
  final Widget child;
  final bool isDestructiveAction;
  final bool isDefaultAction;

  @override
  Widget build(BuildContext context) {
    final color = isDestructiveAction
        ? const Color(0xFFFF6B6B)
        : isDefaultAction
        ? ColoresApp.principalMarca
        : ColoresApp.textoPrincipal;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      minimumSize: const Size(0, 36),
      onPressed: onPressed,
      child: DefaultTextStyle(
        style: GoogleFonts.baloo2(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: color,
        ),
        child: child,
      ),
    );
  }
}

class DialogoFernecito extends StatelessWidget {
  const DialogoFernecito({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ColoresApp.fondoPrincipal,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      DefaultTextStyle(
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: ColoresApp.textoPrincipal,
                          height: 1.15,
                        ),
                        textAlign: TextAlign.center,
                        child: title!,
                      ),
                    if (title != null && content != null)
                      const SizedBox(height: 10),
                    if (content != null)
                      DefaultTextStyle(
                        style: GoogleFonts.baloo2(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textoSecundario,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                        child: content!,
                      ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: actions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showAlertaFernecito<T>({
  required BuildContext context,
  Widget? title,
  Widget? content,
  required List<Widget> actions,
  bool barrierDismissible = true,
}) {
  return showFernecitoDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => DialogoFernecito(
      title: title,
      content: content,
      actions: actions,
    ),
  );
}

Future<T?> showFernecitoDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dialogo',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, anim, _, child) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.94 + 0.06 * t,
          child: child,
        ),
      );
    },
  );
}
