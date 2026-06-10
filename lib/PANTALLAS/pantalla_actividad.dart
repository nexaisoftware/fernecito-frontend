/// Pantalla Actividad - Tokens reales del usuario: asistencias reservadas/aceptadas.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../widgets/boton_compartir_evento.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_pools.dart';

/// Estados de `tokens_promociones` que tratamos como “tenés la promo” en listados.
const _kEstadosTokenPromoUsuario = <String>[
  'activo',
  'canjeado',
  'pendiente',
  'reservada',
  'reservado',
];

/// Snapshot de token de promo por `id_promocion` (precarga desde Mi Actividad).
class _SnapshotTokenPromo {
  final String codigo;
  final String estadoToken;

  const _SnapshotTokenPromo({
    required this.codigo,
    required this.estadoToken,
  });
}

String _formatearFechaPromoActividad(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final dia = dias[dt.weekday - 1];
    final mes = meses[dt.month - 1];
    final hora =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$dia ${dt.day} $mes, $hora';
  } catch (_) {
    return iso;
  }
}

/// Lista aceptada o pase ya canjeado → el usuario puede reservar / ver QR de promos.
bool listaPermitePromosUsuario(String? estadoToken) {
  final e = estadoToken?.trim().toLowerCase() ?? '';
  return e == 'aceptada' || e == 'canjeada';
}

bool _promoVigente(Map<String, dynamic> promo) {
  final finRaw = promo['fecha_fin']?.toString();
  if (finRaw == null || finRaw.isEmpty) return true;
  try {
    final fin = DateTime.parse(finRaw).toUtc();
    return DateTime.now().toUtc().millisecondsSinceEpoch <= fin.millisecondsSinceEpoch;
  } catch (_) {
    return true;
  }
}

class PantallaActividad extends StatefulWidget {
  /// Incrementado desde [PantallaHome] al seleccionar el tab Actividad (IndexedStack).
  final int reloadTick;

  const PantallaActividad({super.key, this.reloadTick = 0});

  @override
  State<PantallaActividad> createState() => _PantallaActividadState();
}

class _PantallaActividadState extends State<PantallaActividad> {
  List<Map<String, dynamic>> _tokens = [];
  bool _cargando = true;

  /// Tokens de promo ya obtenidos por el usuario (clave `id_promocion`), para UX sin flashes.
  Map<String, _SnapshotTokenPromo> _tokensPromoPorId = {};

  @override
  void initState() {
    super.initState();
    _cargarActividad();
  }

