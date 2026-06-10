/// Pantalla de Splash Screen con animación elegante.
///
/// Muestra el logo de Fernecito con una animación fade + scale
/// sobre fondo verde principal de la marca.
///
/// Duración: 2.5 segundos antes de verificar sesión y navegar.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class PantallaSplash extends StatefulWidget {
  final VoidCallback onFinished;

  const PantallaSplash({
    super.key,
    required this.onFinished,
  });

  @override
  State<PantallaSplash> createState() => _PantallaSplashState();
}

class _PantallaSplashState extends State<PantallaSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSplash();
  }

  void _setupAnimations() {
    // Controller de 2 segundos
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fade: de 0 a 1 con curva elegante
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.7,
          curve: Curves.easeOut,
        ),
      ),
    );

    // Scale: de 0.5 a 1.0 con bounce suave
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.8,
          curve: Curves.easeOutBack, // Bounce suave al final
        ),
      ),
    );
  }

  void _startSplash() async {
    // Iniciar animación
    _controller.forward();

    // Esperar 2.5 segundos totales
    await Future.delayed(const Duration(milliseconds: 2500));

    // Llamar callback para continuar
    if (mounted) {
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CupertinoPageScaffold(
        backgroundColor: ColoresApp.principalMarca, // Verde Fernet
        child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo principal con sombra suave
              Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(20), // Padding interno para que el logo sea más pequeño
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/imagenes/logoiconapp.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Indicador de carga elegante
              const CupertinoActivityIndicator(
                color: ColoresApp.textoPrincipal,
                radius: 16,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
