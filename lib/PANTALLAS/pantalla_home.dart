/// Pantalla principal (Home) - Cartelera Fernecito.
///
/// Estructura:
/// - 5 tabs (Actividad, Social, Cartelera, Notificaciones, Mi Perfil).
/// - La cartelera de eventos (`_PantallaCartelera`) tiene:
///   * Header con título + botón GPS (filtra por ciudad/provincia)
///   * Barra Spotlight (search + filtros plan / tiempo)
///   * Top Ultra → modal stories al abrir
///   * Sección TOP (carruseles de 10 por fila, divide en filas si hay más)
///   * Sección RECOMENDADO FERNECITO (carruseles de 15 por fila)
///   * Sección LUGARES POPULARES (locales random)
///   * Sección DESTACADOS EN TU CIUDAD (carruseles "normal" de 15, máx 2 filas + "Ver más")
///   * Grid de planes gratis al final
/// - Pull-to-refresh + shuffle random en cada apertura.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/jerarquias_data.dart';
import '../core/servicio_estado_cuenta.dart';
import '../core/servicio_notificaciones_usuarios.dart';
import '../core/navegacion_evento_compartido.dart';
import '../core/servicio_enlace_evento.dart';
import '../core/supabase_client.dart';
import '../core/tema_fernecito.dart';
import '../core/ubicaciones_data.dart';
import '../widgets/cards_cartelera.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/skeleton_pantallas.dart';
import '../widgets/spotlight_search_bar.dart';
import '../widgets/top_ultra_stories_overlay.dart';
import 'pantalla_actividad.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_mi_perfil.dart';
import 'pantalla_notificaciones.dart';
import 'pantalla_social.dart';
import 'pantalla_ver_evento.dart';
import 'pantalla_scanner_invitacion.dart';

// ============================================================================
// Helpers compartidos (top-level) que usaba la cartelera vieja.
// ============================================================================

bool _esAssetUrl(dynamic url) {
  final s = url?.toString() ?? '';
  return s.startsWith('assets/');
}

Widget _avatarPlaceholderLocal(double size) {
  return Container(
    color: ColoresApp.fondoPrincipal,
    child: Icon(
      CupertinoIcons.building_2_fill,
      size: size * 0.5,
      color: ColoresApp.textoSecundario,
    ),
  );
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value == 1;
  final s = value.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 't' || s == 'yes';
}

