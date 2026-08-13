/// Pantalla principal (Home) - Cartelera Fernecito.
///
/// Estructura:
/// - 5 tabs (Actividad, Social, Cartelera, Notificaciones, Mi Perfil).
/// - La cartelera de eventos (`_PantallaCartelera`) tiene:
///   * Header con título + botón GPS (filtra por ciudad/provincia)
///   * Barra Spotlight (search + filtros plan / tiempo)
///   * Top Ultra → modal stories al abrir
///   * Sección TOP (carruseles de 10 por fila, divide en filas si hay más)
///   * Sección ON FIRE PARA ESTE FINDE (top 5 locales tendencia)
///   * Sección RECOMENDADO FERNECITO (carruseles de 15 por fila)
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

import '../core/app_navigator.dart';
import '../core/bootstrap_cartelera.dart';
import '../core/busqueda_natural.dart';
import '../core/constants.dart';
import '../core/servicio_resena_post_visita.dart';
import '../core/jerarquias_data.dart';
import '../core/secciones_impresion.dart';
import '../core/servicio_estado_cuenta.dart';
import '../core/servicio_impresiones.dart';
import '../core/servicio_cartelera_locales.dart';
import '../core/mezcla_cartelera_locales.dart';
import '../models/local_cartelera_card.dart';
import '../core/servicio_notificaciones_usuarios.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/navegacion_evento_compartido.dart';
import '../core/servicio_enlace_evento.dart';
import '../core/supabase_client.dart';
import '../core/coordenadas_ciudades.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/preferencias_cartelera.dart';
import '../core/servicio_ubicacion_dispositivo.dart';
import '../core/sexo_perfil.dart';
import '../core/tema_fernecito.dart';
import '../core/ubicaciones_data.dart';
import '../widgets/avatar_local.dart';
import '../widgets/cards_cartelera.dart';
import '../widgets/card_local_cartelera.dart';
import '../widgets/carrusel_auto_scroll.dart';
import '../widgets/detector_impresion_cartelera.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/modal_resena_post_visita.dart';
import '../widgets/splash_carga_fernecito.dart';
import '../widgets/spotlight_search_bar.dart';
import '../widgets/busqueda_ia_sheet.dart';
import '../widgets/top_ultra_stories_overlay.dart';
import '../widgets/mapa_ui.dart';
import 'pantalla_actividad.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_mapa.dart';
import 'pantalla_mi_perfil.dart';
import 'pantalla_notificaciones.dart';
import 'pantalla_social.dart';
import 'pantalla_ver_evento.dart';
import 'pantalla_scanner_invitacion.dart';

// ============================================================================
// Helpers compartidos (top-level) que usaba la cartelera vieja.
// ============================================================================

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
const double kHomeTabBarHeight = 66.0;

/// Inset inferior del navbar: en iPhone no usar todo el safe area (queda mucho vacío).
double homeTabBarBottomInset(BuildContext context) {
  final safe = MediaQuery.paddingOf(context).bottom;
  if (safe <= 10) return safe;
  return (safe * 0.35).clamp(10.0, 14.0);
}

/// Espacio entre el pill flotante y el borde superior de la navbar.
const double kHomeFabGapSobreNav = 14.0;

/// Ancho del pill vertical (mapa + QR).
const double kHomeFabPillWidth = 52.0;

/// Alto del pill: dos zonas táctiles compactas.
const double kHomeFabPillHeight = 92.0;

double homeFabBottomOffset(BuildContext context) {
  return kHomeTabBarHeight +
      homeTabBarBottomInset(context) +
      kHomeFabGapSobreNav;
}

double homeCarteleraScrollBottomPadding(BuildContext context) {
  return homeFabBottomOffset(context) + kHomeFabPillHeight + 12;
}

class PantallaHome extends StatefulWidget {
  const PantallaHome({super.key});

  @override
  State<PantallaHome> createState() => _PantallaHomeState();
}

