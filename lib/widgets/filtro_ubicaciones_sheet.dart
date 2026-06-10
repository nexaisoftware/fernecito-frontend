/// Bottomsheet de filtro por provincia + ciudades (multi-selección).
///
/// Se abre desde el botón GPS en el header de la cartelera.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/ubicaciones_data.dart';

/// Ubicación principal del perfil (una provincia + una ciudad).
class ResultadoUbicacionPerfil {
  const ResultadoUbicacionPerfil({
    required this.provincia,
    required this.ciudad,
  });

  final String provincia;
  final String ciudad;
}

/// Sheet para elegir provincia y ciudad del perfil de usuario.
Future<ResultadoUbicacionPerfil?> mostrarSelectorUbicacionPerfil(
  BuildContext context, {
  required String provinciaActual,
  required String ciudadActual,
}) {
  return showModalBottomSheet<ResultadoUbicacionPerfil>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _SelectorUbicacionPerfilSheet(
      provinciaActual: provinciaActual.isNotEmpty
          ? provinciaActual
          : UbicacionesData.provinciaPorDefecto,
      ciudadActual: ciudadActual,
    ),
  );
}

class ResultadoFiltroUbicacion {
  const ResultadoFiltroUbicacion({
    required this.provincia,
    required this.ciudades,
  });

  /// Provincia seleccionada.
  final String provincia;

  /// Ciudades seleccionadas. Si vacío → "todas las ciudades de la provincia".
  final Set<String> ciudades;
}

/// Devuelve `null` si el usuario cierra sin aplicar. Devuelve el filtro si confirma.
Future<ResultadoFiltroUbicacion?> mostrarFiltroUbicacionesSheet(
  BuildContext context, {
  required String provinciaActual,
  required Set<String> ciudadesActuales,
}) {
  return showModalBottomSheet<ResultadoFiltroUbicacion>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _FiltroUbicacionesSheet(
      provinciaActual: provinciaActual,
      ciudadesActuales: ciudadesActuales,
    ),
  );
}

class _FiltroUbicacionesSheet extends StatefulWidget {
  const _FiltroUbicacionesSheet({
    required this.provinciaActual,
    required this.ciudadesActuales,
  });
  final String provinciaActual;
  final Set<String> ciudadesActuales;

  @override
  State<_FiltroUbicacionesSheet> createState() =>
      _FiltroUbicacionesSheetState();
}

class _FiltroUbicacionesSheetState extends State<_FiltroUbicacionesSheet> {
  late String _provincia;
  late Set<String> _ciudades;

  @override
  void initState() {
    super.initState();
    _provincia = widget.provinciaActual;
    _ciudades = {...widget.ciudadesActuales};
  }

  void _toggleCiudad(String ciudad) {
    setState(() {
      if (_ciudades.contains(ciudad)) {
        _ciudades.remove(ciudad);
      } else {
        _ciudades.add(ciudad);
      }
    });
  }

  void _seleccionarTodas() {
    setState(() {
      _ciudades = UbicacionesData.ciudadesDe(_provincia).toSet();
    });
  }

  void _limpiar() {
    setState(() => _ciudades.clear());
  }

  // Altura aproximada de la navbar (58 + safearea bottom). El sheet termina ANTES
  // de la navbar para que el botón de aplicar nunca quede tapado.
  static const double _kAlturaNavbarUI = 58.0;

