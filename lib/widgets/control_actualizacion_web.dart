library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/servicio_actualizacion_web.dart';
import '../core/visibilidad_web.dart';

/// Banner no intrusivo: avisa cuando hay deploy nuevo y recarga solo si el usuario acepta.
class ControlActualizacionWeb extends StatefulWidget {
  const ControlActualizacionWeb({super.key, required this.child});

  final Widget child;

  @override
  State<ControlActualizacionWeb> createState() => _ControlActualizacionWebState();
}

class _ControlActualizacionWebState extends State<ControlActualizacionWeb>
    with WidgetsBindingObserver {
  bool _mostrarBanner = false;
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    if (ServicioActualizacionWeb.instancia.soportado) {
      WidgetsBinding.instance.addObserver(this);
      escucharVisibilidadWeb(_verificar);
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificar());
    }
  }

  @override
  void dispose() {
    if (ServicioActualizacionWeb.instancia.soportado) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificar();
    }
  }

  Future<void> _verificar() async {
    if (_verificando || !ServicioActualizacionWeb.instancia.soportado) return;
    _verificando = true;
    try {
      final hayNueva = await ServicioActualizacionWeb.instancia.verificar();
      if (!mounted) return;
      if (hayNueva != _mostrarBanner) {
        setState(() => _mostrarBanner = hayNueva);
      }
    } finally {
      _verificando = false;
    }
  }

  Future<void> _actualizar() async {
    setState(() => _mostrarBanner = false);
    await ServicioActualizacionWeb.instancia.aplicarActualizacion();
  }

  Widget _banner() {
    return Material(
      elevation: 8,
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hay una nueva versión disponible.',
                  style: GoogleFonts.baloo2(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _mostrarBanner = false),
                child: Text(
                  'Después',
                  style: GoogleFonts.baloo2(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _actualizar,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresApp.principalMarca,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'Actualizar',
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_mostrarBanner) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _banner(),
        ),
      ],
    );
  }
}