String? _primerCampoNoVacio(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return null;
  for (final key in keys) {
    final v = row[key]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

String _resolverAvatarLocal(SupabaseClient sb, dynamic avatarRaw) {
  final avatar = avatarRaw?.toString() ?? '';
  if (avatar.isEmpty || avatar.startsWith('http')) return avatar;
  return sb.storage.from('perfiles-locales').getPublicUrl(avatar);
}

String? _claveIdLocal(dynamic raw) {
  final s = raw?.toString().trim();
  if (s == null || s.isEmpty) return null;
  return s.toLowerCase();
}

// ============================================================================
// PantallaHome (tabs)
// ============================================================================

/// Altura de la navbar inferior (sin safe area del home indicator).
const double kHomeTabBarHeight = 58.0;

/// Espacio entre el FAB QR y el borde superior de la navbar.
const double kHomeFabGapSobreNav = 14.0;

const double kHomeFabQrSize = 52.0;

double homeFabBottomOffset(BuildContext context) {
  return kHomeTabBarHeight +
      MediaQuery.of(context).padding.bottom +
      kHomeFabGapSobreNav;
}

double homeCarteleraScrollBottomPadding(BuildContext context) {
  return homeFabBottomOffset(context) + kHomeFabQrSize + 12;
}

class PantallaHome extends StatefulWidget {
  const PantallaHome({super.key});

  @override
  State<PantallaHome> createState() => _PantallaHomeState();
}

class _PantallaHomeState extends State<PantallaHome>
    with WidgetsBindingObserver {
  String? _fotoPerfilUrl;
  int _currentTabIndex = 2;

  /// Se incrementa al entrar al tab Actividad para forzar `_cargarActividad` (IndexedStack no recrea el hijo).
  int _actividadReloadTick = 0;
  int _perfilReloadTick = 0;

  /// Se incrementa al entrar al tab Notificaciones para forzar recarga
  /// (IndexedStack no recrea el hijo).
  int _notifsReloadTick = 0;
  int _socialInitialTab = 0;
  int _socialNavToken = 0;

  final _srvNotificaciones = ServicioNotificacionesUsuarios();

  void _irATabSocialDesdeNotif(int tab) {
    setState(() {
      _socialInitialTab = tab.clamp(0, 1);
      _socialNavToken++;
      _currentTabIndex = 1;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarFotoPerfil();
    _verificarCuentaPausada();
    _srvNotificaciones.refrescarContador();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _srvNotificaciones.refrescarContador();
      _verificarCuentaPausada();
    }
  }

  Future<void> _verificarCuentaPausada() async {
    if (!mounted) return;
    // Solo refresca el switch; el gate de AppFernecito (builder) toma el
    // control y muestra la pantalla bloqueante si quedó suspendida.
    await ServicioEstadoCuenta.instancia.refrescar();
  }

  Future<void> _cargarFotoPerfil() async {
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) return;
      final respuesta = await supabase.cliente
          .from('perfiles_usuarios')
          .select('foto_perfil_url')
          .eq('id', usuario.id)
          .maybeSingle();
      if (respuesta != null && mounted) {
        setState(() {
          if (respuesta['foto_perfil_url'] != null) {
            final path = respuesta['foto_perfil_url'] as String;
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            _fotoPerfilUrl =
                '${supabase.cliente.storage.from('avatars').getPublicUrl(path)}?v=$timestamp';
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando foto de perfil: $e');
    }
  }

  // Iconos más chicos + altura levemente reducida para look moderno tipo iOS 18 / Android 14
  static const double _kTabBarIconSize = 26.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IndexedStack(
          index: _currentTabIndex,
          children: [
            CupertinoTabView(
              builder: (context) =>
                  PantallaActividad(reloadTick: _actividadReloadTick),
            ),
            CupertinoTabView(
              builder: (context) => PantallaSocial(
                key: ValueKey('social_$_socialNavToken'),
                initialTabIndex: _socialInitialTab,
              ),
            ),
            CupertinoTabView(builder: (context) => const _PantallaCartelera()),
            CupertinoTabView(
              builder: (context) => PantallaNotificaciones(
                reloadTick: _notifsReloadTick,
                onIrATabSocial: _irATabSocialDesdeNotif,
              ),
            ),
            CupertinoTabView(
              builder: (context) =>
                  PantallaMiPerfil(reloadTick: _perfilReloadTick),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<Color>(
            valueListenable: TemaFernecito.instancia.colorActual,
            builder: (context, _, __) => _GlassTabBar(
              height: kHomeTabBarHeight,
              iconSize: _kTabBarIconSize,
              currentIndex: _currentTabIndex,
              onTap: (index) => setState(() {
                _currentTabIndex = index;
                if (index == 0) _actividadReloadTick++;
                if (index == 2) _srvNotificaciones.refrescarContador();
                if (index == 3) {
                  _notifsReloadTick++;
                  _srvNotificaciones.refrescarContador();
                }
                if (index == 4) _perfilReloadTick++;
              }),
              fotoPerfilUrl: _fotoPerfilUrl,
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de tabs con look suave de tema (sin blur para mejor rendimiento).
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({
    required this.height,
    required this.iconSize,
    required this.currentIndex,
    required this.onTap,
    this.fotoPerfilUrl,
  });

  final double height;
  final double iconSize;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? fotoPerfilUrl;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalHeight = height + bottomPadding;
    final iconSizeReducido = iconSize * 0.92;
    final iconSizeCartelera = iconSize * 1.28;
    final iconAreaHeight = iconSizeCartelera + 2;

    return SizedBox(
      width: double.infinity,
      height: totalHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Capa de blur con gradiente más sutil (vibe iOS 18)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ColoresApp.fondoSuperficie.withOpacity(0.78),
                      ColoresApp.fondoSuperficie.withOpacity(0.94),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: ColoresApp.principalMarca.withOpacity(0.18),
                      width: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Indicador superior más fino y centrado
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / 5;
                const indicatorWidth = 26.0;
                final leftOffset =
                    segmentWidth * currentIndex +
                    (segmentWidth - indicatorWidth) / 2;
                return SizedBox(
                  height: 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        left: leftOffset,
                        width: indicatorWidth,
                        top: 0,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: ColoresApp.principalMarca,
                            borderRadius: BorderRadius.circular(1.25),
                            boxShadow: [
                              BoxShadow(
                                color: ColoresApp.principalMarca.withOpacity(
                                  0.55,
                                ),
                                blurRadius: 6,
                                spreadRadius: 0.3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: bottomPadding,
            child: Center(
              child: SizedBox(
                height: height.clamp(0, double.infinity),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _wrappedTabItem(
                      _TabItem(
                        icon: Icon(
                          CupertinoIcons.calendar,
                          size: iconSizeReducido,
                          color: ColoresApp.textoSecundario,
                        ),
                        activeIcon: Icon(
                          CupertinoIcons.calendar_today,
                          size: iconSizeReducido,
                          color: Colors.white,
                        ),
                        label: 'Actividad',
                        isActive: currentIndex == 0,
                        onTap: () => onTap(0),
                        iconAreaHeight: iconAreaHeight,
                      ),
                    ),
                    _wrappedTabItem(
                      _TabItem(
                        icon: Icon(
                          CupertinoIcons.person_2,
                          size: iconSizeReducido,
                          color: ColoresApp.textoSecundario,
                        ),
                        activeIcon: Icon(
                          CupertinoIcons.person_2_fill,
                          size: iconSizeReducido,
                          color: Colors.white,
                        ),
                        label: 'Social',
                        isActive: currentIndex == 1,
                        onTap: () => onTap(1),
                        iconAreaHeight: iconAreaHeight,
                      ),
                    ),
                    _wrappedTabItem(
                      _TabItem(
                        icon: Icon(
                          CupertinoIcons.ticket,
                          size: iconSizeCartelera,
                          color: ColoresApp.textoSecundario,
                        ),
                        activeIcon: Icon(
                          CupertinoIcons.ticket_fill,
                          size: iconSizeCartelera,
                          color: Colors.white,
                        ),
                        label: 'Cartelera',
                        isActive: currentIndex == 2,
                        onTap: () => onTap(2),
                        iconAreaHeight: iconAreaHeight,
                      ),
                    ),
                    _wrappedTabItem(
                      ValueListenableBuilder<int>(
                        valueListenable:
                            ServicioNotificacionesUsuarios().contadorNoLeidas,
                        builder: (context, sinLeer, _) {
                          return _TabItem(
                            icon: _iconoNotificacionesConBadge(
                              CupertinoIcons.bell,
                              sinLeer: sinLeer,
                              size: iconSizeReducido,
                              activo: false,
                            ),
                            activeIcon: _iconoNotificacionesConBadge(
                              CupertinoIcons.bell_fill,
                              sinLeer: sinLeer,
                              size: iconSizeReducido,
                              activo: true,
                            ),
                            label: 'Novedades',
                            isActive: currentIndex == 3,
                            onTap: () => onTap(3),
                            iconAreaHeight: iconAreaHeight,
                          );
                        },
                      ),
                    ),
                    _wrappedTabItem(
                      _TabItem(
                        icon: fotoPerfilUrl != null
                            ? _avatarWidget(
                                fotoPerfilUrl!,
                                active: false,
                                size: iconSizeReducido,
                              )
                            : Icon(
                                CupertinoIcons.person_circle,
                                size: iconSizeReducido,
                                color: ColoresApp.textoSecundario,
                              ),
                        activeIcon: fotoPerfilUrl != null
                            ? _avatarWidget(
                                fotoPerfilUrl!,
                                active: true,
                                size: iconSizeReducido,
                              )
                            : Icon(
                                CupertinoIcons.person_circle_fill,
                                size: iconSizeReducido,
                                color: Colors.white,
                              ),
                        label: 'Perfil',
                        isActive: currentIndex == 4,
                        onTap: () => onTap(4),
                        iconAreaHeight: iconAreaHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrappedTabItem(Widget tabChild) {
    return Expanded(child: SizedBox.expand(child: tabChild));
  }

  Widget _avatarWidget(String url, {required bool active, double? size}) {
    final s = size ?? iconSize;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active
              ? Colors.white
              : ColoresApp.principalMarca.withOpacity(0.8),
          width: active ? 2 : 1.5,
        ),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, u) =>
              Icon(CupertinoIcons.person_circle, size: s - 2),
          errorWidget: (context, u, e) =>
              Icon(CupertinoIcons.person_circle, size: s),
        ),
      ),
    );
  }
}

/// Campana del tab bar con badge de no leídas (mismo patrón que app locales).
Widget _iconoNotificacionesConBadge(
  IconData icon, {
  required int sinLeer,
  required double size,
  required bool activo,
}) {
  final color = activo ? Colors.white : ColoresApp.textoSecundario;
  return SizedBox(
    width: 30,
    height: 26,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(icon, size: size, color: color),
        if (sinLeer > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: ColoresApp.fondoSuperficie,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  sinLeer > 99 ? '99+' : '$sinLeer',
                  style: GoogleFonts.baloo2(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.iconAreaHeight,
  });

  final Widget icon;
  final Widget activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double iconAreaHeight;

  static const _textSpacing = 0.5;
  static final _textShadow = Shadow(
    color: Colors.black.withOpacity(0.15),
    offset: const Offset(0, 0.5),
    blurRadius: 1,
  );

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : ColoresApp.textoSecundario;
    return SizedBox.expand(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        minimumSize: const Size(0, 0),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          scale: isActive ? 1.0 : 0.98,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: iconAreaHeight,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: KeyedSubtree(
                      key: ValueKey<bool>(isActive),
                      child: isActive ? activeIcon : icon,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _textSpacing),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.1,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  shadows: isActive ? null : [_textShadow],
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARTELERA — Pantalla principal
// ============================================================================

class _PantallaCartelera extends StatefulWidget {
  const _PantallaCartelera();
  @override
  State<_PantallaCartelera> createState() => _PantallaCarteleraState();
}

class _PantallaCarteleraState extends State<_PantallaCartelera> {
  // ---- Estado de carga ----
  bool _cargando = true;
  bool _storiesYaMostrado = false;

  /// True hasta que confirmamos provincia+ciudad del usuario.
  /// Si quedan sin definir, NO disparamos consulta de eventos.
  bool _ubicacionLista = false;

  // ---- Datos crudos (de Supabase) ----
  List<Map<String, dynamic>> _eventos = const [];
  List<Map<String, dynamic>> _locales = const [];

  // ---- Filtros ----
  String _query = '';
  Set<String> _tiposSeleccionados = <String>{};
  FiltroTiempo _filtroTiempo = FiltroTiempo.todos;
  String _provinciaActiva = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudadesActivas = <String>{};

  // ---- UI ----
  int _seedShuffle = 0;
  bool _verMasNormal = false;

  @override
  void initState() {
    super.initState();
    _seedShuffle = DateTime.now().millisecondsSinceEpoch;
    ServicioEnlaceEvento.instancia.cambios.addListener(
      _consumirEnlaceEventoPendiente,
    );
    _arrancar();
  }

  @override
  void dispose() {
    ServicioEnlaceEvento.instancia.cambios.removeListener(
      _consumirEnlaceEventoPendiente,
    );
    super.dispose();
  }

  /// Flujo de arranque:
  /// 1. Lee provincia/ciudad del perfil del usuario.
  /// 2. Si faltan → modal obligatorio + bottomsheet (no cierra hasta elegir).
  /// 3. Persiste en perfiles_usuarios.
  /// 4. Recién ahí inicializa filtros y carga la cartelera.
  Future<void> _arrancar() async {
    final ok = await _asegurarUbicacionUsuario();
    if (!ok || !mounted) return;
    setState(() => _ubicacionLista = true);
    await _cargar();
  }

  Future<bool> _asegurarUbicacionUsuario() async {
    final sb = ServicioSupabase().cliente;
    final uid = ServicioSupabase().usuarioActual?.id;
    if (uid == null) return false;

    String? provincia;
    String? ciudad;
    try {
      final resp = await sb
          .from('perfiles_usuarios')
          .select('provincia, ciudad')
          .eq('id', uid)
          .maybeSingle();
      provincia = (resp?['provincia'] as String?)?.trim();
      ciudad = (resp?['ciudad'] as String?)?.trim();
    } catch (e) {
      debugPrint('⚠️ leer ubicacion perfil falló: $e');
    }

    final tieneUbicacion =
        (provincia?.isNotEmpty ?? false) && (ciudad?.isNotEmpty ?? false);

    if (tieneUbicacion) {
      _provinciaActiva = provincia!;
      _ciudadesActivas = {ciudad!};
      return true;
    }

    // Falta ubicación → pedir obligatoria con modal previo, después bottomsheet
    // que NO se puede cerrar sin elegir.
    if (!mounted) return false;
    await _mostrarModalUbicacionRequerida();
    if (!mounted) return false;

    while (mounted) {
      final res = await mostrarFiltroUbicacionesSheet(
        context,
        provinciaActual: UbicacionesData.provinciaPorDefecto,
        ciudadesActuales: const <String>{},
      );
      if (res != null && res.ciudades.isNotEmpty) {
        _provinciaActiva = res.provincia;
        _ciudadesActivas = res.ciudades;
        // Persistir en perfil (guardamos la primera ciudad como principal)
        try {
          await sb
              .from('perfiles_usuarios')
              .update({
                'provincia': res.provincia,
                'ciudad': res.ciudades.first,
              })
              .eq('id', uid);
        } catch (e) {
          debugPrint('⚠️ guardar ubicacion perfil falló: $e');
        }
        return true;
      }
      // Cerró sin elegir → re-mostrar modal y volver a abrir bottomsheet
      if (!mounted) return false;
      await _mostrarModalUbicacionRequerida();
    }
    return false;
  }

  Future<void> _mostrarModalUbicacionRequerida() async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Elegí tu ubicación'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Necesitamos tu provincia y ciudad para mostrarte la cartelera. '
            'Es obligatorio para continuar.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Elegir ubicación'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CARGA DE DATOS
  // ==========================================================================

  Future<void> _cargar({bool refrescando = false}) async {
    if (!refrescando) setState(() => _cargando = true);
    try {
      final sb = ServicioSupabase().cliente;
      final idsConPromo = await _obtenerEventosConPromosActivas(sb);
      final rows = await _consultarEventosPublicados(sb);
      final idsLocales = rows
          .map((r) => r['id_local']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final localesPorId = await _obtenerLocalesPorIds(sb, idsLocales);

      final eventos = rows
          .map<Map<String, dynamic>?>((r) {
            final row = Map<String, dynamic>.from(r as Map);
            final idLocal = row['id_local']?.toString().trim();
            final perfilEmbedded = _perfilEmbeddedDesdeFila(row);
            final keyLocal = _claveIdLocal(idLocal);
            final perfil =
                perfilEmbedded ??
                (keyLocal != null ? localesPorId[keyLocal] : null);
            // Guard moderación: si el local está pausado, el evento no va a
            // cartelera (cubre el fallback sin-embed donde no filtró la query).
            if (perfil != null &&
                perfil['estado_cuenta']?.toString() == 'pausada') {
              return null;
            }
            final cupoMax = row['cupo_lista_max'] as int?;
            final cupoUsados = (row['cupo_lista_usados'] as int?) ?? 0;
            final cuposLibres = cupoMax != null ? (cupoMax - cupoUsados) : null;
            final idEvento = row['id_evento']?.toString() ?? '';
            final promoFromFlag = row['tiene_promo'] == true;
            final promoFromRel = idsConPromo.contains(idEvento);
            final avatarPath = _primerCampoNoVacio(perfil, const [
              'foto_perfil_url',
              'url_foto_banner',
              'foto_local_1',
              'foto_local_2',
              'foto_local_3',
            ]);
            final nombreLocal =
                (_primerCampoNoVacio(perfil, const [
                          'nombre_local',
                          'local_username',
                        ]) ??
                        '')
                    .trim();
            final nombreFallback = nombreLocal.isNotEmpty
                ? nombreLocal
                : 'Local';
            return {
              'id': idEvento,
              'titulo': row['titulo_evento'] ?? '',
              'descripcion': row['descripcion_evento'] ?? '',
              'flyer': row['url_flyer'] ?? '',
              'nombreLocal': nombreFallback,
              'avatarLocal': avatarPath != null && avatarPath.isNotEmpty
                  ? _resolverAvatarLocal(sb, avatarPath)
                  : '',
              'idLocal': idLocal,
              'localVerificado': perfil != null
                  ? _parseBool(perfil['local_verificado'])
                  : false,
              'jerarquia': row['jerarquia'] ?? 'gratis',
              'tipoEvento': (row['tipo_evento']?.toString() ?? 'otro')
                  .toLowerCase(),
              'tienePromo': promoFromFlag || promoFromRel,
              'cupoMax': cupoMax,
              'cuposLibres': cuposLibres,
              'cupoLimitado': cupoMax != null,
              'modoLista': row['modo_lista'] ?? 'auto',
              'fechaInicio': row['fecha_inicio'],
              'fechaFin': row['fecha_fin'],
              'diaSemana': row['dia_semana']?.toString().toLowerCase(),
              'ciudadEvento': row['ciudad_evento']?.toString(),
              'provinciaEvento': row['provincia_evento']?.toString(),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final locales = await _cargarLocalesPopulares(sb, idsLocales);

      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        _locales = locales;
        _cargando = false;
        _seedShuffle = DateTime.now().millisecondsSinceEpoch;
      });

      _consumirEnlaceEventoPendiente();

      // Disparar stories de top_ultra una sola vez por sesión visual
      if (!_storiesYaMostrado) {
        _storiesYaMostrado = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _abrirTopUltraStories(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ cartelera _cargar: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<List<dynamic>> _consultarEventosPublicados(SupabaseClient sb) async {
    const baseSinEmbed =
        'id_evento, titulo_evento, descripcion_evento, url_flyer, fecha_inicio, fecha_fin, '
        'jerarquia, tipo_evento, tiene_promo, cupo_lista_max, cupo_lista_usados, modo_lista, '
        'id_local, ciudad_evento, provincia_evento, dia_semana';
    // !inner + filtro estado_cuenta: oculta de cartelera los eventos de locales
    // bloqueados por moderación (cuenta pausada) sin tocar el evento.
    const baseConEmbed =
        '$baseSinEmbed, '
        'perfiles_locales!eventos_id_local_fkey!inner('
        'id, nombre_local, local_username, local_verificado, foto_perfil_url, url_foto_banner, '
        'foto_local_1, foto_local_2, foto_local_3, rubro, ciudad, provincia, estado_cuenta'
        ')';
    // Red de seguridad (defense-in-depth): además del estado, ocultamos los que
    // ya pasaron su fecha_fin_publicacion aunque el cron todavía no los haya
    // marcado 'finalizado' (el cron corre 2×/día → hasta 12h de lag posible).
    // Se conservan los de fecha_fin_publicacion NULL (eventos legacy).
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final filtroVigencia =
        'fecha_fin_publicacion.gt.$nowIso,fecha_fin_publicacion.is.null';
    try {
      return await sb
          .from('eventos')
          .select(baseConEmbed)
          .eq('estado_publicacion', 'publicado')
          .eq('perfiles_locales.estado_cuenta', 'activa')
          .or(filtroVigencia)
          .order('fecha_inicio', ascending: true);
    } catch (_) {
      return await sb
          .from('eventos')
          .select(baseSinEmbed)
          .eq('estado_publicacion', 'publicado')
          .or(filtroVigencia)
          .order('fecha_inicio', ascending: true);
    }
  }

  Future<Set<String>> _obtenerEventosConPromosActivas(SupabaseClient sb) async {
    try {
      final rows = await sb
          .from('promociones')
          .select('id_evento')
          .eq('estado_promocion', 'activa');
      return (rows as List)
          .map((r) => r['id_evento']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<Map<String, Map<String, dynamic>>> _obtenerLocalesPorIds(
    SupabaseClient sb,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await sb
          .from('perfiles_locales')
          .select(
            'id, nombre_local, local_username, local_verificado, foto_perfil_url, url_foto_banner, foto_local_1, foto_local_2, foto_local_3, rubro, ciudad, provincia, estado_cuenta',
          )
          .inFilter('id', ids);
      final map = <String, Map<String, dynamic>>{};
      for (final raw in (rows as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final key = _claveIdLocal(row['id']);
        if (key != null && key.isNotEmpty) map[key] = row;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _cargarLocalesPopulares(
    SupabaseClient sb,
    List<String> idsPrioritariosCartelera,
  ) async {
    try {
      const sel =
          'id, nombre_local, local_username, local_verificado, foto_perfil_url, '
          'url_foto_banner, foto_local_1, foto_local_2, rubro, ciudad, provincia';
      Map<String, dynamic> empacar(Map<String, dynamic> local) {
        final rubroRaw = local['rubro'];
        String? rubro;
        if (rubroRaw is List && rubroRaw.isNotEmpty) {
          rubro = rubroRaw.first?.toString();
        } else if (rubroRaw is String) {
          rubro = rubroRaw;
        }
        return {
          'idLocal': local['id']?.toString(),
          'nombre':
              _primerCampoNoVacio(local, const [
                'nombre_local',
                'local_username',
              ]) ??
              'Local',
          'avatar': _resolverAvatarLocal(
            sb,
            _primerCampoNoVacio(local, const [
              'foto_perfil_url',
              'url_foto_banner',
              'foto_local_1',
              'foto_local_2',
            ]),
          ),
          'verificado': _parseBool(local['local_verificado']),
          'rubro': rubro,
          'ciudad': local['ciudad']?.toString(),
          'provincia': local['provincia']?.toString(),
        };
      }

      // Random orden: primero los IDs de cartelera, luego completar
      List<Map<String, dynamic>> resultado = [];
      final vistos = <String>{};

      if (idsPrioritariosCartelera.isNotEmpty) {
        final rows = await sb
            .from('perfiles_locales')
            .select(sel)
            .inFilter('id', idsPrioritariosCartelera)
            .eq('estado_cuenta', 'activa')
            .limit(40);
        for (final raw in rows as List) {
          final local = Map<String, dynamic>.from(raw as Map);
          final id = _claveIdLocal(local['id']) ?? '';
          if (id.isEmpty || !vistos.add(id)) continue;
          resultado.add(empacar(local));
        }
      }

      if (resultado.length < 24) {
        try {
          final extra = await sb
              .from('perfiles_locales')
              .select(sel)
              .eq('estado_cuenta', 'activa')
              .limit(60);
          for (final raw in extra as List) {
            final local = Map<String, dynamic>.from(raw as Map);
            final id = _claveIdLocal(local['id']) ?? '';
            if (id.isEmpty || !vistos.add(id)) continue;
            resultado.add(empacar(local));
            if (resultado.length >= 36) break;
          }
        } catch (_) {}
      }

      // Shuffle al final
      resultado.shuffle(math.Random(_seedShuffle));
      return resultado;
    } catch (e) {
      debugPrint('⚠️ locales populares: $e');
      return [];
    }
  }

  Map<String, dynamic>? _perfilEmbeddedDesdeFila(dynamic r) {
    if (r is! Map) return null;
    final m = Map<String, dynamic>.from(r);
    final embedded = m['perfiles_locales'];
    if (embedded is Map) return Map<String, dynamic>.from(embedded);
    if (embedded is List && embedded.isNotEmpty && embedded.first is Map) {
      return Map<String, dynamic>.from(embedded.first as Map);
    }
    return null;
  }

  // ==========================================================================
  // FILTROS
  // ==========================================================================

  bool _coincideQuery(Map<String, dynamic> e) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final t = (e['titulo']?.toString().toLowerCase() ?? '');
    final n = (e['nombreLocal']?.toString().toLowerCase() ?? '');
    final d = (e['descripcion']?.toString().toLowerCase() ?? '');
    return t.contains(q) || n.contains(q) || d.contains(q);
  }

  bool _coincideTipoEvento(Map<String, dynamic> e) {
    if (_tiposSeleccionados.isEmpty) return true;
    final tipo = (e['tipoEvento']?.toString() ?? '').toLowerCase();
    return _tiposSeleccionados.contains(tipo);
  }

  bool _coincideCiudad(Map<String, dynamic> e) {
    // Cartelera estricta: sin ciudades activas → no se muestra nada
    // (no debería ocurrir porque _arrancar() bloquea hasta tener ubicación).
    if (_ciudadesActivas.isEmpty) return false;
    final c = (e['ciudadEvento']?.toString().trim() ?? '');
    // Evento sin ciudad cargada → NO se muestra. Los locales deben cargar ciudad
    // obligatoriamente al subir el evento (edge `subir_evento` aplica default).
    if (c.isEmpty) return false;
    return _ciudadesActivas.contains(c);
  }

  bool _coincideTiempo(Map<String, dynamic> e) {
    if (_filtroTiempo == FiltroTiempo.todos) return true;
    final fechaRaw = e['fechaInicio']?.toString();
    if (fechaRaw == null || fechaRaw.isEmpty) return false;
    final fecha = DateTime.tryParse(fechaRaw);
    if (fecha == null) return false;
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    switch (_filtroTiempo) {
      case FiltroTiempo.todos:
        return true;
      case FiltroTiempo.hoy:
        return fecha.year == hoy.year &&
            fecha.month == hoy.month &&
            fecha.day == hoy.day;
      case FiltroTiempo.estaSemana:
        final fin = inicioHoy.add(const Duration(days: 7));
        return !fecha.isBefore(inicioHoy) && fecha.isBefore(fin);
      case FiltroTiempo.esteFinde:
        // viernes(5), sábado(6), domingo(7) más próximos
        final findeDias = _proximosViernesSabadoDomingo(inicioHoy);
        return findeDias.any(
          (d) =>
              d.year == fecha.year &&
              d.month == fecha.month &&
              d.day == fecha.day,
        );
    }
  }

  List<DateTime> _proximosViernesSabadoDomingo(DateTime base) {
    // Si hoy ya es vie/sáb/dom, los incluye desde hoy.
    final hoy = DateTime(base.year, base.month, base.day);
    // Buscar el viernes más cercano hacia adelante (incluyendo hoy si es vier).
    int dow(DateTime d) => d.weekday; // 1=Lun ... 7=Dom
    DateTime vie = hoy;
    while (dow(vie) != DateTime.friday) {
      vie = vie.add(const Duration(days: 1));
    }
    return [
      vie,
      vie.add(const Duration(days: 1)),
      vie.add(const Duration(days: 2)),
    ];
  }

  List<Map<String, dynamic>> _eventosFiltrados() {
    return _eventos
        .where((e) => _coincideQuery(e))
        .where(_coincideTipoEvento)
        .where(_coincideCiudad)
        .where(_coincideTiempo)
        .toList();
  }

  // ==========================================================================
  // ACCIONES
  // ==========================================================================

  Future<void> _onPullToRefresh() async {
    HapticFeedback.selectionClick();
    await _cargar(refrescando: true);
  }

  Future<void> _abrirFiltroUbicaciones() async {
    final res = await mostrarFiltroUbicacionesSheet(
      context,
      provinciaActual: _provinciaActiva,
      ciudadesActuales: _ciudadesActivas,
    );
    // Cartelera estricta: NUNCA quedar sin ciudad. Si el user vacía la selección
    // o cierra sin aplicar, mantenemos el estado anterior.
    if (res != null && res.ciudades.isNotEmpty && mounted) {
      setState(() {
        _provinciaActiva = res.provincia;
        _ciudadesActivas = res.ciudades;
      });
      // Persistir la ciudad principal en el perfil (la primera seleccionada).
      final uid = ServicioSupabase().usuarioActual?.id;
      if (uid != null) {
        try {
          await ServicioSupabase().cliente
              .from('perfiles_usuarios')
              .update({
                'provincia': res.provincia,
                'ciudad': res.ciudades.first,
              })
              .eq('id', uid);
        } catch (e) {
          debugPrint('⚠️ persistir ubicacion (filtro GPS) falló: $e');
        }
      }
    }
  }

  void _abrirTopUltraStories() {
    final ultras = _eventos
        .where(
          (e) =>
              (e['jerarquia']?.toString() ?? '') ==
              JerarquiasData.topUltra.slug,
        )
        .map(
          (e) => EventoTopUltra(
            idEvento: e['id']?.toString() ?? '',
            tituloEvento: e['titulo']?.toString() ?? 'Evento',
            urlFlyer: e['flyer']?.toString() ?? '',
            nombreLocal: e['nombreLocal']?.toString() ?? 'Local',
            avatarLocal: e['avatarLocal']?.toString(),
            fechaTexto: _fechaCortaTexto(e['fechaInicio']?.toString()),
          ),
        )
        .toList();
    if (ultras.isEmpty) return;
    mostrarTopUltraStoriesOverlay(
      context,
      eventos: ultras,
      onVerEvento: (id) => _irAEvento(id),
    );
  }

  void _irAEvento(String idEvento) {
    final ev = _eventos.firstWhere(
      (e) => e['id'] == idEvento,
      orElse: () => <String, dynamic>{},
    );
    if (ev.isEmpty) return;
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => PantallaVerEvento(evento: ev)));
  }

  void _consumirEnlaceEventoPendiente() {
    final id = ServicioEnlaceEvento.instancia.tomarPendiente();
    if (id == null || id.isEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final enCartelera = _eventos.any((e) => e['id']?.toString() == id);
      if (enCartelera) {
        _irAEvento(id);
        return;
      }
      await abrirEventoCompartidoPorId(context, id);
    });
  }

  void _irALocal(Map<String, dynamic> local) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaLocalPerfil(
          avatarUrl: local['avatar']?.toString() ?? '',
          nombreLocal: local['nombre']?.toString() ?? 'Local',
          idLocal: local['idLocal']?.toString(),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      // El skeleton ya trae su propio Scaffold+SafeArea+CustomScrollView,
      // así que lo devolvemos tal cual (no lo envolvemos).
      return const SkeletonPantallaCartelera();
    }
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<Color>(
          valueListenable: TemaFernecito.instancia.colorActual,
          builder: (context, _, __) {
            return Stack(
              children: [
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Pull-to-refresh nativo de Cupertino (no requiere MaterialLocalizations).
                    CupertinoSliverRefreshControl(onRefresh: _onPullToRefresh),
                    ..._buildSlivers(),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: homeFabBottomOffset(context),
                  child: _BotonScannerInvitacion(
                    onTap: _abrirScannerInvitacion,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _abrirScannerInvitacion() async {
    final res = await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const PantallaScannerInvitacion()),
    );
    if (!mounted || res is! ResultadoInvitacionRrpp) return;
    final ev = _eventos.firstWhere(
      (e) => e['id'] == res.idEvento,
      orElse: () => <String, dynamic>{
        'id': res.idEvento,
        'titulo': res.nombreEvento ?? 'Evento',
      },
    );
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) =>
            PantallaVerEvento(evento: ev, idInvitacionRrpp: res.idInvitacion),
      ),
    );
  }

  List<Widget> _buildSlivers() {
    final filtrados = _eventosFiltrados();
    final tops = _porJerarquia(filtrados, JerarquiasData.top.slug);
    final recos = _porJerarquia(
      filtrados,
      JerarquiasData.recomendadoFernecito.slug,
    );
    // top_ultra también entra al carrusel TOP (además de stories)
    final ultras = _porJerarquia(filtrados, JerarquiasData.topUltra.slug);
    final topsTotales = [...ultras, ...tops]
      ..shuffle(math.Random(_seedShuffle));
    final normales = _porJerarquia(filtrados, JerarquiasData.normal.slug);
    final gratis = _porJerarquia(filtrados, JerarquiasData.gratis.slug);
    final localesPop = _localesPopularesFiltrados();
    final tieneTopUltra = _eventos.any(
      (e) => (e['jerarquia']?.toString() ?? '') == JerarquiasData.topUltra.slug,
    );

    return <Widget>[
      _buildHeader(),
      _buildBarraSpotlight(),
      const SliverPadding(padding: EdgeInsets.only(top: 6)),
      // Badge Top Ultra (reabre stories) — arriba de la sección TOP
      if (tieneTopUltra)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TopUltraBadgeCartelera(onTap: _abrirTopUltraStories),
            ),
          ),
        ),
      // TOP (incluye top_ultra)
      if (topsTotales.isNotEmpty)
        _buildSeccionCarruseles(
          titulo: JerarquiasData.top.labelSeccion,
          icono: JerarquiasData.top.icono,
          eventos: topsTotales,
          porFila: CapacidadCartelera.topPorFila,
          variante: _Variante.grande,
        ),
      // RECOMENDADO FERNECITO
      if (recos.isNotEmpty)
        _buildSeccionCarruseles(
          titulo: JerarquiasData.recomendadoFernecito.labelSeccion,
          icono: JerarquiasData.recomendadoFernecito.icono,
          eventos: recos,
          porFila: CapacidadCartelera.recomendadoPorFila,
          variante: _Variante.mediano,
        ),
      // LUGARES POPULARES (entre recomendado y normal)
      if (localesPop.isNotEmpty) _buildSeccionLocalesPopulares(localesPop),
      // NORMAL (Destacados en tu ciudad)
      if (normales.isNotEmpty) _buildSeccionCarruselesNormal(eventos: normales),
      // GRID GRATIS
      if (gratis.isNotEmpty) _buildSeccionGratisGrid(eventos: gratis),
      // Empty state si nada
      if (topsTotales.isEmpty &&
          recos.isEmpty &&
          normales.isEmpty &&
          gratis.isEmpty)
        _buildEmptyState(),
      SliverPadding(
        padding: EdgeInsets.only(
          bottom: homeCarteleraScrollBottomPadding(context),
        ),
      ),
    ];
  }

  List<Map<String, dynamic>> _porJerarquia(
    List<Map<String, dynamic>> source,
    String slug,
  ) {
    final lista = source
        .where((e) => e['jerarquia']?.toString() == slug)
        .toList();
    lista.shuffle(math.Random(_seedShuffle + slug.hashCode));
    return lista;
  }

  // ---- Header con título + GPS ----
  Widget _buildHeader() {
    final ciudadTexto = _ciudadesActivas.isEmpty
        ? _provinciaActiva
        : (_ciudadesActivas.length == 1
              ? _ciudadesActivas.first
              : '${_ciudadesActivas.length} ciudades');
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
        child: Row(
          children: [
            Text(
              'Cartelera',
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _abrirFiltroUbicaciones,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.fondoSuperficie.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _ciudadesActivas.isEmpty
                          ? ColoresApp.principalMarca.withOpacity(0.35)
                          : ColoresApp.principalMarca.withOpacity(0.75),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _ciudadesActivas.isEmpty
                            ? CupertinoIcons.location
                            : CupertinoIcons.location_solid,
                        size: 14,
                        color: ColoresApp.principalMarca,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          ciudadTexto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            color: ColoresApp.textoPrincipal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_ciudadesActivas.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ColoresApp.principalMarca,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_ciudadesActivas.length}',
                            style: GoogleFonts.baloo2(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraSpotlight() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: SpotlightSearchBar(
          queryActual: _query,
          onQueryChanged: (q) => setState(() => _query = q),
          tiposSeleccionados: _tiposSeleccionados,
          onTiposChanged: (s) => setState(() => _tiposSeleccionados = s),
          filtroTiempo: _filtroTiempo,
          onFiltroTiempoChanged: (f) => setState(() => _filtroTiempo = f),
        ),
      ),
    );
  }

  // ---- Sección carruseles por jerarquía (top / recomendado) ----
  Widget _buildSeccionCarruseles({
    required String titulo,
    required IconData icono,
    required List<Map<String, dynamic>> eventos,
    required int porFila,
    required _Variante variante,
  }) {
    // Split en grupos de `porFila`.
    final filas = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < eventos.length; i += porFila) {
      filas.add(eventos.sublist(i, math.min(i + porFila, eventos.length)));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TituloSeccion(icono: icono, titulo: titulo),
            for (var i = 0; i < filas.length; i++)
              _buildFilaCarrusel(
                filas[i],
                variante,
                mostrarLineaSeparadora: i < filas.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaCarrusel(
    List<Map<String, dynamic>> fila,
    _Variante variante, {
    bool mostrarLineaSeparadora = false,
  }) {
    final esGrande = variante == _Variante.grande;
    final altura = esGrande ? 380.0 : 285.0;
    final ancho = esGrande ? 240.0 : 175.0;
    return Column(
      children: [
        SizedBox(
          height: altura,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            physics: const BouncingScrollPhysics(),
            itemCount: fila.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final e = fila[i];
              final ev = _aEventoCartelera(e);
              if (esGrande) {
                return CardEventoGrande(
                  evento: ev,
                  ancho: ancho,
                  onTap: () => _irAEvento(ev.idEvento),
                );
              }
              return CardEventoMediano(
                evento: ev,
                ancho: ancho,
                onTap: () => _irAEvento(ev.idEvento),
              );
            },
          ),
        ),
        if (mostrarLineaSeparadora)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 0.5,
            color: ColoresApp.textoSecundario.withOpacity(0.12),
          ),
      ],
    );
  }

  // ---- Sección NORMAL con regla de "ver más" ----
  Widget _buildSeccionCarruselesNormal({
    required List<Map<String, dynamic>> eventos,
  }) {
    final porFila = CapacidadCartelera.normalPorFila;
    final iniciales = CapacidadCartelera.normalFilasIniciales * porFila;
    final mostrar = _verMasNormal ? eventos : eventos.take(iniciales).toList();
    final hayMas = eventos.length > iniciales;

    final filas = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < mostrar.length; i += porFila) {
      filas.add(mostrar.sublist(i, math.min(i + porFila, mostrar.length)));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TituloSeccion(
              icono: JerarquiasData.normal.icono,
              titulo: JerarquiasData.normal.labelSeccion,
            ),
            for (var i = 0; i < filas.length; i++)
              _buildFilaCarrusel(
                filas[i],
                _Variante.mediano,
                mostrarLineaSeparadora: i < filas.length - 1,
              ),
            if (hayMas)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _verMasNormal = !_verMasNormal),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresApp.textoPrincipal,
                    side: BorderSide(
                      color: ColoresApp.principalMarca.withOpacity(0.55),
                    ),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(
                    _verMasNormal
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                  ),
                  label: Text(
                    _verMasNormal ? 'Ver menos' : 'Ver más eventos',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _localesPopularesFiltrados() {
    if (_ciudadesActivas.isEmpty) return const [];
    return _locales
        .where((l) {
          final c = l['ciudad']?.toString().trim();
          if (c == null || c.isEmpty) return false;
          return _ciudadesActivas.contains(c);
        })
        .take(24)
        .toList();
  }

  // ---- Sección LUGARES POPULARES ----
  Widget _buildSeccionLocalesPopulares(List<Map<String, dynamic>> filtrados) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TituloSeccion(
              icono: CupertinoIcons.house_fill,
              titulo: 'Lugares populares',
            ),
            SizedBox(
              height: 142,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                physics: const BouncingScrollPhysics(),
                itemCount: filtrados.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final l = filtrados[i];
                  return CardLocalPopular(
                    idLocal: l['idLocal']?.toString() ?? '',
                    nombreLocal: l['nombre']?.toString() ?? 'Local',
                    urlAvatar: l['avatar']?.toString(),
                    rubro: l['rubro']?.toString(),
                    verificado: l['verificado'] == true,
                    onTap: () => _irALocal(l),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Grid GRATIS ----
  Widget _buildSeccionGratisGrid({
    required List<Map<String, dynamic>> eventos,
  }) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: _TituloSeccion(
              icono: JerarquiasData.gratis.icono,
              titulo: JerarquiasData.gratis.labelSeccion,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 9 / 13,
            ),
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final ev = _aEventoCartelera(eventos[i]);
              return CardEventoGrid(
                evento: ev,
                onTap: () => _irAEvento(ev.idEvento),
              );
            }, childCount: eventos.length),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.search,
                size: 56,
                color: ColoresApp.textoSecundario,
              ),
              const SizedBox(height: 16),
              Text(
                'No hay eventos para esos filtros',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Probá quitar alguna ciudad o limpiar los filtros.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: ColoresApp.textoSecundario,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HELPERS UI
  // ==========================================================================

  EventoCartelera _aEventoCartelera(Map<String, dynamic> e) {
    final iso = e['fechaInicio']?.toString();
    return EventoCartelera(
      idEvento: e['id']?.toString() ?? '',
      titulo: e['titulo']?.toString() ?? 'Evento',
      urlFlyer: e['flyer']?.toString() ?? '',
      nombreLocal: e['nombreLocal']?.toString() ?? 'Local',
      avatarLocal: e['avatarLocal']?.toString(),
      fechaTexto: _fechaCompletaTexto(iso),
      fechaCorta: _fechaSuperCorta(iso),
      jerarquia: e['jerarquia']?.toString(),
      tienePromo: e['tienePromo'] == true,
      cupoMax: e['cupoMax'] as int?,
      cuposLibres: e['cuposLibres'] as int?,
      localVerificado: e['localVerificado'] == true,
    );
  }

  /// "Vie 10 Sep · 21:00" — para cards grandes (TOP).
  String? _fechaCompletaTexto(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final f = DateTime.tryParse(iso);
    if (f == null) return null;
    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final meses = [
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
    final dia = dias[f.weekday - 1];
    final mes = meses[f.month - 1];
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    return '$dia ${f.day} $mes · $hh:$mm';
  }

  /// "Vie 10" — para cards medianas/grid (chocaba con promo si era larga).
  String? _fechaSuperCorta(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final f = DateTime.tryParse(iso);
    if (f == null) return null;
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[f.weekday - 1]} ${f.day}';
  }

  // Helper compat: lo usaba el código del bottomsheet de top_ultra antes de
  // diferenciar versiones. Lo redirijo a la versión completa.
  // ignore: unused_element
  String? _fechaCortaTexto(String? iso) => _fechaCompletaTexto(iso);
}

enum _Variante { grande, mediano }

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.icono, required this.titulo});
  final IconData icono;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Row(
        children: [
          Icon(icono, size: 18, color: ColoresApp.principalMarca),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: GoogleFonts.baloo2(
              color: ColoresApp.textoPrincipal,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// _CarruselAvataresLocales (preservado, usado por otras pantallas si aplica)
// ============================================================================

/// Carrusel de avatares de locales (solo logos circulares, sin título). Auto-scroll lento derecha a izquierda.
class _CarruselAvataresLocales extends StatefulWidget {
  // ignore: unused_element
  const _CarruselAvataresLocales({
    required this.locales,
    // ignore: unused_element_parameter
    this.autoScrollEnabled = false,
  });

  final List<Map<String, dynamic>> locales;
  final bool autoScrollEnabled;

  @override
  State<_CarruselAvataresLocales> createState() =>
      _CarruselAvataresLocalesState();
}

class _CarruselAvataresLocalesState extends State<_CarruselAvataresLocales> {
  late ScrollController _scrollController;
  Timer? _autoScrollTimer;
  bool _userScrolling = false;

  static const double _avatarSize = 77.28;
  static const double _spacing = 14;
  static const int _iconosPorTanda = 4;
  static const int _intervaloSegundos = 5;
  static const double _nombreHeight = 18;
  static const double _nombreTopSpacing = 6;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.position.isScrollingNotifier.addListener(
        _onScrollActivity,
      );
    });
    _autoScrollTimer = Timer.periodic(
      const Duration(seconds: _intervaloSegundos),
      (_) async {
        if (!mounted ||
            !widget.autoScrollEnabled ||
            _scrollController.hasClients == false ||
            _userScrolling) {
          return;
        }
        final maxOffset = _scrollController.position.maxScrollExtent;
        final paso = (_avatarSize + _spacing) * _iconosPorTanda;
        double next = _scrollController.offset + paso;
        final target = next > maxOffset ? maxOffset : next;
        if (!mounted) return;
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        if (next > maxOffset && mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
    );
  }

  void _onScrollActivity() {
    if (!_scrollController.hasClients) return;
    final scrolling = _scrollController.position.isScrollingNotifier.value;
    if (scrolling != _userScrolling && mounted) {
      setState(() => _userScrolling = scrolling);
    }
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      _scrollController.position.isScrollingNotifier.removeListener(
        _onScrollActivity,
      );
    }
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locales.isEmpty) return const SizedBox.shrink();
    final numLocales = widget.locales.length;
    final repetir = numLocales <= 1 ? 1 : 3;
    final itemCountTotal = numLocales * repetir;
    return SizedBox(
      height: _avatarSize + _nombreTopSpacing + _nombreHeight + 20,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: itemCountTotal,
        itemBuilder: (context, index) {
          final loc = widget.locales[index % numLocales];
          final avatar = (loc['avatar']?.toString() ?? '');
          final nombre = (loc['nombre']?.toString() ?? 'Local');
          final idLocal = loc['idLocal']?.toString();
          final verificado = loc['verificado'] == true;
          return Padding(
            padding: EdgeInsets.only(
              right: index < itemCountTotal - 1 ? _spacing : 20,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => PantallaLocalPerfil(
                      avatarUrl: avatar,
                      nombreLocal: nombre,
                      idLocal: idLocal,
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: _avatarSize,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _avatarSize,
                      height: _avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ColoresApp.principalMarca.withOpacity(0.9),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox.expand(
                          child: _esAssetUrl(avatar)
                              ? Image.asset(
                                  avatar,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.low,
                                  cacheWidth:
                                      (_avatarSize *
                                              MediaQuery.of(context)
                                                  .devicePixelRatio
                                                  .clamp(1.0, 2.0))
                                          .round(),
                                  errorBuilder: (_, __, ___) =>
                                      _avatarPlaceholderLocal(_avatarSize),
                                )
                              : CachedNetworkImage(
                                  imageUrl: avatar,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  memCacheWidth:
                                      (_avatarSize *
                                              MediaQuery.of(context)
                                                  .devicePixelRatio
                                                  .clamp(1.0, 2.0))
                                          .round(),
                                  placeholder: (_, __) =>
                                      _avatarPlaceholderLocal(_avatarSize),
                                  errorWidget: (_, __, ___) =>
                                      _avatarPlaceholderLocal(_avatarSize),
                                ),
                        ),
                      ),
                    ),
                    if (verificado)
                      Transform.translate(
                        offset: const Offset(24, -18),
                        child: const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 17,
                          color: Color(0xFF4DA3FF),
                        ),
                      ),
                    const SizedBox(height: _nombreTopSpacing),
                    SizedBox(
                      height: _nombreHeight,
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BotonScannerInvitacion extends StatelessWidget {
  const _BotonScannerInvitacion({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: kHomeFabQrSize,
        height: kHomeFabQrSize,
        child: ClipOval(
          clipBehavior: Clip.hardEdge,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: ValueListenableBuilder<Color>(
              valueListenable: TemaFernecito.instancia.colorActual,
              builder: (context, colorTema, _) => Center(
                child: Icon(
                  CupertinoIcons.qrcode_viewfinder,
                  color: colorTema,
                  size: 30,
                  shadows: [
                    Shadow(
                      color: colorTema.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
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