class _PantallaHomeState extends State<PantallaHome>
    with WidgetsBindingObserver {
  String? _fotoPerfilUrl;
  DateTime? _fotoPerfilAt;
  static const _ttlFotoPerfil = Duration(minutes: 5);
  int _currentTabIndex = 2;

  /// Se incrementa al entrar al tab Actividad para forzar `_cargarActividad` (IndexedStack no recrea el hijo).
  int _actividadReloadTick = 0;
  int _perfilReloadTick = 0;

  /// Se incrementa al entrar al tab Notificaciones para forzar recarga
  /// (IndexedStack no recrea el hijo).
  int _notifsReloadTick = 0;
  int _socialNavToken = 0;
  int? _socialAbrirAmigosSquadsTab;

  final _srvNotificaciones = ServicioNotificacionesUsuarios();

  void _irATabDesdeNotif(int tab, {SocialVista? socialVista}) {
    setState(() {
      _currentTabIndex = tab.clamp(0, 4);
      if (tab == 0) _actividadReloadTick++;
      if (tab == 1) {
        // Tab Social = hub nuevo. Amigos/Squads se abren encima.
        _socialAbrirAmigosSquadsTab = switch (socialVista) {
          SocialVista.amigos => 0,
          SocialVista.squads => 1,
          _ => null,
        };
        _socialNavToken++;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // El splash único vive en AppFernecito; acá solo cargamos datos.
    BootstrapCartelera.reset();
    ServicioPerfilUsuario().avatarNavbarUrl.addListener(_onAvatarNavbarCambio);
    _cargarFotoPerfil();
    _verificarCuentaPausada();
    _srvNotificaciones.refrescarContador();
  }

  @override
  void dispose() {
    ServicioPerfilUsuario().avatarNavbarUrl.removeListener(
      _onAvatarNavbarCambio,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAvatarNavbarCambio() {
    final url = ServicioPerfilUsuario().avatarNavbarUrl.value;
    if (!mounted) return;
    setState(() {
      _fotoPerfilUrl = url;
      _fotoPerfilAt = DateTime.now();
    });
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

  Future<void> _cargarFotoPerfil({bool forzar = false}) async {
    if (!forzar &&
        _fotoPerfilUrl != null &&
        _fotoPerfilAt != null &&
        DateTime.now().difference(_fotoPerfilAt!) < _ttlFotoPerfil) {
      return;
    }
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
          } else {
            _fotoPerfilUrl = null;
          }
          _fotoPerfilAt = DateTime.now();
        });
        // Sincroniza el notifier sin disparar recargas en bucle.
        final nav = ServicioPerfilUsuario().avatarNavbarUrl;
        if (nav.value != _fotoPerfilUrl) {
          nav.value = _fotoPerfilUrl;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando foto de perfil: $e');
    }
  }

  // Iconos más chicos + altura levemente reducida para look moderno tipo iOS 18 / Android 14
  static const double _kTabBarIconSize = 26.0;

  @override
  Widget build(BuildContext context) {
    // Splash único en AppFernecito; acá siempre el shell (puede estar tapado).
    return Stack(
      children: [
        const ColoredBox(
          color: ColoresApp.fondoPrincipal,
          child: SizedBox.expand(),
        ),
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
                // Siempre hub. Amigos/Squads van por push (abrirAmigosSquadsTab).
                vista: SocialVista.explorar,
                abrirAmigosSquadsTab: _socialAbrirAmigosSquadsTab,
              ),
            ),
            CupertinoTabView(builder: (context) => const _PantallaCartelera()),
            CupertinoTabView(
              builder: (context) => PantallaNotificaciones(
                reloadTick: _notifsReloadTick,
                onIrATab: _irATabDesdeNotif,
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
            builder: (context, accent, __) => _GlassTabBar(
              height: kHomeTabBarHeight,
              iconSize: _kTabBarIconSize,
              accentColor: accent,
              currentIndex: _currentTabIndex,
              onTap: (index) {
                if (_currentTabIndex == 2 && index != 2) {
                  ServicioImpresiones.instancia.alSalirCartelera();
                }
                setState(() {
                  _currentTabIndex = index;
                  if (index == 0) _actividadReloadTick++;
                  if (index == 1) {
                    // Tap manual al tab Social: hub limpio, sin auto-abrir Amigos.
                    _socialAbrirAmigosSquadsTab = null;
                    _socialNavToken++;
                  }
                  if (index == 2) _srvNotificaciones.refrescarContador();
                  if (index == 3) {
                    _notifsReloadTick++;
                    _srvNotificaciones.refrescarContador(forzar: true);
                  }
                  if (index == 4) _perfilReloadTick++;
                });
              },
              fotoPerfilUrl: _fotoPerfilUrl,
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de tabs inferior con glassmorphism (blur + tinte oscuro semitransparente).
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({
    required this.height,
    required this.iconSize,
    required this.accentColor,
    required this.currentIndex,
    required this.onTap,
    this.fotoPerfilUrl,
  });

  final double height;
  final double iconSize;
  final Color accentColor;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? fotoPerfilUrl;

  static const _topRadius = 12.0;
  static const _dotSize = 5.5;
  static const _dotTop = 5.0;
  static const _tabsVerticalPadding = 10.0;

  /// Social y Cartelera un poco más grandes para equilibrar la campana.
  static const _iconBoostSocialCartelera = 1.10;

  Widget _tab({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required double iconSizeTab,
    bool prominentWhenInactive = false,
    double iconSizeScale = 1.0,
  }) {
    return Expanded(
      child: _TabItem(
        icon: icon,
        activeIcon: activeIcon,
        label: label,
        isActive: currentIndex == index,
        onTap: () => onTap(index),
        iconSize: iconSizeTab * iconSizeScale,
        accentColor: accentColor,
        prominentWhenInactive: prominentWhenInactive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = homeTabBarBottomInset(context);
    final totalHeight = height + bottomInset;
    final iconSizeTab = iconSize * 0.94;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(_topRadius),
      ),
      child: SizedBox(
        width: double.infinity,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1E1E22).withValues(alpha: 0.62),
                          const Color(0xFF111114).withValues(alpha: 0.82),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _tabsVerticalPadding,
              bottom: bottomInset,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tab(
                    icon: CupertinoIcons.calendar,
                    activeIcon: CupertinoIcons.calendar_today,
                    label: 'Actividad',
                    index: 0,
                    iconSizeTab: iconSizeTab,
                  ),
                  _tab(
                    icon: CupertinoIcons.person_2,
                    activeIcon: CupertinoIcons.person_2_fill,
                    label: 'Social',
                    index: 1,
                    iconSizeTab: iconSizeTab,
                    iconSizeScale: _iconBoostSocialCartelera,
                  ),
                  _tab(
                    icon: CupertinoIcons.ticket,
                    activeIcon: CupertinoIcons.ticket_fill,
                    label: 'Cartelera',
                    index: 2,
                    iconSizeTab: iconSizeTab,
                    prominentWhenInactive: true,
                    iconSizeScale: _iconBoostSocialCartelera,
                  ),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable:
                          ServicioNotificacionesUsuarios().contadorNoLeidas,
                      builder: (context, sinLeer, _) {
                        return _TabItem(
                          customIcon: _iconoNotificacionesConBadge(
                            CupertinoIcons.bell,
                            sinLeer: sinLeer,
                            size: iconSizeTab,
                            activo: false,
                            accentColor: accentColor,
                          ),
                          customActiveIcon: _iconoNotificacionesConBadge(
                            CupertinoIcons.bell_fill,
                            sinLeer: sinLeer,
                            size: iconSizeTab,
                            activo: true,
                            accentColor: accentColor,
                          ),
                          label: 'Novedades',
                          isActive: currentIndex == 3,
                          onTap: () => onTap(3),
                          iconSize: iconSizeTab,
                          accentColor: accentColor,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _TabItem(
                      customIcon: fotoPerfilUrl != null
                          ? _avatarWidget(
                              fotoPerfilUrl!,
                              active: false,
                              size: iconSizeTab,
                              accentColor: accentColor,
                            )
                          : Icon(
                              CupertinoIcons.person_circle,
                              size: iconSizeTab,
                              color: ColoresApp.textoSecundario,
                            ),
                      customActiveIcon: fotoPerfilUrl != null
                          ? _avatarWidget(
                              fotoPerfilUrl!,
                              active: true,
                              size: iconSizeTab,
                              accentColor: accentColor,
                            )
                          : Icon(
                              CupertinoIcons.person_circle_fill,
                              size: iconSizeTab,
                              color: accentColor,
                            ),
                      label: 'Perfil',
                      isActive: currentIndex == 4,
                      onTap: () => onTap(4),
                      iconSize: iconSizeTab,
                      accentColor: accentColor,
                      activeScaleOverride: 0.96,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _tabsVerticalPadding + 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segmentWidth = constraints.maxWidth / 5;
                  final dotLeft =
                      segmentWidth * currentIndex +
                      (segmentWidth - _dotSize) / 2;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        left: dotLeft,
                        top: _dotTop,
                        width: _dotSize,
                        height: _dotSize,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.65),
                                  blurRadius: 6,
                                  spreadRadius: 0.4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarWidget(
    String url, {
    required bool active,
    required Color accentColor,
    double? size,
  }) {
    final s = size ?? iconSize;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active
              ? accentColor
              : ColoresApp.textoSecundario.withValues(alpha: 0.55),
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
  required Color accentColor,
}) {
  final color = activo ? accentColor : ColoresApp.textoSecundario;
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

class _TabItem extends StatefulWidget {
  const _TabItem({
    this.icon,
    this.activeIcon,
    this.customIcon,
    this.customActiveIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.iconSize,
    required this.accentColor,
    this.prominentWhenInactive = false,
    this.activeScaleOverride,
  });

  final IconData? icon;
  final IconData? activeIcon;
  final Widget? customIcon;
  final Widget? customActiveIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final double iconSize;
  final Color accentColor;

  /// Ícono central (Cartelera) un poco más grande cuando no está activo.
  final bool prominentWhenInactive;

  /// Escala al activar distinta a la default (ej. avatar de perfil).
  final double? activeScaleOverride;

  static const _activeScale = 1.2;
  static const _inactiveScale = 1.0;
  static const _prominentInactiveScale = 1.08;
  static const _pressedScaleFactor = 0.92;
  static const _iconTop = 6.0;
  static const _labelGap = 8.0;
  static const _labelSlotHeight = 19.0;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _pressed = false;

  double get _baseScale {
    if (widget.isActive) {
      return widget.activeScaleOverride ?? _TabItem._activeScale;
    }
    if (widget.prominentWhenInactive) return _TabItem._prominentInactiveScale;
    return _TabItem._inactiveScale;
  }

  double get _targetScale =>
      _pressed ? _baseScale * _TabItem._pressedScaleFactor : _baseScale;

  Widget _icono(bool activo) {
    if (activo && widget.customActiveIcon != null) {
      return widget.customActiveIcon!;
    }
    if (!activo && widget.customIcon != null) {
      return widget.customIcon!;
    }
    final size =
        widget.iconSize *
        (widget.prominentWhenInactive && !activo ? 1.06 : 1.0);
    return Icon(
      activo ? widget.activeIcon! : widget.icon!,
      size: size,
      color: activo ? widget.accentColor : ColoresApp.textoSecundario,
    );
  }

  Widget _slotEtiqueta() {
    return ClipRect(
      child: SizedBox(
        height: widget.isActive ? _TabItem._labelSlotHeight : 0,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) {
            final slide =
                Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                );
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: widget.isActive
              ? Padding(
                  key: ValueKey<String>('lbl-${widget.label}'),
                  padding: const EdgeInsets.only(top: _TabItem._labelGap),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                )
              : SizedBox.shrink(
                  key: ValueKey<String>('lbl-off-${widget.label}'),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: ClipRect(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: _TabItem._iconTop),
            AnimatedScale(
              scale: _targetScale,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey<bool>(widget.isActive),
                  child: _icono(widget.isActive),
                ),
              ),
            ),
            _slotEtiqueta(),
          ],
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
  bool _pedidoSexoArranqueHecho = false;

  // ---- Datos crudos (de Supabase) ----
  List<Map<String, dynamic>> _eventos = const [];
  List<Map<String, dynamic>> _locales = const [];
  List<LocalCarteleraCard> _poolLocalesCartelera = const [];

  // ---- Filtros ----
  String _query = '';
  Set<String> _tiposSeleccionados = <String>{};
  FiltroTiempo _filtroTiempo = FiltroTiempo.todos;
  String _provinciaActiva = UbicacionesData.provinciaPorDefecto;
  Set<String> _ciudadesActivas = <String>{};

  /// Capa previa al filtro: GPS elige ciudades hardcode ≤20 km.
  /// La query/filtro de cartelera siguen igual; solo cambia el set de ciudades.
  bool _carteleraInteligente = false;

  // ---- UI ----
  int _seedShuffle = 0;
  bool _verMasNormal = false;

  @override
  void initState() {
    super.initState();
    _seedShuffle = DateTime.now().millisecondsSinceEpoch;
    ServicioImpresiones.instancia.asegurarTimer();
    ServicioEnlaceEvento.instancia.cambios.addListener(
      _consumirEnlaceEventoPendiente,
    );
    _arrancar();
  }

  @override
  void dispose() {
    ServicioImpresiones.instancia.alSalirCartelera();
    ServicioEnlaceEvento.instancia.cambios.removeListener(
      _consumirEnlaceEventoPendiente,
    );
    super.dispose();
  }

  /// Flujo de arranque:
  /// 1. Lee provincia/ciudad del perfil del usuario.
  /// 2. Si faltan → modal obligatorio + bottomsheet (no cierra hasta elegir).
  /// 3. Persiste en perfiles_usuarios.
  /// 4. Si “cartelera inteligente” estaba activa → resuelve ciudades por GPS
  ///    (misma lista hardcode) y las usa como set de filtro.
  /// 5. Si falta género → modal con Hombre/Mujer/Otro (se puede posponer).
  /// 6. Recién ahí carga la cartelera (query igual que siempre).
  Future<void> _arrancar() async {
    final ok = await _asegurarUbicacionUsuario();
    if (!ok || !mounted) {
      // No bloquear el splash para siempre (sin sesión / canceló ubicación).
      if (mounted) setState(() => _cargando = false);
      BootstrapCartelera.marcarLista();
      return;
    }
    await PreferenciasCartelera.instancia.cargar();
    await _aplicarModoUbicacionAlArrancar();
    if (!mounted) return;
    setState(() => _ubicacionLista = true);
    await _asegurarSexoUsuario();
    if (!mounted) return;
    await _cargar();
  }

  /// Perfiles viejos sin `sexo`: pide género al abrir la app (una vez por sesión).
  Future<void> _asegurarSexoUsuario() async {
    if (_pedidoSexoArranqueHecho) return;
    _pedidoSexoArranqueHecho = true;

    final sb = ServicioSupabase().cliente;
    final uid = ServicioSupabase().usuarioActual?.id;
    if (uid == null || !mounted) return;

    String? sexo;
    try {
      final resp = await sb
          .from('perfiles_usuarios')
          .select('sexo')
          .eq('id', uid)
          .maybeSingle();
      sexo = SexoPerfil.normalizar(resp?['sexo']);
    } catch (e) {
      debugPrint('⚠️ leer sexo perfil falló: $e');
      return;
    }

    if (SexoPerfil.esValido(sexo) || !mounted) return;

    final elegido = await mostrarDialogoPedirSexo(context);
    if (!mounted || elegido == null || !SexoPerfil.esValido(elegido)) return;

    try {
      await sb
          .from('perfiles_usuarios')
          .update({'sexo': elegido})
          .eq('id', uid);
    } catch (e) {
      debugPrint('⚠️ guardar sexo perfil falló: $e');
    }
  }

  /// Capa previa: si el modo inteligente está guardado, intenta GPS y arma el
  /// set de ciudades hardcode a ≤20 km. Si falla, mantiene la ciudad del perfil.
  Future<void> _aplicarModoUbicacionAlArrancar() async {
    final prefs = PreferenciasCartelera.instancia;
    _carteleraInteligente = prefs.inteligenteActiva;
    if (!_carteleraInteligente) {
      if (prefs.ciudadesCustom.isNotEmpty) {
        _ciudadesActivas = {...prefs.ciudadesCustom};
        _provinciaActiva = prefs.provinciaCustom ?? _provinciaActiva;
      }
      return;
    }

    try {
      final gps = await ServicioUbicacionDispositivo.instancia
          .iniciarDesdeGestoUsuario();
      if (gps.exito && gps.latitud != null && gps.longitud != null) {
        final cercanas = CoordenadasCiudades.ciudadesCercanas(
          latitud: gps.latitud!,
          longitud: gps.longitud!,
          radioKm: PreferenciasCartelera.radioKmDefault,
        );
        if (cercanas.isNotEmpty) {
          _ciudadesActivas = cercanas.toSet();
          _provinciaActiva =
              CoordenadasCiudades.provinciaDeCiudad(cercanas.first) ??
              _provinciaActiva;
          // Guarda el set del radio + la más cercana como principal en el perfil.
          await ServicioUbicacionGlobal.aplicarInteligente(
            ciudades: _ciudadesActivas,
            provincia: _provinciaActiva,
            principal: cercanas.first,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ cartelera inteligente al arrancar: $e');
    }
    // Fallback: queda la ciudad del perfil (ya seteada en _asegurarUbicacionUsuario).
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
        _carteleraInteligente = res.carteleraInteligente;
        // Persistir set local + ciudad principal en el perfil (fuente de verdad).
        if (res.carteleraInteligente) {
          await ServicioUbicacionGlobal.aplicarInteligente(
            ciudades: res.ciudades,
            provincia: res.provincia,
            principal: res.ciudadPrincipal,
          );
        } else {
          await ServicioUbicacionGlobal.aplicarManual(
            provincia: res.provincia,
            ciudades: res.ciudades,
            principal: res.ciudadPrincipal,
          );
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
      // Promos (Q1) y eventos (Q2) son independientes → se piden EN PARALELO.
      final promosFut = _obtenerEventosConPromosActivas(sb);
      final rowsFut = _consultarEventosPublicados(sb);
      final idsConPromo = await promosFut;
      final rows = await rowsFut;
      final idsLocales = rows
          .map((r) => r['id_local']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      // El embed de Q2 YA trae el perfil del local (perfiles_locales!inner).
      // Solo si cayó al fallback sin-embed pedimos los locales aparte: así
      // evitamos una consulta redundante que repetía todos los perfiles.
      final usoEmbed =
          rows.isNotEmpty && _perfilEmbeddedDesdeFila(rows.first) != null;
      final localesPorIdFut = usoEmbed
          ? Future<Map<String, Map<String, dynamic>>>.value(
              const <String, Map<String, dynamic>>{},
            )
          : _obtenerLocalesPorIds(sb, idsLocales);
      // Lugares populares (Q4) y pool semanal de locales cartelera en paralelo.
      final localesPopFut = _cargarLocalesPopulares(sb, idsLocales);
      final poolLocalesFut = _ciudadesActivas.isEmpty
          ? Future<List<LocalCarteleraCard>>.value(const [])
          : ServicioCarteleraLocales.instancia.obtenerPorCiudades(
              _ciudadesActivas,
            );
      final localesPorId = await localesPorIdFut;

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
              'rubroLocal': perfil?['rubro'],
              'avatarLocal': avatarPath != null && avatarPath.isNotEmpty
                  ? _resolverAvatarLocal(sb, avatarPath)
                  : '',
              'idLocal': idLocal,
              'localVerificado': perfil != null
                  ? _parseBool(perfil['local_verificado'])
                  : false,
              'localEsPionero': perfil != null
                  ? _parseBool(perfil['es_pionero'])
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

      final locales = await localesPopFut;
      final poolLocales = await poolLocalesFut;

      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        _locales = locales;
        _poolLocalesCartelera = poolLocales;
        _cargando = false;
        _seedShuffle = DateTime.now().millisecondsSinceEpoch;
      });
      BootstrapCartelera.marcarLista();

      _consumirEnlaceEventoPendiente();

      // Top Ultra y luego modal de reseña sobre la cartelera.
      if (!_storiesYaMostrado) {
        _storiesYaMostrado = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_flujoPostCargaCartelera());
        });
      }
    } catch (e) {
      debugPrint('⚠️ cartelera _cargar: $e');
      if (mounted) setState(() => _cargando = false);
      BootstrapCartelera.marcarLista();
      if (!_storiesYaMostrado) {
        _storiesYaMostrado = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_flujoPostCargaCartelera());
        });
      }
    }
  }

  Future<void> _flujoPostCargaCartelera() async {
    debugPrint('[ResenaPostVisita] flujo: top ultra → modal');
    try {
      await _abrirTopUltraStories();
    } catch (e) {
      debugPrint('[ResenaPostVisita] top ultra: $e');
    }
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _intentarModalResenaPostVisita();
  }

  Future<void> _intentarModalResenaPostVisita() async {
    try {
      debugPrint('[ResenaPostVisita] buscando pendiente…');
      final pendiente = await ServicioResenaPostVisita.instancia
          .siguientePendiente();
      if (pendiente == null) {
        debugPrint('[ResenaPostVisita] sin pendiente');
        return;
      }
      final ctx = navigatorKey.currentContext;
      debugPrint(
        '[ResenaPostVisita] modal ${pendiente.nombreLocal} ctx=${ctx != null}',
      );
      if (ctx == null || !ctx.mounted) return;
      await mostrarModalResenaPostVisita(ctx, pendiente: pendiente);
    } catch (e, st) {
      debugPrint('[ResenaPostVisita] error: $e\n$st');
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
        'id, nombre_local, local_username, local_verificado, es_pionero, foto_perfil_url, url_foto_banner, '
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
            'id, nombre_local, local_username, local_verificado, es_pionero, foto_perfil_url, url_foto_banner, foto_local_1, foto_local_2, foto_local_3, rubro, ciudad, provincia, estado_cuenta',
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
      final tendencias = await sb.rpc(
        'cartelera_locales_on_fire',
        params: {
          'p_ciudades': _ciudadesActivas.isEmpty
              ? null
              : _ciudadesActivas.toList(),
          'p_provincia': _provinciaActiva,
          'p_limite': 5,
        },
      );
      if (tendencias is List && tendencias.isNotEmpty) {
        return tendencias
            .whereType<Map>()
            .take(5)
            .map((raw) {
              final t = Map<String, dynamic>.from(raw);
              return {
                'idLocal': t['id_local']?.toString() ?? '',
                'nombre': t['nombre_local']?.toString() ?? 'Local',
                'avatar': _resolverAvatarLocal(sb, t['foto_perfil_url']),
                'verificado': false,
                'esPionero': false,
                'rubro': 'tendencia',
                'ciudad': t['ciudad']?.toString(),
                'provincia': t['provincia']?.toString(),
                'score': (t['score'] as num?)?.toInt() ?? 0,
              };
            })
            .toList(growable: false);
      }

      const sel =
          'id, nombre_local, local_username, local_verificado, es_pionero, foto_perfil_url, '
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
          'esPionero': _parseBool(local['es_pionero']),
          'rubro': rubro,
          'ciudad': local['ciudad']?.toString(),
          'provincia': local['provincia']?.toString(),
        };
      }

      // Fallback si ranking no trae nada: primero IDs de cartelera, luego completar.
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

      // Shuffle al final, pero solo mostramos top 5 para no ensuciar cartelera.
      resultado.shuffle(math.Random(_seedShuffle));
      return resultado.take(5).toList(growable: false);
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
    return BusquedaNatural.coincide(_query, [
      e['titulo'],
      e['nombreLocal'],
      e['descripcion'],
      e['tipoEvento'],
      e['rubroLocal'],
      e['ciudadEvento'],
      e['diaSemana'],
      e['tienePromo'] == true ? 'promo promocion descuento' : null,
    ]);
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

  bool _eventoSinFechaDeclarada(Map<String, dynamic> e) {
    final fechaRaw = e['fechaInicio']?.toString();
    return fechaRaw == null || fechaRaw.isEmpty;
  }

  List<Map<String, dynamic>> _eventosFiltrados() {
    final base = _eventos
        .where((e) => _coincideQuery(e))
        .where(_coincideTipoEvento)
        .where(_coincideCiudad);

    if (_filtroTiempo == FiltroTiempo.todos) {
      return base.toList();
    }

    // Eventos vidriera sin fecha: no entran en hoy/semana/finde, pero se muestran al final.
    final conFecha = <Map<String, dynamic>>[];
    final sinFecha = <Map<String, dynamic>>[];
    for (final e in base) {
      if (_eventoSinFechaDeclarada(e)) {
        sinFecha.add(e);
      } else if (_coincideTiempo(e)) {
        conFecha.add(e);
      }
    }
    return [...conFecha, ...sinFecha];
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
      carteleraInteligente: _carteleraInteligente,
    );
    // Cartelera estricta: NUNCA quedar sin ciudad. Si el user vacía la selección
    // o cierra sin aplicar, mantenemos el estado anterior.
    if (res != null && res.ciudades.isNotEmpty && mounted) {
      setState(() {
        _provinciaActiva = res.provincia;
        _ciudadesActivas = res.ciudades;
        _carteleraInteligente = res.carteleraInteligente;
      });

      // Unifica: guarda el set local + sincroniza la ciudad principal al perfil.
      if (res.carteleraInteligente) {
        await ServicioUbicacionGlobal.aplicarInteligente(
          ciudades: res.ciudades,
          provincia: res.provincia,
          principal: res.ciudadPrincipal,
        );
      } else {
        await ServicioUbicacionGlobal.aplicarManual(
          provincia: res.provincia,
          ciudades: res.ciudades,
          principal: res.ciudadPrincipal,
        );
      }
      await _recargarPoolLocales();
    }
  }

  Future<void> _recargarPoolLocales() async {
    if (_ciudadesActivas.isEmpty) {
      if (mounted) setState(() => _poolLocalesCartelera = const []);
      return;
    }
    final pool = await ServicioCarteleraLocales.instancia.obtenerPorCiudades(
      _ciudadesActivas,
    );
    if (mounted) setState(() => _poolLocalesCartelera = pool);
  }

  Future<void> _abrirTopUltraStories() async {
    final ultras = _eventos
        .where(
          (e) =>
              (e['jerarquia']?.toString() ?? '') ==
              JerarquiasData.topUltra.slug,
        )
        // Solo top_ultra de la(s) ciudad(es) seleccionada(s) en la cartelera.
        .where(_coincideCiudad)
        .map(
          (e) => EventoTopUltra(
            idEvento: e['id']?.toString() ?? '',
            idLocal: e['idLocal']?.toString() ?? '',
            tituloEvento: e['titulo']?.toString() ?? 'Evento',
            urlFlyer: e['flyer']?.toString() ?? '',
            nombreLocal: e['nombreLocal']?.toString() ?? 'Local',
            avatarLocal: e['avatarLocal']?.toString(),
            localEsPionero: e['localEsPionero'] == true,
            fechaTexto: _fechaCortaTexto(e['fechaInicio']?.toString()),
          ),
        )
        .toList();
    if (ultras.isEmpty) {
      debugPrint('[ResenaPostVisita] sin top ultra');
      return;
    }
    final ctx = navigatorKey.currentContext ?? context;
    await mostrarTopUltraStoriesOverlay(
      ctx,
      eventos: ultras,
      onVerEvento: (id) => _irAEvento(id),
    );
  }

  Future<void> _abrirCercaTuyo() async {
    final res = await Navigator.of(context).push<ResultadoFiltroUbicacion>(
      CupertinoPageRoute(
        builder: (_) => PantallaMapa(
          provinciaInicial: _provinciaActiva,
          ciudadesIniciales: _ciudadesActivas,
          carteleraInteligenteInicial: _carteleraInteligente,
        ),
      ),
    );
    // Mismo filtro que el mapa: al volver sincronizamos chip / ciudades.
    if (res == null || !mounted) return;
    if (res.ciudades.isEmpty) return;
    setState(() {
      _provinciaActiva = res.provincia;
      _ciudadesActivas = Set<String>.from(res.ciudades);
      _carteleraInteligente = res.carteleraInteligente;
    });
    await _recargarPoolLocales();
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

  void _irALocalCartelera(LocalCarteleraCard local) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaLocalPerfil(
          avatarUrl: local.avatarUrl ?? '',
          nombreLocal: local.nombreLocal,
          idLocal: local.localId,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // El splash full-screen lo pinta [PantallaHome]; acá solo el contenido.
    if (_cargando) {
      return const ColoredBox(color: kVerdeSplashFernecito);
    }
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ValueListenableBuilder<Color>(
          valueListenable: TemaFernecito.instancia.colorActual,
          builder: (context, _, __) {
            return Stack(
              children: [
                FernecitoRefreshScrollView(
                  onRefresh: _onPullToRefresh,
                  slivers: _buildSlivers(),
                ),
                Positioned(
                  right: 16,
                  bottom: homeFabBottomOffset(context),
                  child: _PillMapaYQr(
                    onMapa: _abrirCercaTuyo,
                    onQr: _abrirScannerInvitacion,
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

    final conteosEventos = <String, int>{
      'top': topsTotales.length,
      JerarquiasData.recomendadoFernecito.slug: recos.length,
      JerarquiasData.normal.slug: normales.length,
      JerarquiasData.gratis.slug: gratis.length,
    };
    final localesPorSeccion =
        MezclaCarteleraLocales.necesitaRelleno(conteosEventos)
        ? MezclaCarteleraLocales.distribuir(
            pool: _poolLocalesCartelera,
            conteosEventos: conteosEventos,
            seed: _seedShuffle,
          )
        : const <String, List<LocalCarteleraCard>>{};

    final topsConLocales = MezclaCarteleraLocales.appendLocales(
      topsTotales,
      localesPorSeccion['top'],
    );
    final recosConLocales = MezclaCarteleraLocales.appendLocales(
      recos,
      localesPorSeccion[JerarquiasData.recomendadoFernecito.slug],
    );
    final normalesConLocales = MezclaCarteleraLocales.appendLocales(
      normales,
      localesPorSeccion[JerarquiasData.normal.slug],
    );
    final gratisConLocales = MezclaCarteleraLocales.appendLocales(
      gratis,
      localesPorSeccion[JerarquiasData.gratis.slug],
    );
    // El badge de stories solo aparece si hay top_ultra en la(s) ciudad(es)
    // seleccionada(s) — consistente con que las stories ahora filtran por ciudad.
    final tieneTopUltra = _eventos
        .where(_coincideCiudad)
        .any(
          (e) =>
              (e['jerarquia']?.toString() ?? '') ==
              JerarquiasData.topUltra.slug,
        );

    return <Widget>[
      _buildHeader(),
      _buildBarraSpotlight(),
      const SliverPadding(padding: EdgeInsets.only(top: 6)),
      // Badge Top Ultra solo si hay stories; el mapa vive en el pill flotante.
      if (tieneTopUltra)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TopUltraBadgeCartelera(onTap: _abrirTopUltraStories),
            ),
          ),
        ),
      // TOP (incluye top_ultra; locales solo si <10 eventos en la sección)
      if (topsConLocales.isNotEmpty)
        _buildSeccionCarruseles(
          titulo: JerarquiasData.top.labelSeccion,
          icono: JerarquiasData.top.icono,
          eventos: topsConLocales,
          porFila: CapacidadCartelera.topPorFila,
          variante: _Variante.grande,
          sentidoBase: false, // TOP: hacia la derecha
          seccionDeEvento: _seccionImpresionCartelera,
        ),
      // TOP 5 LOCALES TENDENCIA (ranking semanal, filtrado por ubicación)
      if (localesPop.isNotEmpty) _buildSeccionLocalesPopulares(localesPop),
      // RECOMENDADO FERNECITO
      if (recosConLocales.isNotEmpty)
        _buildSeccionCarruseles(
          titulo: JerarquiasData.recomendadoFernecito.labelSeccion,
          icono: CupertinoIcons.hand_thumbsup_fill,
          eventos: recosConLocales,
          porFila: CapacidadCartelera.recomendadoPorFila,
          variante: _Variante.mediano,
          sentidoBase:
              true, // RECOMENDADOS: hacia la izquierda (contrario a TOP)
          seccionFija: SeccionesImpresion.recomendadoFernecito,
        ),
      // NORMAL (Destacados en tu ciudad)
      if (normalesConLocales.isNotEmpty)
        _buildSeccionCarruseles(
          titulo: JerarquiasData.normal.labelSeccion,
          icono: JerarquiasData.normal.icono,
          eventos: normalesConLocales,
          porFila: CapacidadCartelera.normalPorFila,
          variante: _Variante.mediano,
          sentidoBase: false, // base derecha, alterna por fila
          paginar: true, // muestra 2 filas + "Ver más"
          seccionFija: SeccionesImpresion.normal,
        ),
      // GRID GRATIS
      if (gratisConLocales.isNotEmpty)
        _buildSeccionGratisGrid(eventos: gratisConLocales),
      // Empty state si nada
      if (topsConLocales.isEmpty &&
          recosConLocales.isEmpty &&
          normalesConLocales.isEmpty &&
          gratisConLocales.isEmpty &&
          localesPop.isEmpty)
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
    final topSafe = MediaQuery.paddingOf(context).top;
    final ciudadTexto = _carteleraInteligente
        ? 'cerca tuyo'
        : (_ciudadesActivas.isEmpty
              ? _provinciaActiva
              : (_ciudadesActivas.length == 1
                    ? _ciudadesActivas.first
                    : '${_ciudadesActivas.length} ciudades'));
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topSafe + 4, 16, 8),
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
                    color: ColoresApp.fondoSuperficie,
                    borderRadius: BorderRadius.circular(20),
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
                      if (!_carteleraInteligente &&
                          _ciudadesActivas.isNotEmpty) ...[
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
          onBusquedaIa: (texto) {
            mostrarBusquedaIaSheet(
              context,
              ciudades: _ciudadesActivas,
              preguntaInicial: texto.isEmpty ? null : texto,
            );
          },
        ),
      ),
    );
  }

  // ---- Sección carruseles por jerarquía (top / recomendado / normal) ----
  // `paginar: true` muestra solo `normalFilasIniciales` filas + botón "Ver más"
  // (lo que usa Normal). En false muestra todas las filas (top / recomendado).
  Widget _buildSeccionCarruseles({
    required String titulo,
    required IconData icono,
    required List<Map<String, dynamic>> eventos,
    required int porFila,
    required _Variante variante,
    bool sentidoBase = false,
    bool paginar = false,
    String Function(Map<String, dynamic> e)? seccionDeEvento,
    String? seccionFija,
  }) {
    final iniciales = CapacidadCartelera.normalFilasIniciales * porFila;
    final mostrar = (paginar && !_verMasNormal)
        ? eventos.take(iniciales).toList()
        : eventos;
    final hayMas = paginar && eventos.length > iniciales;

    // Split en grupos de `porFila`.
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
            _TituloSeccion(icono: icono, titulo: titulo),
            for (var i = 0; i < filas.length; i++)
              _buildFilaCarrusel(
                filas[i],
                variante,
                mostrarLineaSeparadora: i < filas.length - 1,
                sentidoBase: sentidoBase,
                indiceFila: i,
                seccionDeEvento: seccionDeEvento,
                seccionFija: seccionFija,
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

  Widget _buildFilaCarrusel(
    List<Map<String, dynamic>> fila,
    _Variante variante, {
    bool mostrarLineaSeparadora = false,
    bool sentidoBase =
        false, // false = hacia la derecha, true = hacia la izquierda
    int indiceFila = 0,
    String Function(Map<String, dynamic> e)? seccionDeEvento,
    String? seccionFija,
  }) {
    // Sentido por fila: la primera usa el sentido base de la sección y cada
    // fila siguiente gira al revés que la de arriba (intercalado estético).
    final bool invertir = sentidoBase ^ indiceFila.isOdd;
    final esGrande = variante == _Variante.grande;
    final altura = esGrande ? 380.0 : 285.0;
    final ancho = esGrande ? 240.0 : 175.0;

    Widget cardAt(BuildContext ctx, int i) {
      final raw = fila[i];
      if (LocalCarteleraCard.esItemLocal(raw)) {
        final local = LocalCarteleraCard.desdeItemCartelera(raw);
        if (local == null) return const SizedBox.shrink();
        Widget card;
        if (esGrande) {
          card = CardLocalCartelera(
            local: local,
            ancho: ancho,
            variante: VarianteCardLocalCartelera.grande,
            onTap: () => _irALocalCartelera(local),
          );
        } else {
          card = CardLocalCartelera(
            local: local,
            ancho: ancho,
            variante: VarianteCardLocalCartelera.mediano,
            onTap: () => _irALocalCartelera(local),
          );
        }
        // Misma mecánica que eventos: ~10% visible → 1 vista (card_local).
        if (local.localId.isNotEmpty) {
          card = DetectorImpresionCartelera(
            idLocal: local.localId,
            idEvento: ServicioImpresiones.uuidSinEvento,
            seccion: SeccionesImpresion.cardLocal,
            child: card,
          );
        }
        return RepaintBoundary(child: card);
      }

      final ev = _aEventoCartelera(raw);
      final idLocal = raw['idLocal']?.toString() ?? '';
      final seccion =
          seccionFija ??
          seccionDeEvento?.call(raw) ??
          _seccionImpresionCartelera(raw);
      Widget card;
      if (esGrande) {
        card = CardEventoGrande(
          evento: ev,
          ancho: ancho,
          onTap: () => _irAEvento(ev.idEvento),
        );
      } else {
        card = CardEventoMediano(
          evento: ev,
          ancho: ancho,
          onTap: () => _irAEvento(ev.idEvento),
        );
      }
      if (idLocal.isNotEmpty && ev.idEvento.isNotEmpty) {
        card = DetectorImpresionCartelera(
          idLocal: idLocal,
          idEvento: ev.idEvento,
          seccion: seccion,
          child: card,
        );
      }
      return RepaintBoundary(child: card);
    }

    // Todo carrusel con más de 1 evento se auto-scrollea suavemente (top,
    // recomendados y normal). Solo el grid de gratis queda sin auto-scroll.
    final Widget carrusel = (fila.length > 1)
        ? CarruselAutoScroll(
            itemCount: fila.length,
            itemBuilder: cardAt,
            height: altura,
            invertir: invertir,
          )
        : SizedBox(
            height: altura,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              physics: const BouncingScrollPhysics(),
              itemCount: fila.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: cardAt,
            ),
          );

    return Column(
      children: [
        carrusel,
        if (mostrarLineaSeparadora)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 0.5,
            color: ColoresApp.textoSecundario.withOpacity(0.12),
          ),
      ],
    );
  }

  /// El RPC ya filtró por ciudades activas (+ alias). No re-filtrar por string
  /// exacto: "Córdoba" vs "Córdoba capital" vaciaba la sección.
  List<Map<String, dynamic>> _localesPopularesFiltrados() {
    if (_locales.isEmpty) return const [];
    return _locales.take(5).toList(growable: false);
  }

  // ---- Sección TOP 5 LOCALES TENDENCIA ----
  Widget _buildSeccionLocalesPopulares(List<Map<String, dynamic>> filtrados) {
    final top5 = filtrados.take(5).toList(growable: false);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TituloOnFireCartelera(),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 3, 20, 6),
                physics: const BouncingScrollPhysics(),
                itemCount: top5.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) {
                  final local = top5[index];
                  return _LocalOnFireCarteleraItem(
                    posicion: index + 1,
                    nombre: local['nombre']?.toString() ?? 'Local',
                    fotoUrl: local['avatar']?.toString(),
                    onTap: () => _irALocal(local),
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
              final raw = eventos[i];
              if (LocalCarteleraCard.esItemLocal(raw)) {
                final local = LocalCarteleraCard.desdeItemCartelera(raw);
                if (local == null) return const SizedBox.shrink();
                Widget card = CardLocalCartelera(
                  local: local,
                  variante: VarianteCardLocalCartelera.grid,
                  onTap: () => _irALocalCartelera(local),
                );
                if (local.localId.isNotEmpty) {
                  card = DetectorImpresionCartelera(
                    idLocal: local.localId,
                    idEvento: ServicioImpresiones.uuidSinEvento,
                    seccion: SeccionesImpresion.cardLocal,
                    child: card,
                  );
                }
                return RepaintBoundary(child: card);
              }
              final ev = _aEventoCartelera(raw);
              final idLocal = raw['idLocal']?.toString() ?? '';
              Widget card = CardEventoGrid(
                evento: ev,
                onTap: () => _irAEvento(ev.idEvento),
              );
              if (idLocal.isNotEmpty && ev.idEvento.isNotEmpty) {
                card = DetectorImpresionCartelera(
                  idLocal: idLocal,
                  idEvento: ev.idEvento,
                  seccion: SeccionesImpresion.gratis,
                  child: card,
                );
              }
              return RepaintBoundary(child: card);
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
      localEsPionero: e['localEsPionero'] == true,
    );
  }

  String _seccionImpresionCartelera(Map<String, dynamic> e) {
    final j = (e['jerarquia']?.toString() ?? '').toLowerCase();
    switch (j) {
      case 'top_ultra':
        return SeccionesImpresion.topUltra;
      case 'top':
        return SeccionesImpresion.top;
      case 'recomendado_fernecito':
        return SeccionesImpresion.recomendadoFernecito;
      case 'normal':
        return SeccionesImpresion.normal;
      case 'gratis':
        return SeccionesImpresion.gratis;
      default:
        return j.isNotEmpty ? j : SeccionesImpresion.normal;
    }
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

class _TituloOnFireCartelera extends StatefulWidget {
  const _TituloOnFireCartelera();

  @override
  State<_TituloOnFireCartelera> createState() => _TituloOnFireCarteleraState();
}

class _TituloOnFireCarteleraState extends State<_TituloOnFireCartelera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _onFireController;

  @override
  void initState() {
    super.initState();
    _onFireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loopOnFire());
  }

  Future<void> _loopOnFire() async {
    while (mounted) {
      await _onFireController.forward(from: 0);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  void dispose() {
    _onFireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _onFireController,
            child: const Text('🔥', style: TextStyle(fontSize: 19)),
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_onFireController.value);
              final wave = math.sin(t * math.pi * 4);
              final pop = 1 + (math.sin(t * math.pi) * 0.18);
              return Transform.translate(
                offset: Offset(wave * 1.6, 0),
                child: Transform.rotate(
                  angle: wave * 0.07,
                  child: Transform.scale(scale: pop, child: child),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _onFireController,
            builder: (context, _) {
              final breathe = math.sin(_onFireController.value * math.pi);
              final color = Color.lerp(
                ColoresApp.textoPrincipal,
                const Color(0xFFFF6B5F),
                breathe * 0.72,
              );
              return Text(
                'Tendencias para el finde',
                style: GoogleFonts.baloo2(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: ColoresApp.principalMarca.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Top 5',
              style: GoogleFonts.baloo2(
                color: ColoresApp.principalMarca,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalOnFireCarteleraItem extends StatelessWidget {
  const _LocalOnFireCarteleraItem({
    required this.posicion,
    required this.nombre,
    required this.fotoUrl,
    required this.onTap,
  });

  static const _oro = Color(0xFFFFD54A);
  static const _platino = Color(0xFFD8DEE9);
  static const _cobre = Color(0xFFD08A45);

  final int posicion;
  final String nombre;
  final String? fotoUrl;
  final VoidCallback onTap;

  Color get _acentoMedalla {
    switch (posicion) {
      case 1:
        return _oro;
      case 2:
        return _platino;
      case 3:
        return _cobre;
      default:
        return ColoresApp.principalMarca;
    }
  }

  @override
  Widget build(BuildContext context) {
    final acento = _acentoMedalla;
    final esPodio = posicion <= 3;
    final foto = fotoUrl?.trim();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 61,
        child: Column(
          children: [
            SizedBox(
              width: 58,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 11,
                    top: 1,
                    child: Container(
                      width: 47,
                      height: 47,
                      padding: EdgeInsets.all(esPodio ? 2.25 : 1.8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: acento,
                        boxShadow: [
                          BoxShadow(
                            color: acento.withValues(
                              alpha: esPodio ? 0.34 : 0.2,
                            ),
                            blurRadius: esPodio ? 8 : 6,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: ColoresApp.fondoSuperficie,
                          child: foto != null && foto.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: foto,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => _iconoLocal(),
                                  placeholder: (_, _) => _iconoLocal(),
                                )
                              : _iconoLocal(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(
                      '$posicion',
                      style: GoogleFonts.baloo2(
                        fontSize: 25,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        color: esPodio ? acento : Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 7),
                          Shadow(color: Colors.black, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              nombre,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                fontSize: 9.6,
                height: 0.98,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconoLocal() => Icon(
    CupertinoIcons.building_2_fill,
    size: 24,
    color: ColoresApp.textoSecundario,
  );
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
          final esPionero = loc['esPionero'] == true;
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
                    AvatarLocal(
                      imageUrl: avatar,
                      size: _avatarSize,
                      esPionero: esPionero,
                      placeholderIcon: CupertinoIcons.building_2_fill,
                      memCacheWidth:
                          (_avatarSize *
                                  MediaQuery.of(
                                    context,
                                  ).devicePixelRatio.clamp(1.0, 2.0))
                              .round(),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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

/// Pill vertical único: mapa arriba, QR abajo. Los iconos son hit-targets;
/// no hay botones anidados dentro de la cápsula.
class _PillMapaYQr extends StatelessWidget {
  const _PillMapaYQr({required this.onMapa, required this.onQr});

  final VoidCallback onMapa;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: TemaFernecito.instancia.colorActual,
      builder: (context, colorTema, _) {
        return SizedBox(
          width: kHomeFabPillWidth,
          height: kHomeFabPillHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4EA),
              borderRadius: BorderRadius.circular(kHomeFabPillWidth / 2),
              border: Border.all(color: Colors.white, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onMapa,
                    behavior: HitTestBehavior.opaque,
                    child: const Center(
                      child: IconoMapaCarteleraAnimado(size: 24),
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 1,
                  decoration: BoxDecoration(
                    color: colorTema.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onQr,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Icon(
                        CupertinoIcons.qrcode_viewfinder,
                        color: colorTema,
                        size: 26,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 2.5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
