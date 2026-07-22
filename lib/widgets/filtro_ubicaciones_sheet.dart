/// Bottomsheet de ubicación de cartelera: inteligente (GPS) vs filtro personalizado.
///
/// Additive: no cambia el contrato de query; solo define qué ciudades entran
/// al filtro local `_ciudadesActivas`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/coordenadas_ciudades.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_ubicacion_dispositivo.dart';
import '../core/ubicaciones_data.dart';
import 'fernecito_loader.dart';

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
    useRootNavigator: true,
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
    this.ciudadPrincipal,
    this.carteleraInteligente = false,
  });

  /// Provincia seleccionada (o la de la ciudad más cercana en modo inteligente).
  final String provincia;

  /// Ciudades seleccionadas / resueltas por proximidad.
  final Set<String> ciudades;

  /// Ciudad que debe sincronizarse al perfil del usuario.
  final String? ciudadPrincipal;

  /// True = modo GPS (ciudades ≤ 20 km). False = filtro personalizado.
  final bool carteleraInteligente;
}

/// Devuelve `null` si el usuario cierra sin aplicar. Devuelve el filtro si confirma.
Future<ResultadoFiltroUbicacion?> mostrarFiltroUbicacionesSheet(
  BuildContext context, {
  required String provinciaActual,
  required Set<String> ciudadesActuales,
  bool carteleraInteligente = false,
}) {
  return showModalBottomSheet<ResultadoFiltroUbicacion>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => _FiltroUbicacionesSheet(
      provinciaActual: provinciaActual,
      ciudadesActuales: ciudadesActuales,
      carteleraInteligente: carteleraInteligente,
    ),
  );
}

class _FiltroUbicacionesSheet extends StatefulWidget {
  const _FiltroUbicacionesSheet({
    required this.provinciaActual,
    required this.ciudadesActuales,
    required this.carteleraInteligente,
  });
  final String provinciaActual;
  final Set<String> ciudadesActuales;
  final bool carteleraInteligente;

  @override
  State<_FiltroUbicacionesSheet> createState() =>
      _FiltroUbicacionesSheetState();
}

class _FiltroUbicacionesSheetState extends State<_FiltroUbicacionesSheet> {
  late String _provincia;
  late Set<String> _ciudades;
  late bool _inteligente;
  bool _resolviendoGps = false;
  String? _errorGps;
  String? _hintInteligente;
  String? _ciudadPrincipal;

  @override
  void initState() {
    super.initState();
    _provincia = widget.provinciaActual;
    _ciudades = {...widget.ciudadesActuales};
    _inteligente = widget.carteleraInteligente;
    final principalGuardada = PreferenciasCartelera.instancia.ciudadPrincipal;
    if (principalGuardada != null && _ciudades.contains(principalGuardada)) {
      _ciudadPrincipal = principalGuardada;
    } else if (_ciudades.isNotEmpty) {
      _ciudadPrincipal = _ciudades.first;
    }
    if (_inteligente && _ciudades.isNotEmpty) {
      _hintInteligente =
          '${_ciudades.length} ciudad${_ciudades.length == 1 ? '' : 'es'} cerca tuyo';
    }
  }

  void _toggleCiudad(String ciudad) {
    if (_inteligente) return;
    setState(() {
      if (_ciudades.contains(ciudad)) {
        _ciudades.remove(ciudad);
        if (_ciudadPrincipal == ciudad) {
          _ciudadPrincipal = _ciudades.isNotEmpty ? _ciudades.first : null;
        }
      } else {
        _ciudades.add(ciudad);
        _ciudadPrincipal ??= ciudad;
      }
    });
  }

  void _seleccionarTodas() {
    if (_inteligente) return;
    setState(() {
      _ciudades = UbicacionesData.ciudadesDe(_provincia).toSet();
      if (_ciudadPrincipal == null || !_ciudades.contains(_ciudadPrincipal)) {
        _ciudadPrincipal = _ciudades.isNotEmpty ? _ciudades.first : null;
      }
    });
  }

