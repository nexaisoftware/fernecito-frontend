library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const Color kVerdeSplashFernecito = Color(0xFF16B957);

class SplashCargaFernecito extends StatefulWidget {
  const SplashCargaFernecito({super.key});

  @override
  State<SplashCargaFernecito> createState() => _SplashCargaFernecitoState();
}

class _SplashCargaFernecitoState extends State<SplashCargaFernecito>
    with TickerProviderStateMixin {
  late final AnimationController _entradaController;
  late final AnimationController _barraController;
  late final Animation<double> _entrada;
  late final Animation<double> _barra;

  @override
  void initState() {
    super.initState();
    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _barraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _entrada = CurvedAnimation(
      parent: _entradaController,
      curve: Curves.easeOutCubic,
    );
    _barra = CurvedAnimation(
      parent: _barraController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _entradaController.dispose();
    _barraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kVerdeSplashFernecito,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_entradaController, _barraController]),
          builder: (context, child) {
            final entrada = _entrada.value;
            return Opacity(
              opacity: entrada.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - entrada)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    child!,
                    const SizedBox(height: 34),
                    BarraEspejoFernecito(value: _barra.value),
                  ],
                ),
              ),
            );
          },
          child: Container(
            width: 160,
            height: 160,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/imagenes/logoiconapp.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SplashCargaFernecitoBarra extends StatefulWidget {
  const SplashCargaFernecitoBarra({super.key});

  @override
  State<SplashCargaFernecitoBarra> createState() =>
      _SplashCargaFernecitoBarraState();
}

class _SplashCargaFernecitoBarraState extends State<SplashCargaFernecitoBarra>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _value = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _value,
      builder: (context, _) => BarraEspejoFernecito(value: _value.value),
    );
  }
}

class BarraEspejoFernecito extends StatelessWidget {
  const BarraEspejoFernecito({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final halfWidth = 86.0 * value.clamp(0.0, 1.0);

    return SizedBox(
      width: 172,
      height: 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            width: halfWidth * 2,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.28),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
