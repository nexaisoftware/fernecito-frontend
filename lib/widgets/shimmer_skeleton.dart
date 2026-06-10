/// Skeleton loader con efecto shimmer reutilizable.
/// Usar ShimmerBox, ShimmerCircle, ShimmerLine o envolver cualquier widget con ShimmerSkeleton.
library;

import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Color base de los placeholders (gris oscuro acorde al tema).
final Color _skeletonBase = ColoresApp.fondoSuperficie;

/// Color del brillo del shimmer (un poco más claro).
final Color _skeletonHighlight = Colors.white.withOpacity(0.08);

/// Envuelve [child] con el efecto shimmer animado (gradiente que se mueve).
class ShimmerSkeleton extends StatefulWidget {
  final Widget child;

  const ShimmerSkeleton({super.key, required this.child});

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = (_animation.value + 1) / 2;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(t - 0.4, 0),
              end: Alignment(t + 0.4, 0),
              colors: [
                _skeletonBase,
                _skeletonHighlight,
                _skeletonBase,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Caja rectangular con shimmer (para cards, imágenes, etc.).
Widget ShimmerBox({
  double? width,
  double? height,
  double borderRadius = 12,
}) {
  return ShimmerSkeleton(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );
}

/// Círculo con shimmer (para avatares).
Widget ShimmerCircle({double size = 48}) {
  return ShimmerSkeleton(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _skeletonBase,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// Línea con shimmer (para textos).
Widget ShimmerLine({
  double? width,
  double height = 14,
  double borderRadius = 6,
}) {
  return ShimmerSkeleton(
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );
}