  @override
  void didUpdateWidget(PantallaActividad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick && widget.reloadTick > 0) {
      _cargarActividad();
    }
  }

  Future<void> _cargarActividad() async {
    try {
      final sb = ServicioSupabase().cliente;
      final userId = sb.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[Actividad] _cargarActividad: sin sesión (currentUser null)');
        if (mounted) setState(() => _cargando = false);
        return;
      }

      // Paso 1: cargar tokens de asistencia del usuario con evento
      final rows = await sb
          .from('tokens_asistencia')
          .select(
            'id_token, codigo_puerta, estado_token, fecha_expiracion, '
            'eventos!tokens_asistencia_id_evento_fkey('
              'id_evento, titulo_evento, descripcion_evento, url_flyer, '
              'fecha_inicio, fecha_fin, id_local'
            ')',
          )
          .eq('id_usuario', userId)
          .inFilter('estado_token', ['pendiente', 'aceptada', 'canjeada'])
          .order('fecha_creacion', ascending: false);

      if (kDebugMode) {
        debugPrint(
          '[Actividad] userId=$userId tokens devueltos por Supabase: ${(rows as List).length}',
        );
      }

      // Paso 2: recolectar ids de locales únicos para cargar sus perfiles
      final idsLocales = <String>{};
      for (final r in (rows as List)) {
        final ev = r['eventos'];
        if (ev is Map) {
          final idL = ev['id_local']?.toString().trim() ?? '';
          if (idL.isNotEmpty) idsLocales.add(idL);
        }
      }

      // Paso 3: cargar perfiles de locales (después de que RLS tenga la política pública)
      final perfilesPorId = <String, Map<String, dynamic>>{};
      if (idsLocales.isNotEmpty) {
        try {
          final perfilesRows = await sb
              .from('perfiles_locales')
              .select('id, nombre_local, foto_perfil_url, url_maps, direccion, ciudad, provincia')
              .inFilter('id', idsLocales.toList());
          for (final p in (perfilesRows as List)) {
            final id = p['id']?.toString().toLowerCase() ?? '';
            if (id.isNotEmpty) perfilesPorId[id] = Map<String, dynamic>.from(p as Map);
          }
        } catch (_) {
          // RLS puede bloquear si aún no se aplicó la migración SQL_RLS_LECTURA_PUBLICA.sql
        }
      }

      if (!mounted) return;

      final tokens = (rows).map<Map<String, dynamic>>((r) {
        final ev = r['eventos'] as Map<String, dynamic>? ?? {};
        final idLocal = ev['id_local']?.toString().trim() ?? '';
        final perfil = perfilesPorId[idLocal.toLowerCase()];
        return {
          'id_token': r['id_token'],
          'codigo_puerta': r['codigo_puerta'] ?? '',
          'estado_token': r['estado_token'] ?? 'pendiente',
          'titulo': ev['titulo_evento'] ?? 'Evento',
          'descripcion': ev['descripcion_evento'] ?? '',
          'flyer': ev['url_flyer'] ?? '',
          'fechaInicio': ev['fecha_inicio'],
          'fechaFin': ev['fecha_fin'],
          'nombreLocal': perfil?['nombre_local']?.toString().trim().isNotEmpty == true
              ? perfil!['nombre_local'].toString()
              : 'Local',
          'avatarLocal': _resolverAvatarLocal(perfil?['foto_perfil_url']),
          'idLocal': idLocal.isNotEmpty ? idLocal : null,
          'urlMaps': perfil?['url_maps']?.toString().trim() ?? '',
          'direccion': perfil?['direccion']?.toString().trim() ?? '',
          'ciudad': perfil?['ciudad']?.toString().trim() ?? '',
          'provincia': perfil?['provincia']?.toString().trim() ?? '',
          'id_evento': ev['id_evento'],
        };
      }).toList();

      final promoPorId = <String, _SnapshotTokenPromo>{};
      try {
        final promoRows = await sb
            .from('tokens_promociones')
            .select('id_promocion, token_codigo, estado_token')
            .eq('id_usuario', userId)
            .inFilter('estado_token', _kEstadosTokenPromoUsuario);
        for (final t in (promoRows as List)) {
          final idP = t['id_promocion']?.toString() ?? '';
          final codigo = t['token_codigo']?.toString() ?? '';
          final est =
              t['estado_token']?.toString().toLowerCase() ?? 'activo';
          if (idP.isNotEmpty && codigo.isNotEmpty) {
            promoPorId[idP] =
                _SnapshotTokenPromo(codigo: codigo, estadoToken: est);
          }
        }
      } catch (e, st) {
        debugPrint('[Actividad] tokens_promociones: $e\n$st');
      }

      setState(() {
        _tokens = tokens;
        _tokensPromoPorId = promoPorId;
        _cargando = false;
      });
    } catch (e, st) {
      debugPrint('[Actividad] _cargarActividad error: $e');
      debugPrint('$st');
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _resolverAvatarLocal(dynamic avatarRaw) {
    final avatar = avatarRaw?.toString() ?? '';
    if (avatar.isEmpty || avatar.startsWith('http')) return avatar;
    return ServicioSupabase().cliente.storage
        .from('perfiles-locales')
        .getPublicUrl(avatar);
  }

  String _estadoTextoReal(String estado) {
    switch (estado) {
      case 'aceptada':  return 'Aceptada';
      case 'pendiente': return 'En espera';
      case 'canjeada':  return 'Ya ingresaste';
      case 'rechazada': return 'Rechazada';
      default:          return estado;
    }
  }

  Color _estadoColorReal(String estado) {
    switch (estado) {
      case 'aceptada':  return ColoresApp.principalMarca;
      case 'pendiente': return ColoresApp.promoMarca;
      case 'canjeada':  return ColoresApp.textoSecundario;
      case 'rechazada': return ColoresApp.peligroMarca;
      default:          return ColoresApp.textoSecundario;
    }
  }

  String _formatearFecha(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const dias   = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      const meses  = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${dias[dt.weekday - 1]} ${dt.day} ${meses[dt.month - 1]}, '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  Uri? _parseUrlMaps(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    var u = Uri.tryParse(t);
    if (u != null && u.hasScheme) return u;
    if (!t.startsWith('http')) {
      u = Uri.tryParse('https://$t');
    }
    return u;
  }

  String _ubicacionTextoToken(Map<String, dynamic> token) {
    final ciudad = token['ciudad']?.toString().trim() ?? '';
    final provincia = token['provincia']?.toString().trim() ?? '';
    if (ciudad.isNotEmpty && provincia.isNotEmpty) return '$ciudad, $provincia';
    if (ciudad.isNotEmpty) return ciudad;
    if (provincia.isNotEmpty) return provincia;
    return '';
  }

  /// 1) `url_maps` del local (link de Google Maps). 2) Búsqueda por dirección + ciudad/provincia.
  /// Solo si no hay datos de ubicación, usa el nombre del local como último recurso.
  Future<void> _abrirMaps(BuildContext context, Map<String, dynamic> token) async {
    final urlMaps = token['urlMaps']?.toString().trim() ?? '';
    if (urlMaps.isNotEmpty) {
      final u = _parseUrlMaps(urlMaps);
      if (u != null && await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final direccion = token['direccion']?.toString().trim() ?? '';
    final ubicacion = _ubicacionTextoToken(token);
    final partes = <String>[
      if (direccion.isNotEmpty) direccion,
      if (ubicacion.isNotEmpty) ubicacion,
    ];

    final nombreLocal = token['nombreLocal']?.toString().trim() ?? '';
    final query = partes.isNotEmpty
        ? partes.join(', ')
        : (nombreLocal.isNotEmpty && nombreLocal != 'Local' ? nombreLocal : '');

    if (query.isEmpty) {
      final uri = Uri.parse('https://www.google.com/maps');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _mostrarQR(BuildContext context, Map<String, dynamic> token) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _BottomSheetContrasenaFernecito(
        codigo: token['codigo_puerta'] as String? ?? '',
        tituloEvento: token['titulo'] as String? ?? 'Evento',
      ),
    );
  }

  void _mostrarPromos(BuildContext context, Map<String, dynamic> token) {
    final idEvento = token['id_evento']?.toString().trim() ?? '';
    final puedeObtenerPromos = listaPermitePromosUsuario(
      token['estado_token']?.toString(),
    );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _BottomSheetPromos(
        token: token,
        idEvento: idEvento,
        puedeObtenerPromos: puedeObtenerPromos,
        promoTokensPrecarga: Map<String, _SnapshotTokenPromo>.from(_tokensPromoPorId),
        onReloadActividadDesdePromos: _cargarActividad,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: Stack(
        children: [
          // Fondo degradado sutil
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ColoresApp.principalMarca.withOpacity(0.18),
                      ColoresApp.principalMarca.withOpacity(0.06),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _cargarActividad),
              SliverToBoxAdapter(child: SizedBox(height: padding.top)),
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mi Actividad',
                              style: GoogleFonts.baloo2(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: ColoresApp.textoPrincipal,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              _tokens.isEmpty
                                  ? 'Todavía no reservaste nada'
                                  : '${_tokens.length} ${_tokens.length == 1 ? "reserva" : "reservas"} activas',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_cargando)
                        CupertinoButton(
                          padding: const EdgeInsets.all(8),
                          onPressed: () {
                            setState(() => _cargando = true);
                            _cargarActividad();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ColoresApp.fondoSuperficie.withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ColoresApp.principalMarca.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.refresh,
                              size: 18,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              if (_cargando)
                const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator(radius: 14)),
                )
              else if (_tokens.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: ColoresApp.principalMarca.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.ticket,
                            size: 38,
                            color: ColoresApp.principalMarca,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sin reservas aún',
                          style: GoogleFonts.baloo2(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Explorá la cartelera y reservá tu lugar en los mejores eventos',
                            style: GoogleFonts.baloo2(
                              fontSize: 14,
                              color: ColoresApp.textoSecundario,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final t = _tokens[index];
                        final estado = t['estado_token'] as String? ?? 'pendiente';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _CardActividad(
                            token: t,
                            flyerUrl: t['flyer'] as String? ?? '',
                            avatarLocal: t['avatarLocal'] as String? ?? '',
                            estadoTexto: _estadoTextoReal(estado),
                            estadoColor: _estadoColorReal(estado),
                            fechaHora: _formatearFecha(t['fechaInicio'] as String?),
                            codigoPuerta: t['codigo_puerta'] as String? ?? '',
                            onAbrirQR: estado == 'aceptada'
                                ? () => _mostrarQR(context, t)
                                : null,
                            onComoLlegar: () => _abrirMaps(context, t),
                            onVerPromos: () => _mostrarPromos(context, t),
                            onVerPool: () {
                              final idEv = t['id_evento']?.toString() ?? '';
                              if (idEv.isEmpty) return;
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => PantallaPools(
                                    idEvento: idEv,
                                    nombreEvento:
                                        t['titulo'] as String? ?? 'Evento',
                                    flyerUrl: t['flyer'] as String?,
                                    nombreLocal:
                                        t['nombreLocal'] as String? ?? 'Local',
                                    avatarLocal:
                                        t['avatarLocal'] as String? ?? '',
                                  ),
                                ),
                              );
                            },
                            onVerPerfilLocal: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => PantallaLocalPerfil(
                                    avatarUrl: t['avatarLocal'] as String? ?? '',
                                    nombreLocal: t['nombreLocal'] as String? ?? 'Local',
                                    idLocal: t['idLocal'] as String?,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: _tokens.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: padding.bottom + 80)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de Actividad
// ─────────────────────────────────────────────────────────────────────────────

class _CardActividad extends StatelessWidget {
  final Map<String, dynamic> token;
  final String flyerUrl;
  final String avatarLocal;
  final String estadoTexto;
  final Color estadoColor;
  final String fechaHora;
  final String codigoPuerta;
  final VoidCallback? onAbrirQR;
  final VoidCallback onComoLlegar;
  final VoidCallback onVerPromos;
  final VoidCallback onVerPool;
  final VoidCallback onVerPerfilLocal;

  const _CardActividad({
    required this.token,
    required this.flyerUrl,
    required this.avatarLocal,
    required this.estadoTexto,
    required this.estadoColor,
    required this.fechaHora,
    required this.codigoPuerta,
    required this.onAbrirQR,
    required this.onComoLlegar,
    required this.onVerPromos,
    required this.onVerPool,
    required this.onVerPerfilLocal,
  });

  @override
  Widget build(BuildContext context) {
    final nombreLocal = token['nombreLocal'] as String? ?? 'Local';
    final dpr         = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 2.0);
    const flyerW      = 90.0;
    const flyerH      = flyerW * (16 / 9);
    final flyerCacheW = (flyerW * dpr).round();
    final avatarCacheW = (24 * dpr).round();

    Widget flyerWidget = flyerUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: flyerUrl,
            fit: BoxFit.cover,
            memCacheWidth: flyerCacheW,
            width: flyerW,
            height: flyerH,
            placeholder: (_, __) => Container(
              color: ColoresApp.fondoSuperficie,
              child: const Center(child: CupertinoActivityIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              color: ColoresApp.fondoSuperficie,
              child: const Icon(
                CupertinoIcons.photo,
                color: ColoresApp.textoSecundario,
                size: 28,
              ),
            ),
          )
        : Container(
            width: flyerW,
            height: flyerH,
            color: ColoresApp.fondoSuperficie,
            child: const Icon(
              CupertinoIcons.photo,
              color: ColoresApp.textoSecundario,
              size: 28,
            ),
          );

    Widget avatarWidget = avatarLocal.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: avatarLocal,
            fit: BoxFit.cover,
            memCacheWidth: avatarCacheW,
            width: 24,
            height: 24,
            errorWidget: (_, __, ___) => const Icon(
              CupertinoIcons.building_2_fill,
              size: 14,
              color: ColoresApp.textoSecundario,
            ),
          )
        : const Icon(
            CupertinoIcons.building_2_fill,
            size: 14,
            color: ColoresApp.textoSecundario,
          );

    return Container(
      decoration: SuperficiesApp.card(
        radius: 22,
        temaTint: 0.22,
        sombraAlpha: 0.2,
        sombraBlur: 14,
        sombraOffsetY: 5,
      ).copyWith(
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Parte superior: flyer + info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniatura flyer (toca para ver QR si está aceptada)
                GestureDetector(
                  onTap: onAbrirQR,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: onAbrirQR != null
                              ? [
                                  BoxShadow(
                                    color: ColoresApp.principalMarca.withOpacity(0.5),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: flyerWidget,
                        ),
                      ),
                      if (onAbrirQR != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              color: Colors.black.withOpacity(0.35),
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.qrcode,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge estado
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: estadoColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: estadoColor.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          estadoTexto,
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: estadoColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        token['titulo'] as String? ?? 'Evento',
                        style: GoogleFonts.baloo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.textoPrincipal,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Local (toca para ver perfil)
                      GestureDetector(
                        onTap: onVerPerfilLocal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: avatarWidget,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                nombreLocal,
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ColoresApp.textoSecundario,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (fechaHora.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.calendar,
                              size: 13,
                              color: ColoresApp.principalMarca,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                fechaHora,
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ColoresApp.textoSecundario,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: ColoresApp.principalMarca.withOpacity(0.12),
          ),

          // ── Botones de acción ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                // Cómo llegar
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onComoLlegar,
                    child: Container(
                      decoration: BoxDecoration(
                        color: ColoresApp.fondoSuperficie.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: ColoresApp.principalMarca.withOpacity(0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.location_fill,
                            size: 15,
                            color: ColoresApp.principalMarca,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Cómo llegar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.textoPrincipal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ver promos
                Expanded(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onVerPromos,
                    child: Container(
                      decoration: BoxDecoration(
                        color: ColoresApp.promoMarca.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: ColoresApp.promoMarca.withOpacity(0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.tag_fill,
                            size: 15,
                            color: ColoresApp.promoMarca,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Ver promos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.promoMarca,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onAbrirQR != null) ...[
                  const SizedBox(width: 8),
                  // Mi QR
                  Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onAbrirQR,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColoresApp.principalMarca,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: ColoresApp.principalMarca.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.qrcode,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Mi QR',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Compartir (preview OG + deep link) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: BotonCompartirEvento(
              idEvento: token['id_evento']?.toString() ?? '',
              titulo: token['titulo'] as String? ?? 'Evento',
              nombreLocal: token['nombreLocal'] as String?,
              fechaIso: token['fechaInicio'] as String?,
              ciudad: token['ciudad'] as String?,
            ),
          ),

          // ── Ver el pool ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onVerPool,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: ColoresApp.principalMarca.withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.person_2_fill,
                      size: 15,
                      color: ColoresApp.principalMarca,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ver quiénes van (Pool)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet: QR de ingreso real con codigo_puerta
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSheetContrasenaFernecito extends StatelessWidget {
  final String codigo;
  final String tituloEvento;

  const _BottomSheetContrasenaFernecito({
    required this.codigo,
    this.tituloEvento = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: SuperficiesApp.bottomSheet(topRadius: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: ColoresApp.textoSecundario.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Tu código de ingreso',
              style: GoogleFonts.baloo2(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            if (tituloEvento.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tituloEvento,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  color: ColoresApp.textoSecundario,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Mostrá el QR o dictá el código en la entrada',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: ColoresApp.textoSecundario,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ColoresApp.principalMarca.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: codigo.isNotEmpty ? codigo : 'SIN_CODIGO',
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: ColoresApp.fondoPrincipal,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ColoresApp.principalMarca.withOpacity(0.5),
                ),
              ),
              child: Text(
                codigo.isNotEmpty ? codigo : '--------',
                style: GoogleFonts.baloo2(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: ColoresApp.principalMarca,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Válido una sola vez',
              style: GoogleFonts.baloo2(
                fontSize: 11,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel QR promo (misma línea visual que código de ingreso)
// ─────────────────────────────────────────────────────────────────────────────

class _PanelQrCodigoPromo extends StatelessWidget {
  final String codigo;
  final String tituloPromo;
  final bool canjeada;

  const _PanelQrCodigoPromo({
    required this.codigo,
    required this.tituloPromo,
    this.canjeada = false,
  });

  @override
  Widget build(BuildContext context) {
    final safe = codigo.isNotEmpty ? codigo : 'SIN_CODIGO';
    final letter =
        codigo.length > 10 ? 2.5 : (codigo.length > 8 ? 4.0 : 6.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          canjeada ? 'Promo canjeada' : 'Tu código de promo',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        if (tituloPromo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            tituloPromo,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              color: ColoresApp.textoSecundario,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          canjeada
              ? 'Este código ya fue utilizado en el local.'
              : 'Mostrá el QR o dictá el código al canjear la promo',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 12,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ColoresApp.promoMarca.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: safe,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: ColoresApp.fondoPrincipal,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ColoresApp.promoMarca.withOpacity(0.5),
            ),
          ),
          child: Text(
            codigo.isNotEmpty ? codigo : '------------',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: letter,
              color: ColoresApp.promoMarca,
            ),
          ),
        ),
      ],
    );
  }
}

String _descripcionPromoRow(Map<String, dynamic> p) {
  final a = p['descripcion_promocion']?.toString().trim();
  if (a != null && a.isNotEmpty) return a;
  final b = p['descripcion_promo']?.toString().trim();
  if (b != null && b.isNotEmpty) return b;
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet: promos del evento (igual que pantalla_ver_evento + obtener promo)
// ─────────────────────────────────────────────────────────────────────────────

enum _FaseBotonObtenerPromo { cargando, exitoCheck }

class _BottomSheetPromos extends StatefulWidget {
  final Map<String, dynamic> token;
  final String idEvento;
  final bool puedeObtenerPromos;
  /// Snapshot desde Mi Actividad al abrir el sheet (evita mostrar “Obtener” si ya está en BD).
  final Map<String, _SnapshotTokenPromo> promoTokensPrecarga;
  final Future<void> Function()? onReloadActividadDesdePromos;

  const _BottomSheetPromos({
    required this.token,
    required this.idEvento,
    required this.puedeObtenerPromos,
    required this.promoTokensPrecarga,
    required this.onReloadActividadDesdePromos,
  });

  @override
  State<_BottomSheetPromos> createState() => _BottomSheetPromosState();
}

class _BottomSheetPromosState extends State<_BottomSheetPromos> {
  bool _cargando = true;
  String? _errorMsg;
  List<Map<String, dynamic>> _promos = [];
  final Map<String, String> _misTokens = {};
  final Map<String, String> _estadoTokenPromo = {};
  final Set<String> _qrExpandido = {};
  final Map<String, _FaseBotonObtenerPromo> _faseObtenerPromo = {};
  final Map<String, Timer> _timersObtenerPromo = {};

  void _aplicarPrecarga(Map<String, _SnapshotTokenPromo> src) {
    for (final e in src.entries) {
      _misTokens[e.key] = e.value.codigo;
      _estadoTokenPromo[e.key] = e.value.estadoToken;
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarPromos(aplicarPrecargaInicial: true);
  }

  @override
  void dispose() {
    for (final t in _timersObtenerPromo.values) {
      t.cancel();
    }
    _timersObtenerPromo.clear();
    super.dispose();
  }

  Future<void> _cargarPromos({bool aplicarPrecargaInicial = false}) async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });
    try {
      final sb = ServicioSupabase().cliente;
      final userId = sb.auth.currentUser?.id;

      if (widget.idEvento.isEmpty) {
        if (!mounted) return;
        setState(() {
          _promos = [];
          _cargando = false;
          _errorMsg = 'No se pudo identificar el evento.';
        });
        return;
      }

      final res = await sb
          .from('promociones')
          .select(
            'id_promocion, id_evento, id_local, titulo_promocion, descripcion_promocion, '
            'fecha_inicio, fecha_fin, cupos_totales, cupos_usados, modo_uso, estado_promocion',
          )
          .eq('id_evento', widget.idEvento);
      final lista = List<Map<String, dynamic>>.from(res as List);
      final activas = lista
          .where((p) =>
              (p['estado_promocion']?.toString().toLowerCase() ?? 'activa') ==
              'activa')
          .toList();

      _misTokens.clear();
      _estadoTokenPromo.clear();
      if (aplicarPrecargaInicial) {
        _aplicarPrecarga(widget.promoTokensPrecarga);
      }

      if (userId != null && activas.isNotEmpty) {
        final tokenIds = activas
            .map((p) => p['id_promocion']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        if (tokenIds.isNotEmpty) {
          final misRows = await sb
              .from('tokens_promociones')
              .select('id_promocion, token_codigo, estado_token')
              .eq('id_usuario', userId)
              .inFilter('id_promocion', tokenIds)
              .inFilter('estado_token', _kEstadosTokenPromoUsuario);
          for (final t in (misRows as List)) {
            final idP = t['id_promocion']?.toString() ?? '';
            final codigo = t['token_codigo']?.toString() ?? '';
            final est =
                t['estado_token']?.toString().toLowerCase() ?? 'activo';
            if (idP.isNotEmpty && codigo.isNotEmpty) {
              _misTokens[idP] = codigo;
              _estadoTokenPromo[idP] = est;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _promos = activas;
        _cargando = false;
      });
    } catch (e, st) {
      debugPrint('[Actividad Promos] _cargarPromos: $e\n$st');
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _cargando = false;
      });
    }
  }

  String _mensajeEdgePromo(dynamic details) {
    if (details is Map) {
      final m = Map<String, dynamic>.from(details);
      return m['error']?.toString() ??
          m['message']?.toString() ??
          'No se pudo obtener la promo';
    }
    if (details is String && details.isNotEmpty) return details;
    return 'No se pudo obtener la promo';
  }

  bool _errorPromoDuplicada(Object? details) {
    final String s;
    if (details == null) {
      s = '';
    } else if (details is String) {
      s = details.toLowerCase();
    } else if (details is Map) {
      s = _mensajeEdgePromo(details).toLowerCase();
    } else {
      s = details.toString().toLowerCase();
    }
    return s.contains('ya ') ||
        s.contains('duplicate') ||
        s.contains('409') ||
        s.contains('activa') ||
        s.contains('reservad');
  }

  String _mensajePromoAmigable(Object? details, int? httpStatus) {
    final combined = [
      if (details != null) details.toString(),
      if (httpStatus != null) '$httpStatus',
    ].join(' ').toLowerCase();

    if (combined.contains('socket') ||
        combined.contains('network') ||
        combined.contains('connection refused') ||
        combined.contains('timeout') ||
        combined.contains('failed host lookup') ||
        combined.contains('handshake')) {
      return 'Sin conexión o el servidor tardó demasiado. Revisá tu internet e intentá de nuevo.';
    }

    final msg = _mensajeEdgePromo(details).toLowerCase();
    if (msg.contains('expir') ||
        msg.contains('venc') ||
        msg.contains('promo_expired') ||
        msg.contains('finaliz')) {
      return 'Esta promo ya no está disponible: la fecha de fin venció.';
    }
    if (msg.contains('promo_not_started') || msg.contains('aún no')) {
      return 'Esta promo todavía no está disponible.';
    }
    if (msg.contains('attendance') ||
        msg.contains('asistencia') ||
        msg.contains('lista')) {
      return 'Necesitás tener la lista aceptada en el local para obtener esta promo.';
    }
    if (msg.contains('cupo') ||
        msg.contains('agot') ||
        msg.contains('sin cupo')) {
      return 'No quedan cupos para esta promo.';
    }
    if (msg.contains('403') ||
        combined.contains('403') ||
        msg.contains('no autorizado')) {
      return 'No podés obtener esta promo con tu cuenta actual.';
    }
    if (httpStatus == 429 || combined.contains('429')) {
      return 'Demasiados intentos. Esperá un momento y probá de nuevo.';
    }

    final readable = details is String
        ? details.replaceAll('Exception: ', '')
        : _mensajeEdgePromo(details);
    if (readable.isNotEmpty &&
        readable != 'No se pudo obtener la promo') {
      return readable;
    }
    return 'No pudimos obtener la promo. Intentá de nuevo en unos momentos.';
  }

  Future<void> _dialogoPromo(String titulo, String mensaje) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(mensaje),
        ),
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

  /// Hace SELECT del token recién creado, con hasta 3 reintentos (180ms, 400ms, 800ms).
  /// La edge inserta con service_role, pero el cliente lee con su JWT — a veces hay
  /// pequeño lag de replicación o caché. Reintentos garantizan visibilidad.
  Future<Map<String, dynamic>?> _fetchTokenPromoConRetry(String idPromo) async {
    final sb = ServicioSupabase().cliente;
    final userId = sb.auth.currentUser?.id;
    if (userId == null) return null;
    const delays = [Duration(milliseconds: 180), Duration(milliseconds: 400), Duration(milliseconds: 800)];
    for (var intento = 0; intento < delays.length; intento++) {
      try {
        final res = await sb
            .from('tokens_promociones')
            .select('id_promocion, token_codigo, estado_token')
            .eq('id_usuario', userId)
            .eq('id_promocion', idPromo)
            .inFilter('estado_token', _kEstadosTokenPromoUsuario)
            .order('fecha_creacion', ascending: false)
            .limit(1);
        final lista = List<Map<String, dynamic>>.from(res as List);
        debugPrint('[Actividad Promos] fetch token intento ${intento + 1}: ${lista.length} rows');
        if (lista.isNotEmpty) return lista.first;
      } catch (e) {
        debugPrint('[Actividad Promos] fetch token error intento ${intento + 1}: $e');
      }
      if (intento < delays.length - 1) await Future.delayed(delays[intento]);
    }
    return null;
  }

  Future<void> _obtenerPromo(Map<String, dynamic> promo) async {
    final idPromo = promo['id_promocion']?.toString() ?? '';
    if (idPromo.isEmpty) return;
    if (_faseObtenerPromo[idPromo] == _FaseBotonObtenerPromo.cargando) {
      return;
    }
    _timersObtenerPromo[idPromo]?.cancel();
    _timersObtenerPromo.remove(idPromo);

    final sb = ServicioSupabase().cliente;
    setState(() {
      _faseObtenerPromo[idPromo] = _FaseBotonObtenerPromo.cargando;
    });

    // ── FASE 1: invocar edge ──
    try {
      final edgeResponse = await sb.functions.invoke(
        'reservar_promocion',
        body: {'id_promocion': idPromo},
      );
      debugPrint(
        '[Actividad Promos] reservar_promocion status=${edgeResponse.status}'
        ' data=${edgeResponse.data}',
      );
    } on FunctionException catch (fe) {
      debugPrint('[Actividad Promos] FunctionException status=${fe.status} details=${fe.details}');
      if (!mounted) return;
      // Si es "duplicate" y ya teníamos token, simplemente ocultamos el botón
      final dup = _errorPromoDuplicada(fe.details);
      if (dup) {
        // Recargar tokens para reflejar el estado real
        final token = await _fetchTokenPromoConRetry(idPromo);
        if (!mounted) return;
        if (token != null) {
          setState(() {
            _misTokens[idPromo] = token['token_codigo']?.toString() ?? '';
            _estadoTokenPromo[idPromo] =
                token['estado_token']?.toString().toLowerCase() ?? 'activo';
            _faseObtenerPromo.remove(idPromo);
            _qrExpandido.add(idPromo);
          });
          HapticFeedback.lightImpact();
          unawaited(widget.onReloadActividadDesdePromos?.call());
          return;
        }
      }
      setState(() => _faseObtenerPromo.remove(idPromo));
      await _dialogoPromo(
        'No se pudo obtener la promo',
        _mensajePromoAmigable(fe.details, fe.status),
      );
      return;
    } catch (e, st) {
      debugPrint('[Actividad Promos] _obtenerPromo invoke error: $e\n$st');
      if (!mounted) return;
      setState(() => _faseObtenerPromo.remove(idPromo));
      await _dialogoPromo(
        'No se pudo obtener la promo',
        _mensajePromoAmigable(e, null),
      );
      return;
    }

    // ── FASE 2: edge devolvió 200 — leer el token recién creado ──
    HapticFeedback.mediumImpact();
    final token = await _fetchTokenPromoConRetry(idPromo);

    if (!mounted) return;

    if (token != null) {
      // ÉXITO TOTAL: cambiar a "Mostrar QR" + auto-expandir + actualizar contador cupos
      setState(() {
        _misTokens[idPromo] = token['token_codigo']?.toString() ?? '';
        _estadoTokenPromo[idPromo] =
            token['estado_token']?.toString().toLowerCase() ?? 'activo';
        _qrExpandido.add(idPromo);
        _faseObtenerPromo.remove(idPromo);
        // Bump local de cupos_usados para reflejar inmediatamente el cambio
        final idx = _promos.indexWhere((p) => p['id_promocion']?.toString() == idPromo);
        if (idx != -1) {
          final actual = _promos[idx];
          final usados = (actual['cupos_usados'] as int?) ?? 0;
          _promos[idx] = {...actual, 'cupos_usados': usados + 1};
        }
      });
      // Best-effort: refrescar padre (no bloquea ni rompe nada)
      unawaited(widget.onReloadActividadDesdePromos?.call());
      return;
    }

    // ── Caso raro: edge OK pero no podemos leer el token (lag/RLS) ──
    // Mostramos estado "obtenida" 2s y luego forzamos reload completo.
    setState(() => _faseObtenerPromo[idPromo] = _FaseBotonObtenerPromo.exitoCheck);
    _timersObtenerPromo[idPromo] = Timer(const Duration(seconds: 2), () async {
      await widget.onReloadActividadDesdePromos?.call();
      if (!mounted) return;
      await _cargarPromos();
      if (!mounted) return;
      setState(() {
        _faseObtenerPromo.remove(idPromo);
        // Si vino el token tras reload, auto-expandir
        if (_misTokens[idPromo]?.isNotEmpty == true) {
          _qrExpandido.add(idPromo);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: SuperficiesApp.bottomSheet(topRadius: 24),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: ColoresApp.textoSecundario.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.tag_fill,
                      color: ColoresApp.promoMarca,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promos del evento${_promos.isNotEmpty ? ' (${_promos.length})' : ''}',
                            style: GoogleFonts.baloo2(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            widget.token['titulo'] as String? ?? '',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              color: ColoresApp.textoSecundario,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: ColoresApp.textoSecundario.withOpacity(0.85),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                height: 1,
                color: ColoresApp.principalMarca.withOpacity(0.10),
              ),
              const SizedBox(height: 4),
              if (!_cargando && _errorMsg == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.puedeObtenerPromos
                          ? const Color(0xFF34C759).withOpacity(0.12)
                          : ColoresApp.promoMarca.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.puedeObtenerPromos
                            ? const Color(0xFF34C759).withOpacity(0.42)
                            : ColoresApp.promoMarca.withOpacity(0.38),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          widget.puedeObtenerPromos
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.clock_fill,
                          size: 18,
                          color: widget.puedeObtenerPromos
                              ? const Color(0xFF34C759)
                              : ColoresApp.promoMarca,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.puedeObtenerPromos
                                ? 'Tu lista está confirmada. Podés obtener cada promo hasta su fecha de fin.'
                                : 'Tu lista está pendiente. Cuando el local la acepte vas a poder obtener tus promos.',
                            style: GoogleFonts.baloo2(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.textoPrincipal,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Contenido
              Expanded(
                child: _cargando
                    ? const Center(child: CupertinoActivityIndicator(radius: 14))
                    : _errorMsg != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.exclamationmark_triangle_fill,
                                    size: 40,
                                    color: ColoresApp.peligroMarca,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No pudimos cargar las promos',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: ColoresApp.textoPrincipal,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMsg!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
                                      fontSize: 13,
                                      color: ColoresApp.textoSecundario,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: _cargarPromos,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 22, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: ColoresApp.promoMarca,
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Text(
                                        'Reintentar',
                                        style: GoogleFonts.baloo2(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                    : _promos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.tag,
                                  size: 48,
                                  color: ColoresApp.textoSecundario.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sin promos activas',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: ColoresApp.textoSecundario,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Este evento no tiene promos disponibles por ahora',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    color: ColoresApp.textoSecundario.withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _promos.length,
                            itemBuilder: (context, index) {
                              final p = _promos[index];
                              final idPromo =
                                  p['id_promocion']?.toString() ?? '';
                              final codigo = _misTokens[idPromo] ?? '';
                              final yaGuardada = codigo.isNotEmpty;
                              final qrVisible =
                                  _qrExpandido.contains(idPromo);
                              final faseBtn = _faseObtenerPromo[idPromo];
                              final tituloPromo =
                                  p['titulo_promocion']?.toString() ?? 'Promo';
                              final descripcion = _descripcionPromoRow(p);
                              final estadoTp =
                                  _estadoTokenPromo[idPromo] ?? 'activo';
                              final esCanjeada = estadoTp == 'canjeado';
                              final fechaIni = _formatearFechaPromoActividad(
                                p['fecha_inicio']?.toString(),
                              );
                              final fechaFin = _formatearFechaPromoActividad(
                                p['fecha_fin']?.toString(),
                              );
                              final cuposRaw = p['cupos_totales'];
                              final cupoTotal = cuposRaw is int
                                  ? cuposRaw
                                  : int.tryParse(cuposRaw?.toString() ?? '');
                              final cuRaw = p['cupos_usados'];
                              final cupoUsados = cuRaw is int
                                  ? cuRaw
                                  : int.tryParse(cuRaw?.toString() ?? '') ?? 0;
                              final cuposLibres = cupoTotal != null
                                  ? cupoTotal - cupoUsados
                                  : null;
                              final promoVigente = _promoVigente(p);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  decoration: SuperficiesApp.card(
                                    radius: 18,
                                    temaTint: 0.18,
                                    sombraAlpha: 0.12,
                                    sombraBlur: 8,
                                    sombraOffsetY: 3,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(7),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF8C42)
                                                        .withOpacity(0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    CupertinoIcons.gift_fill,
                                                    size: 16,
                                                    color: Color(0xFFFF8C42),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        tituloPromo,
                                                        style: GoogleFonts.baloo2(
                                                          fontSize: 16.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: ColoresApp
                                                              .textoPrincipal,
                                                          height: 1.2,
                                                        ),
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                      if (yaGuardada) ...[
                                                        const SizedBox(height: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: esCanjeada
                                                                ? ColoresApp
                                                                    .textoSecundario
                                                                    .withOpacity(
                                                                        0.18)
                                                                : ColoresApp
                                                                    .promoMarca
                                                                    .withOpacity(
                                                                        0.2),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: Text(
                                                            esCanjeada
                                                                ? 'Canjeada'
                                                                : 'Obtenida',
                                                            style: GoogleFonts
                                                                .baloo2(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight.w800,
                                                              color: esCanjeada
                                                                  ? ColoresApp
                                                                      .textoSecundario
                                                                  : ColoresApp
                                                                      .promoMarca,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                if (cuposLibres != null &&
                                                    cuposLibres > 0 &&
                                                    cuposLibres <= 15) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: ColoresApp
                                                          .peligroMarca
                                                          .withOpacity(0.85),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          CupertinoIcons
                                                              .flame_fill,
                                                          size: 11,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          '$cuposLibres',
                                                          style: GoogleFonts
                                                              .baloo2(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (fechaIni.isNotEmpty ||
                                                fechaFin.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.calendar,
                                                    size: 13,
                                                    color: ColoresApp
                                                        .textoSecundario,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      fechaIni.isNotEmpty &&
                                                              fechaFin.isNotEmpty
                                                          ? '$fechaIni — $fechaFin'
                                                          : (fechaIni.isNotEmpty
                                                              ? fechaIni
                                                              : fechaFin),
                                                      style: GoogleFonts.baloo2(
                                                        fontSize: 12,
                                                        color: ColoresApp
                                                            .textoSecundario,
                                                      ),
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (descripcion.trim().isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Text(
                                                descripcion,
                                                style: GoogleFonts.baloo2(
                                                  fontSize: 13,
                                                  color: ColoresApp
                                                      .textoSecundario,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 14),
                                            if (!widget.puedeObtenerPromos)
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 12, horizontal: 14),
                                                decoration: BoxDecoration(
                                                  color: ColoresApp.fondoSuperficie
                                                      .withOpacity(0.95),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: ColoresApp
                                                        .textoSecundario
                                                        .withOpacity(0.28),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons.lock_fill,
                                                      size: 16,
                                                      color: ColoresApp
                                                          .textoSecundario,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        'Disponible cuando acepten tu lista en el local.',
                                                        style: GoogleFonts.baloo2(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: ColoresApp
                                                              .textoSecundario,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (!promoVigente && !yaGuardada)
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 12, horizontal: 14),
                                                decoration: BoxDecoration(
                                                  color: ColoresApp.fondoSuperficie
                                                      .withOpacity(0.95),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: ColoresApp.peligroMarca
                                                        .withOpacity(0.35),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons
                                                          .exclamationmark_circle_fill,
                                                      size: 16,
                                                      color: ColoresApp.peligroMarca,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        'Esta promo ya finalizó y no se puede obtener.',
                                                        style: GoogleFonts.baloo2(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: ColoresApp
                                                              .textoSecundario,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (yaGuardada)
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (qrVisible) {
                                                      _qrExpandido
                                                          .remove(idPromo);
                                                    } else {
                                                      _qrExpandido
                                                          .add(idPromo);
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 14),
                                                  decoration: BoxDecoration(
                                                    color: ColoresApp.promoMarca
                                                        .withOpacity(0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(50),
                                                    border: Border.all(
                                                      color: ColoresApp
                                                          .promoMarca
                                                          .withOpacity(0.55),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        qrVisible
                                                            ? CupertinoIcons
                                                                .chevron_up_circle_fill
                                                            : CupertinoIcons
                                                                .qrcode_viewfinder,
                                                        size: 18,
                                                        color: ColoresApp
                                                            .promoMarca,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        qrVisible
                                                            ? 'Ocultar QR'
                                                            : 'Mostrar QR',
                                                        style: GoogleFonts.baloo2(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: ColoresApp
                                                              .promoMarca,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            else if (faseBtn ==
                                                _FaseBotonObtenerPromo.cargando)
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: ColoresApp.promoMarca
                                                      .withOpacity(0.38),
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const CupertinoActivityIndicator(
                                                      color: Colors.white,
                                                      radius: 11,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      'Obteniendo…',
                                                      style:
                                                          GoogleFonts.baloo2(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (faseBtn ==
                                                _FaseBotonObtenerPromo
                                                    .exitoCheck)
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF34C759),
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF34C759)
                                                          .withOpacity(0.35),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      CupertinoIcons
                                                          .checkmark_circle_fill,
                                                      size: 22,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '¡Listo!',
                                                      style:
                                                          GoogleFonts.baloo2(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              GestureDetector(
                                                onTap: () => _obtenerPromo(p),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 14),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        ColoresApp.promoMarca,
                                                        ColoresApp.promoMarca
                                                            .withOpacity(0.85),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(50),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: ColoresApp
                                                            .promoMarca
                                                            .withOpacity(0.4),
                                                        blurRadius: 12,
                                                        offset:
                                                            const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(
                                                        CupertinoIcons
                                                            .gift_fill,
                                                        size: 18,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Obtener promo',
                                                        style: GoogleFonts
                                                            .baloo2(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (widget.puedeObtenerPromos &&
                                          yaGuardada &&
                                          qrVisible)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 0, 16, 16),
                                          child: Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: ColoresApp.fondoSuperficie
                                                  .withOpacity(0.65),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: ColoresApp.promoMarca
                                                    .withOpacity(0.22),
                                              ),
                                            ),
                                            child: _PanelQrCodigoPromo(
                                              codigo: codigo,
                                              tituloPromo: tituloPromo,
                                              canjeada: esCanjeada,
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
            ],
          ),
        ),
      ),
    );
  }
}