  void _limpiar() {
    if (_inteligente) return;
    setState(() {
      _ciudades.clear();
      _ciudadPrincipal = null;
    });
  }

  Future<void> _onToggleInteligente(bool value) async {
    HapticFeedback.selectionClick();
    if (!value) {
      setState(() {
        _inteligente = false;
        _errorGps = null;
        _hintInteligente = null;
        _resolviendoGps = false;
        final prefs = PreferenciasCartelera.instancia;
        if (prefs.ciudadesCustom.isNotEmpty) {
          _ciudades = {...prefs.ciudadesCustom};
          _provincia =
              prefs.provinciaCustom ?? UbicacionesData.provinciaPorDefecto;
          final principal = prefs.ciudadPrincipal;
          _ciudadPrincipal = principal != null && _ciudades.contains(principal)
              ? principal
              : (_ciudades.isNotEmpty ? _ciudades.first : null);
        }
      });
      return;
    }

    // Debe llamarse síncrono desde el gesto (switch).
    final futuro = ServicioUbicacionDispositivo.instancia
        .iniciarDesdeGestoUsuario();
    setState(() {
      _inteligente = true;
      _resolviendoGps = true;
      _errorGps = null;
      _hintInteligente = null;
    });

    final res = await futuro;
    if (!mounted) return;

    if (!res.exito || res.latitud == null || res.longitud == null) {
      setState(() {
        _inteligente = false;
        _resolviendoGps = false;
        _errorGps =
            res.mensajeUsuario ??
            'No pudimos obtener tu ubicación. Usá el filtro personalizado.';
      });
      return;
    }

    final cercanas = CoordenadasCiudades.ciudadesCercanas(
      latitud: res.latitud!,
      longitud: res.longitud!,
      radioKm: PreferenciasCartelera.radioKmDefault,
    );
    if (cercanas.isEmpty) {
      setState(() {
        _inteligente = false;
        _resolviendoGps = false;
        _errorGps =
            'No hay ciudades Fernecito cerca de tu ubicación. Elegí manualmente.';
      });
      return;
    }

    final provincia =
        CoordenadasCiudades.provinciaDeCiudad(cercanas.first) ??
        UbicacionesData.provinciaPorDefecto;

    setState(() {
      _resolviendoGps = false;
      _ciudades = cercanas.toSet();
      _provincia = provincia;
      _ciudadPrincipal = cercanas.first;
      _hintInteligente =
          '${cercanas.length} ciudad${cercanas.length == 1 ? '' : 'es'} a ≤${PreferenciasCartelera.radioKmDefault.toInt()} km';
      _errorGps = null;
    });
    _aplicar();
  }