  @override
  Widget build(BuildContext context) {
    final ciudadesProvincia = UbicacionesData.ciudadesDe(_provincia);
    final altura = MediaQuery.of(context).size.height * 0.78;
    final marginNavbar =
        _kAlturaNavbarUI + MediaQuery.of(context).padding.bottom + 4;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + marginNavbar,
      ),
      child: Container(
        height: altura,
        decoration: SuperficiesApp.bottomSheet(),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _HandleBar(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.location_solid,
                      color: ColoresApp.principalMarca, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '¿Dónde salís?',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark_circle_fill,
                        color: ColoresApp.textoSecundario, size: 22),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DropdownProvincia(
                valor: _provincia,
                onChanged: (p) {
                  if (p == null) return;
                  setState(() {
                    _provincia = p;
                    _ciudades = {};
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Ciudades (${_ciudades.length}/${ciudadesProvincia.length})',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _seleccionarTodas,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      'Todas',
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.principalMarca,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _limpiar,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: Text(
                      'Limpiar',
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.textoSecundario,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: ciudadesProvincia.length,
                itemBuilder: (ctx, i) {
                  final c = ciudadesProvincia[i];
                  final marcada = _ciudades.contains(c);
                  return InkWell(
                    onTap: () => _toggleCiudad(c),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: marcada
                            ? ColoresApp.principalMarca.withOpacity(0.12)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            marcada
                                ? CupertinoIcons.checkmark_square_fill
                                : CupertinoIcons.square,
                            color: marcada
                                ? ColoresApp.principalMarca
                                : ColoresApp.textoSecundario,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c,
                              style: GoogleFonts.baloo2(
                                color: ColoresApp.textoPrincipal,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: BoxDecoration(
                color: ColoresApp.fondoPrincipal.withOpacity(0.92),
                border: Border(
                  top: BorderSide(
                    color: ColoresApp.textoSecundario.withOpacity(0.15),
                    width: 1,
                  ),
                ),
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresApp.principalMarca,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(
                  context,
                  ResultadoFiltroUbicacion(
                    provincia: _provincia,
                    ciudades: _ciudades,
                  ),
                ),
                child: Text(
                  _ciudades.isEmpty
                      ? 'Ver toda la provincia'
                      : 'Aplicar (${_ciudades.length} ciudad${_ciudades.length == 1 ? '' : 'es'})',
                  style: GoogleFonts.baloo2(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorUbicacionPerfilSheet extends StatefulWidget {
  const _SelectorUbicacionPerfilSheet({
    required this.provinciaActual,
    required this.ciudadActual,
  });

  final String provinciaActual;
  final String ciudadActual;

  @override
  State<_SelectorUbicacionPerfilSheet> createState() =>
      _SelectorUbicacionPerfilSheetState();
}

class _SelectorUbicacionPerfilSheetState extends State<_SelectorUbicacionPerfilSheet> {
  late String _provincia;
  String? _ciudad;

  @override
  void initState() {
    super.initState();
    _provincia = widget.provinciaActual;
    final ciudad = widget.ciudadActual.trim();
    _ciudad = ciudad.isNotEmpty ? ciudad : null;
  }

  @override
  Widget build(BuildContext context) {
    final ciudades = UbicacionesData.ciudadesDe(_provincia);
    final altura = MediaQuery.of(context).size.height * 0.62;

    return Container(
      height: altura,
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _HandleBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Tu ubicación',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Así te muestran la cartelera y te encuentran en la app.',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DropdownProvincia(
              valor: _provincia,
              onChanged: (p) {
                if (p == null) return;
                setState(() {
                  _provincia = p;
                  _ciudad = null;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: ciudades.length,
              itemBuilder: (context, i) {
                final c = ciudades[i];
                final sel = _ciudad == c;
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: () => setState(() => _ciudad = c),
                  child: Row(
                    children: [
                      Icon(
                        sel
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        color: sel
                            ? ColoresApp.principalMarca
                            : ColoresApp.textoSecundario,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c,
                          style: GoogleFonts.baloo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.principalMarca,
                disabledBackgroundColor:
                    ColoresApp.principalMarca.withValues(alpha: 0.35),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _ciudad == null
                  ? null
                  : () => Navigator.pop(
                        context,
                        ResultadoUbicacionPerfil(
                          provincia: _provincia,
                          ciudad: _ciudad!,
                        ),
                      ),
              child: Text(
                'Guardar ubicación',
                style: GoogleFonts.baloo2(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: ColoresApp.textoSecundario.withOpacity(0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DropdownProvincia extends StatelessWidget {
  const _DropdownProvincia({required this.valor, required this.onChanged});
  final String valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColoresApp.textoSecundario.withOpacity(0.18),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: ColoresApp.fondoSuperficie,
          value: valor,
          icon: const Icon(CupertinoIcons.chevron_down,
              size: 16, color: ColoresApp.textoSecundario),
          style: GoogleFonts.baloo2(
            color: ColoresApp.textoPrincipal,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final p in UbicacionesData.provincias)
              DropdownMenuItem<String>(
                value: p,
                child: Text(p,
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    )),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