  void _aplicar() {
    if (_ciudades.isEmpty) return;
    Navigator.pop(
      context,
      ResultadoFiltroUbicacion(
        provincia: _provincia,
        ciudades: _ciudades,
        ciudadPrincipal:
            _ciudadPrincipal != null && _ciudades.contains(_ciudadPrincipal)
            ? _ciudadPrincipal
            : (_ciudades.isNotEmpty ? _ciudades.first : null),
        carteleraInteligente: _inteligente,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ciudadesProvincia = UbicacionesData.ciudadesDe(_provincia);
    final altura = MediaQuery.of(context).size.height * 0.70;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final customEnabled = !_inteligente;

    return Container(
      height: altura,
      decoration: SuperficiesApp.bottomSheet(topRadius: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const _HandleBar(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.location_solid,
                  color: ColoresApp.principalMarca,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Dónde salís?',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: ColoresApp.textoSecundario,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottomSafe),
              children: [
                _TarjetaInteligente(
                  activa: _inteligente,
                  cargando: _resolviendoGps,
                  hint: _hintInteligente,
                  error: _errorGps,
                  onChanged: _resolviendoGps ? null : _onToggleInteligente,
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: customEnabled ? 1 : 0.38,
                  child: IgnorePointer(
                    ignoring: !customEnabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtro personalizado',
                          style: GoogleFonts.baloo2(
                            color: ColoresApp.textoPrincipal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Elegí las ubicaciones que quieras ver de manera segmentada.',
                          style: GoogleFonts.baloo2(
                            color: ColoresApp.textoSecundario,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DropdownProvincia(
                          valor: _provincia,
                          onChanged: (p) {
                            if (p == null) return;
                            setState(() {
                              _provincia = p;
                              _ciudades = {};
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
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
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 30),
                              onPressed: _seleccionarTodas,
                              child: Text(
                                'Todas',
                                style: GoogleFonts.baloo2(
                                  color: ColoresApp.principalMarca,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 30),
                              onPressed: _limpiar,
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
                        const SizedBox(height: 4),
                        for (final c in ciudadesProvincia)
                          _FilaCiudad(
                            ciudad: c,
                            marcada: _ciudades.contains(c),
                            onTap: () => _toggleCiudad(c),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 14 + bottomSafe),
            color: ColoresApp.fondoSuperficie,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.principalMarca,
                disabledBackgroundColor: ColoresApp.principalMarca.withValues(
                  alpha: 0.35,
                ),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _ciudades.isEmpty || _resolviendoGps ? null : _aplicar,
              child: Text(
                _inteligente
                    ? (_ciudades.isEmpty
                          ? 'Esperando ubicación…'
                          : 'Usar ubicación inteligente (${_ciudades.length})')
                    : (_ciudades.isEmpty
                          ? 'Elegí al menos una ciudad'
                          : 'Aplicar (${_ciudades.length} ciudad${_ciudades.length == 1 ? '' : 'es'})'),
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

class _TarjetaInteligente extends StatelessWidget {
  const _TarjetaInteligente({
    required this.activa,
    required this.cargando,
    required this.onChanged,
    this.hint,
    this.error,
  });

  final bool activa;
  final bool cargando;
  final ValueChanged<bool>? onChanged;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tint = ColoresApp.principalMarca.withValues(
      alpha: activa ? 0.18 : 0.10,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color:
            Color.lerp(ColoresApp.fondoPrincipal, tint, 1) ??
            ColoresApp.fondoPrincipal,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  CupertinoIcons.sparkles,
                  color: ColoresApp.principalMarca,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación inteligente',
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.textoPrincipal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activá esta opción para mostrarte eventos de tu ciudad y ciudades cercanas según tu ubicación.',
                      style: GoogleFonts.baloo2(
                        color: ColoresApp.textoSecundario,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (cargando)
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 6),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: FernecitoLoader.inline(size: 22),
                  ),
                )
              else
                CupertinoSwitch(
                  value: activa,
                  activeTrackColor: ColoresApp.principalMarca,
                  onChanged: onChanged,
                ),
            ],
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              hint!,
              style: GoogleFonts.baloo2(
                color: ColoresApp.principalMarca,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: GoogleFonts.baloo2(
                color: ColoresApp.peligroMarca,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaCiudad extends StatelessWidget {
  const _FilaCiudad({
    required this.ciudad,
    required this.marcada,
    required this.onTap,
  });

  final String ciudad;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: marcada
              ? ColoresApp.principalMarca.withValues(alpha: 0.12)
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
                ciudad,
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

class _SelectorUbicacionPerfilSheetState
    extends State<_SelectorUbicacionPerfilSheet> {
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
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      height: altura,
      decoration: SuperficiesApp.bottomSheet(topRadius: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const _HandleBar(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomSafe),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.principalMarca,
                disabledBackgroundColor: ColoresApp.principalMarca.withValues(
                  alpha: 0.35,
                ),
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
  const _HandleBar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: ColoresApp.textoSecundario.withValues(alpha: 0.35),
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
        color: ColoresApp.fondoPrincipal.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          dropdownColor: ColoresApp.fondoSuperficie,
          value: valor,
          icon: const Icon(
            CupertinoIcons.chevron_down,
            size: 16,
            color: ColoresApp.textoSecundario,
          ),
          style: GoogleFonts.baloo2(
            color: ColoresApp.textoPrincipal,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final p in UbicacionesData.provincias)
              DropdownMenuItem<String>(
                value: p,
                child: Text(
                  p,
                  style: GoogleFonts.baloo2(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
