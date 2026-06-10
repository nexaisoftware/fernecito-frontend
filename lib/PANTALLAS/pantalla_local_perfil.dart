/// Pantalla perfil del local: avatar, nombre, calificaciones, ubicación, fotos, promos/eventos, lugares similares.
library;

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/servicio_reportes.dart';
import '../core/supabase_client.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import 'pantalla_resenas_locales.dart';
import 'pantalla_ver_evento.dart';
import '../widgets/social_ui.dart';

bool _avatarUrlEsAsset(String url) => url.startsWith('assets/');

class PantallaLocalPerfil extends StatefulWidget {
  final String avatarUrl;
  final String nombreLocal;
  final String? idLocal; // nullable so existing call sites still work

  const PantallaLocalPerfil({
    super.key,
    required this.avatarUrl,
    required this.nombreLocal,
    this.idLocal,
  });

  @override
  State<PantallaLocalPerfil> createState() => _PantallaLocalPerfilState();
}

class _PantallaLocalPerfilState extends State<PantallaLocalPerfil>
    with SingleTickerProviderStateMixin {
  bool _infoExpandida = false;
  AnimationController? _breathController;
  Animation<double>? _breathScale;

  // Loading state
  bool _cargando = true;
  bool _bloqueado = false;

  // Real data fields (todos mapean a columnas reales de `perfiles_locales`)
  String? _descripcion;
  String? _instagramUrl;
  String? _tiktokUrl;
  String? _sitioWebUrl;
  String? _ciudad;
  String? _provincia;
  String? _direccion;
  String? _urlMaps;
  List<String> _rubros = [];
  bool _verificado = false;
  double? _calificacionPromedio;
  int _calificacionCantidad = 0;
  String? _bannerUrl;
  List<Map<String, dynamic>> _eventos = [];
  List<String> _fotosLocal = []; // URLs resueltas
  String _avatarEffective = '';
  List<Map<String, dynamic>> _lugaresPopulares = [];

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathScale = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _breathController!, curve: Curves.easeInOut),
    );
    _avatarEffective = widget.avatarUrl;
    _cargarDatos();
  }

  @override
  void dispose() {
    _breathController?.dispose();
    super.dispose();
  }

  /// Resuelve una path de storage a URL pública. Si ya es http, la devuelve tal cual.
  String _resolverPathStorage(SupabaseClient sb, String? path, String bucket) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return sb.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> _cargarDatos() async {
    if (widget.idLocal == null || widget.idLocal!.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    try {
      final sb = ServicioSupabase().cliente;

      // 1) Perfil del local — columnas reales del schema
      final local = await sb
          .from('perfiles_locales')
          .select(
            'id, nombre_local, descripcion_local, '
            'url_instagram, url_tiktok, url_website, '
            'ciudad, provincia, direccion, url_maps, rubro, '
            'local_verificado, calificacion_promedio, calificacion_cantidad, '
            'foto_perfil_url, url_foto_banner, estado_cuenta, '
            'foto_local_1, foto_local_2, foto_local_3, foto_local_4, foto_local_5',
          )
          .eq('id', widget.idLocal!)
          .maybeSingle();

      if (local == null) {
        if (mounted) setState(() => _cargando = false);
        return;
      }

      // 2) Eventos publicados del local
      List<Map<String, dynamic>> eventos = [];
      try {
        final eventosRaw = await sb
            .from('eventos')
            .select(
              'id_evento, titulo_evento, descripcion_evento, url_flyer, '
              'fecha_inicio, fecha_fin, jerarquia, id_local, tipo_evento, '
              'tiene_promo, ciudad_evento, provincia_evento, '
              'cupo_lista_max, cupo_lista_usados, modo_lista',
            )
            .eq('id_local', widget.idLocal!)
            .eq('estado_publicacion', 'publicado')
            .order('fecha_inicio', ascending: true)
            .limit(10);
        eventos = List<Map<String, dynamic>>.from(eventosRaw as List);
      } catch (e) {
        debugPrint('[LocalPerfil] eventos: $e');
      }

      // 3) Resolver fotos locales (foto_local_1..5 → URLs públicas en bucket fotos_locales)
      final fotos = <String>[];
      for (var i = 1; i <= 5; i++) {
        final path = local['foto_local_$i']?.toString();
        final url = _resolverPathStorage(sb, path, 'fotos_locales');
        if (url.isNotEmpty) fotos.add(url);
      }

      // 4) Resolver avatar y banner
      final avatarEff =
          _resolverPathStorage(
            sb,
            local['foto_perfil_url']?.toString(),
            'avatars_locales',
          ).isNotEmpty
          ? _resolverPathStorage(
              sb,
              local['foto_perfil_url']?.toString(),
              'avatars_locales',
            )
          : widget.avatarUrl;
      final bannerEff = _resolverPathStorage(
        sb,
        local['url_foto_banner']?.toString(),
        'banners_locales',
      );

      // 5) "Más lugares": últimos locales en misma ciudad y provincia
      List<Map<String, dynamic>> populares = [];
      final ciudadLocal = local['ciudad']?.toString().trim() ?? '';
      final provinciaLocal = local['provincia']?.toString().trim() ?? '';
      try {
        List<dynamic> rawPop = [];
        if (ciudadLocal.isNotEmpty || provinciaLocal.isNotEmpty) {
          try {
            final rpc = await sb.rpc(
              'locales_mas_en_zona',
              params: {
                'p_ciudad': ciudadLocal.isEmpty ? null : ciudadLocal,
                'p_provincia': provinciaLocal.isEmpty ? null : provinciaLocal,
                'p_excluir': widget.idLocal,
                'p_limit': 8,
              },
            );
            if (rpc is List) rawPop = rpc;
          } catch (e) {
            debugPrint('[LocalPerfil] locales_mas_en_zona RPC: $e');
          }
        }
        if (rawPop.isEmpty &&
            (ciudadLocal.isNotEmpty || provinciaLocal.isNotEmpty)) {
          var q = sb
              .from('perfiles_locales')
              .select(
                'id, nombre_local, foto_perfil_url, ciudad, provincia, local_verificado, rubro, fecha_creacion',
              )
              .neq('id', widget.idLocal!);
          if (ciudadLocal.isNotEmpty) {
            q = q.ilike('ciudad', ciudadLocal);
          }
          if (provinciaLocal.isNotEmpty) {
            q = q.ilike('provincia', provinciaLocal);
          }
          final res = await q
              .order('fecha_creacion', ascending: false)
              .limit(8);
          rawPop = res as List;
        }
        populares = rawPop.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          final avatarPath = m['foto_perfil_url']?.toString();
          return {
            'id': m['id']?.toString() ?? '',
            'nombre': m['nombre_local']?.toString() ?? 'Local',
            'avatar': _resolverPathStorage(sb, avatarPath, 'avatars_locales'),
            'ciudad': m['ciudad']?.toString() ?? '',
            'provincia': m['provincia']?.toString() ?? '',
            'verificado': m['local_verificado'] == true,
            'rubro': (m['rubro'] is List && (m['rubro'] as List).isNotEmpty)
                ? (m['rubro'] as List).first.toString()
                : '',
          };
        }).toList();
      } catch (e) {
        debugPrint('[LocalPerfil] mas lugares: $e');
      }

      // 6) Calificación
      final cal = local['calificacion_promedio'];
      final calNum = cal is num
          ? cal.toDouble()
          : double.tryParse(cal?.toString() ?? '');
      final calCant = local['calificacion_cantidad'];
      final calCantInt = calCant is int
          ? calCant
          : (calCant != null ? int.tryParse(calCant.toString()) ?? 0 : 0);

      // 7) Rubros
      final rubroRaw = local['rubro'];
      final rubrosList = rubroRaw is List
          ? rubroRaw
                .map((r) => r.toString())
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>[];

      if (!mounted) return;
      setState(() {
        _descripcion = local['descripcion_local']?.toString();
        _instagramUrl = local['url_instagram']?.toString();
        _tiktokUrl = local['url_tiktok']?.toString();
        _sitioWebUrl = local['url_website']?.toString();
        _ciudad = local['ciudad']?.toString();
        _provincia = local['provincia']?.toString();
        _direccion = local['direccion']?.toString();
        _urlMaps = local['url_maps']?.toString();
        _rubros = rubrosList;
        _verificado = local['local_verificado'] == true;
        _calificacionPromedio = (calNum != null && calNum > 0) ? calNum : null;
        _calificacionCantidad = calCantInt;
        _bannerUrl = bannerEff.isNotEmpty ? bannerEff : null;
        _eventos = eventos;
        _fotosLocal = fotos;
        _avatarEffective = avatarEff;
        _lugaresPopulares = populares;
        _bloqueado =
            (local['estado_cuenta']?.toString() ?? 'activa') != 'activa';
        _cargando = false;
      });
    } catch (e, st) {
      debugPrint('[LocalPerfil] _cargarDatos error: $e\n$st');
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Texto de ubicación armado: "Ciudad, Provincia" (o lo que tenga).
  String get _ubicacionTextoComputed {
    final c = (_ciudad ?? '').trim();
    final p = (_provincia ?? '').trim();
    if (c.isNotEmpty && p.isNotEmpty) return '$c, $p';
    if (c.isNotEmpty) return c;
    if (p.isNotEmpty) return p;
    return '';
  }

  Map<String, dynamic> _eventoParaVer(Map<String, dynamic> row) {
    final idEvento = row['id_evento']?.toString() ?? '';
    final cupoMax = row['cupo_lista_max'] as int?;
    final cupoUsados = (row['cupo_lista_usados'] as int?) ?? 0;
    final cuposLibres = cupoMax != null ? (cupoMax - cupoUsados) : null;
    return {
      'id': idEvento,
      'titulo': row['titulo_evento'] ?? '',
      'descripcion': row['descripcion_evento'] ?? '',
      'flyer': row['url_flyer'] ?? '',
      'nombreLocal': widget.nombreLocal,
      'avatarLocal': _avatarEffective,
      'idLocal': widget.idLocal,
      'localVerificado': _verificado,
      'jerarquia': row['jerarquia'] ?? 'gratis',
      'tipoEvento': (row['tipo_evento']?.toString() ?? 'otro').toLowerCase(),
      'tienePromo': row['tiene_promo'] == true,
      'cupoMax': cupoMax,
      'cuposLibres': cuposLibres,
      'cupoLimitado': cupoMax != null,
      'modoLista': row['modo_lista'] ?? 'auto',
      'fechaInicio': row['fecha_inicio'],
      'fechaFin': row['fecha_fin'],
      'ciudadEvento': row['ciudad_evento']?.toString(),
      'provinciaEvento': row['provincia_evento']?.toString(),
    };
  }

  void _abrirEvento(Map<String, dynamic> eventoRow) {
    final id = eventoRow['id_evento']?.toString() ?? '';
    if (id.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaVerEvento(evento: _eventoParaVer(eventoRow)),
      ),
    );
  }

  /// Label cualitativa del rating.
  String _labelRating(double r) {
    if (r >= 4.5) return 'Excelente';
    if (r >= 4.0) return 'Muy bueno';
    if (r >= 3.5) return 'Bueno';
    if (r >= 3.0) return 'Regular';
    return 'Bajo';
  }

  Future<void> _abrirUbicacion(BuildContext context) async {
    // Si el local cargó url_maps, lo usamos directo (Google Maps / Maps app).
    if (_urlMaps != null && _urlMaps!.isNotEmpty) {
      final u = Uri.tryParse(_urlMaps!);
      if (u != null && await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Fallback: armar query con dirección + ciudad o nombre del local
    final partes = <String>[
      if (_direccion != null && _direccion!.isNotEmpty) _direccion!,
      if (_ubicacionTextoComputed.isNotEmpty) _ubicacionTextoComputed,
    ];
    final query = partes.isNotEmpty ? partes.join(', ') : widget.nombreLocal;
    final url = Uri.parse(
      'https://maps.google.com/?q=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reportarLocal() async {
    final id = widget.idLocal;
    if (id == null || id.isEmpty) return;
    final motivo = await showCupertinoModalPopup<MotivoReporte>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Reportar local'),
        message: const Text('Elegí el motivo principal del reporte.'),
        actions: motivosReporteCuenta
            .map(
              (m) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, m),
                child: Text(m.label),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (motivo == null) return;
    final res = await ServicioReportes().reportarCuenta(
      reportanteTipo: 'usuario',
      targetTipo: 'local',
      targetId: id,
      motivo: motivo.codigo,
    );
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reporte enviado'),
        content: Text(
          res['ok'] == true
              ? 'Gracias. Vamos a revisar este local.'
              : (res['error']?.toString() ?? 'No se pudo enviar el reporte.'),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalBloqueado(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final nombre = widget.nombreLocal.trim().isNotEmpty
        ? widget.nombreLocal.trim()
        : 'Local';
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(8, padding.top > 0 ? 4 : 8, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(CupertinoIcons.back,
                        color: ColoresApp.principalMarca),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ColoresApp.fondoSuperficie,
                            border: Border.all(
                              color: ColoresApp.textoSecundario
                                  .withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.building_2_fill,
                            size: 50,
                            color:
                                ColoresApp.textoSecundario.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          nombre,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color:
                                ColoresApp.fondoSuperficie.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: ColoresApp.textoSecundario
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_shield_fill,
                                size: 28,
                                color: ColoresApp.textoSecundario,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Cuenta bloqueada temporalmente por el equipo '
                                'de moderación de Fernecito.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.baloo2(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ColoresApp.textoSecundario,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    // Show loading indicator while fetching data
    if (_cargando) {
      return CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: FondoGradienteFernecito(
          corto: true,
          child: const Center(child: CupertinoActivityIndicator(radius: 18)),
        ),
      );
    }

    // Cuenta bloqueada por moderación: sin foto, banner ni eventos. Solo el
    // nombre con ícono redondo + cartel.
    if (_bloqueado) {
      return _buildLocalBloqueado(context);
    }

    // Banner: usa el banner real si existe, sino cae en el avatar como antes.
    final bannerSource = (_bannerUrl != null && _bannerUrl!.isNotEmpty)
        ? _bannerUrl!
        : _avatarEffective;
    final nombreLocal = widget.nombreLocal;

    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final bannerHeight = (screenHeight * 0.43).clamp(320.0, 460.0).toDouble();

    final padding = MediaQuery.of(context).padding;
    // Responsive: pantallas estrechas reducen tamaños para evitar overflow
    final isNarrow = screenWidth < 400;
    final avatarSize = isNarrow ? 72.0 : 100.0;
    final horizontalPadding = isNarrow ? 16.0 : 24.0;
    final photoCardWidth = (screenWidth - horizontalPadding * 2 - 14).clamp(
      160.0,
      210.0,
    );

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: CustomScrollView(
          slivers: [
            // Banner: pegado al borde superior (sin safe area), degradado super agresivo solo en la parte inferior
            SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                height: bannerHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner: imagen + overlay enmascarados juntos para fundirse con el degradado de fondo (sin borde duro)
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.55, 0.85, 1.0],
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.65),
                            Colors.white.withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Banner image: use avatar as banner if available, otherwise show placeholder
                            _avatarUrlEsAsset(bannerSource)
                                ? Image.asset(
                                    bannerSource,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: ColoresApp.fondoSuperficie,
                                      child: const Icon(
                                        CupertinoIcons.photo,
                                        size: 64,
                                        color: ColoresApp.textoSecundario,
                                      ),
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: bannerSource,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: ColoresApp.fondoSuperficie,
                                      child: const Icon(
                                        CupertinoIcons.photo,
                                        size: 64,
                                        color: ColoresApp.textoSecundario,
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: ColoresApp.fondoSuperficie,
                                      child: const Icon(
                                        CupertinoIcons.photo,
                                        size: 64,
                                        color: ColoresApp.textoSecundario,
                                      ),
                                    ),
                                  ),
                            // Overlay oscuro (también enmascarado: se desvanece con la imagen)
                            Container(color: Colors.black.withOpacity(0.45)),
                          ],
                        ),
                      ),
                    ),
                    // Contenido: avatar, nombre, puntuación, botones (responsive, scroll si overflow)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          padding.top + 16,
                          horizontalPadding,
                          24,
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: avatarSize,
                                  height: avatarSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ColoresApp.principalMarca
                                          .withOpacity(0.8),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _avatarUrlEsAsset(_avatarEffective)
                                        ? Image.asset(
                                            _avatarEffective,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  CupertinoIcons
                                                      .building_2_fill,
                                                  size: 48,
                                                  color: ColoresApp
                                                      .textoSecundario,
                                                ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: _avatarEffective,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => const Icon(
                                              CupertinoIcons.building_2_fill,
                                              size: 48,
                                              color: ColoresApp.textoSecundario,
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                                  CupertinoIcons
                                                      .building_2_fill,
                                                  size: 48,
                                                  color: ColoresApp
                                                      .textoSecundario,
                                                ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _breathScale != null
                                    ? ScaleTransition(
                                        scale: _breathScale!,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            nombreLocal,
                                            style: GoogleFonts.baloo2(
                                              fontSize: isNarrow ? 18 : 22,
                                              fontWeight: FontWeight.w800,
                                              color: ColoresApp.textoPrincipal,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          nombreLocal,
                                          style: GoogleFonts.baloo2(
                                            fontSize: isNarrow ? 18 : 22,
                                            fontWeight: FontWeight.w800,
                                            color: ColoresApp.textoPrincipal,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                if (_verificado) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: 14,
                                        color: ColoresApp.principalMarca,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verificado',
                                        style: GoogleFonts.baloo2(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: ColoresApp.principalMarca,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (_) => PantallaResenasLocales(
                                          nombreLocal: nombreLocal,
                                          idLocal: widget.idLocal,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 2.1,
                                        sigmaY: 2.1,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          border: Border.all(
                                            color: ColoresApp.principalMarca
                                                .withOpacity(0.45),
                                          ),
                                          gradient: RadialGradient(
                                            center: Alignment.center,
                                            radius: 1.2,
                                            colors: [
                                              ColoresApp.principalMarca
                                                  .withOpacity(0.28),
                                              ColoresApp.principalMarca
                                                  .withOpacity(0.08),
                                            ],
                                          ),
                                        ),
                                        child: _calificacionPromedio == null
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.star,
                                                    color: ColoresApp
                                                        .principalMarca,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Sin calificaciones aún',
                                                    style: GoogleFonts.baloo2(
                                                      fontSize: 14,
                                                      color: ColoresApp
                                                          .principalMarca,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.star_fill,
                                                    color: ColoresApp
                                                        .principalMarca,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${_calificacionPromedio!.toStringAsFixed(1)} • ${_labelRating(_calificacionPromedio!)}'
                                                    '${_calificacionCantidad > 0 ? '  ·  $_calificacionCantidad' : ''}',
                                                    style: GoogleFonts.baloo2(
                                                      fontSize: 14,
                                                      color: ColoresApp
                                                          .principalMarca,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isNarrow ? 14 : 18),
                                // Fila de iconos modernos sin contenedor (solo glow)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isNarrow ? 4 : 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _IconoEnlace(
                                        icon: CupertinoIcons.location_solid,
                                        onTap: () => _abrirUbicacion(context),
                                        size: isNarrow ? 24 : 28,
                                      ),
                                      if (_instagramUrl != null &&
                                          _instagramUrl!.isNotEmpty) ...[
                                        SizedBox(width: isNarrow ? 22 : 28),
                                        _IconoEnlace(
                                          icon: FontAwesomeIcons.instagram,
                                          useFontAwesome: true,
                                          onTap: () =>
                                              _abrirUrl(_instagramUrl!),
                                          size: isNarrow ? 24 : 28,
                                        ),
                                      ],
                                      if (_tiktokUrl != null &&
                                          _tiktokUrl!.isNotEmpty) ...[
                                        SizedBox(width: isNarrow ? 22 : 28),
                                        _IconoEnlace(
                                          icon: FontAwesomeIcons.tiktok,
                                          useFontAwesome: true,
                                          onTap: () => _abrirUrl(_tiktokUrl!),
                                          size: isNarrow ? 24 : 28,
                                        ),
                                      ],
                                      if (_sitioWebUrl != null &&
                                          _sitioWebUrl!.isNotEmpty) ...[
                                        SizedBox(width: isNarrow ? 22 : 28),
                                        _IconoEnlace(
                                          icon: CupertinoIcons.globe,
                                          onTap: () => _abrirUrl(_sitioWebUrl!),
                                          size: isNarrow ? 24 : 28,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: padding.top + 10,
                      right: horizontalPadding,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        onPressed: _reportarLocal,
                        child: Text(
                          'Reportar',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info del lugar (solo texto + flecha a la derecha, sin contenedor; al tocar despliega)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _infoExpandida = !_infoExpandida),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Info del lugar',
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _infoExpandida ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              CupertinoIcons.chevron_down,
                              size: 20,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_descripcion != null &&
                                _descripcion!.trim().isNotEmpty)
                              Text(
                                _descripcion!,
                                style: GoogleFonts.baloo2(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: ColoresApp.textoPrincipal.withOpacity(
                                    0.95,
                                  ),
                                ),
                              )
                            else
                              Text(
                                'El local todavía no escribió una descripción.',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: ColoresApp.textoSecundario,
                                ),
                              ),
                            if (_ubicacionTextoComputed.isNotEmpty ||
                                (_direccion ?? '').isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    CupertinoIcons.location_solid,
                                    size: 14,
                                    color: ColoresApp.principalMarca,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      [
                                        if ((_direccion ?? '').isNotEmpty)
                                          _direccion!,
                                        if (_ubicacionTextoComputed.isNotEmpty)
                                          _ubicacionTextoComputed,
                                      ].join(' · '),
                                      style: GoogleFonts.baloo2(
                                        fontSize: 13,
                                        color: ColoresApp.textoSecundario,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_rubros.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final r in _rubros)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColoresApp.principalMarca
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: ColoresApp.principalMarca
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        r,
                                        style: GoogleFonts.baloo2(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: ColoresApp.principalMarca,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      crossFadeState: _infoExpandida
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            ),

            // Carrusel fotos del lugar (formato 3:4)
            if (_fotosLocal.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        10,
                      ),
                      child: Text(
                        'Fotos del lugar',
                        style: GoogleFonts.baloo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 280,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        itemCount: _fotosLocal.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    fullscreenDialog: true,
                                    builder: (_) => VisualizadorFotosLocal(
                                      fotos: _fotosLocal,
                                      indiceInicial: index,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: photoCardWidth,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: _fotosLocal[index],
                                    fit: BoxFit.cover,
                                    width: photoCardWidth,
                                    height: 280,
                                    placeholder: (_, __) => Container(
                                      width: photoCardWidth,
                                      height: 280,
                                      color: ColoresApp.fondoSuperficie,
                                      child: const Center(
                                        child: CupertinoActivityIndicator(),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: photoCardWidth,
                                      height: 280,
                                      color: ColoresApp.fondoSuperficie,
                                      child: const Icon(
                                        CupertinoIcons.photo,
                                        size: 48,
                                        color: ColoresApp.textoSecundario,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Otros eventos del mismo local
            if (_eventos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    4,
                  ),
                  child: EncabezadoSeccionSocial(
                    titulo: 'Otros eventos de ${widget.nombreLocal}',
                    subtitulo: 'Tocá un flyer para ver el detalle',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 248,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    itemCount: _eventos.length,
                    itemBuilder: (context, index) {
                      final evento = _eventos[index];
                      final urlFlyer = evento['url_flyer'] as String?;
                      final titulo =
                          evento['titulo_evento'] as String? ?? 'Evento';
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _abrirEvento(evento),
                          child: SizedBox(
                            width: 152,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child:
                                        urlFlyer != null && urlFlyer.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: urlFlyer,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: ColoresApp.fondoSuperficie,
                                              child: const Center(
                                                child:
                                                    CupertinoActivityIndicator(),
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                _EventoPlaceholder(
                                                  titulo: titulo,
                                                ),
                                          )
                                        : _EventoPlaceholder(titulo: titulo),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: ColoresApp.textoPrincipal,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Más lugares (misma ciudad y provincia)
            if (_lugaresPopulares.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    28,
                    horizontalPadding,
                    4,
                  ),
                  child: EncabezadoSeccionSocial(
                    titulo: 'Más lugares',
                    subtitulo: _ubicacionTextoComputed.isNotEmpty
                        ? 'Recién sumados en $_ubicacionTextoComputed'
                        : 'Locales recientes en tu zona',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    32,
                  ),
                  child: Column(
                    children: [
                      for (final loc in _lugaresPopulares)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CardLugarPopular(
                            idLocal: loc['id'] as String? ?? '',
                            nombre: loc['nombre'] as String? ?? 'Local',
                            avatar: loc['avatar'] as String? ?? '',
                            verificado: loc['verificado'] == true,
                            rubro: loc['rubro'] as String? ?? '',
                            ciudad: loc['ciudad'] as String? ?? '',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: padding.bottom)),
          ],
        ),
      ),
    );
  }
}

/// Placeholder para evento sin flyer: fondo oscuro con nombre del evento centrado.
class _EventoPlaceholder extends StatelessWidget {
  final String titulo;
  const _EventoPlaceholder({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColoresApp.fondoSuperficie,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            titulo.isEmpty ? 'Evento' : titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ),
      ),
    );
  }
}

/// Icono moderno sin contenedor, con glow sutil. Reemplaza el botón circular antiguo.
/// Se usa para ubicación, Instagram, TikTok, sitio web en el banner del local.
class _IconoEnlace extends StatefulWidget {
  final IconData icon;
  final bool useFontAwesome;
  final VoidCallback onTap;
  final double size;

  const _IconoEnlace({
    required this.icon,
    required this.onTap,
    this.useFontAwesome = false,
    this.size = 28,
  });

  @override
  State<_IconoEnlace> createState() => _IconoEnlaceState();
}

class _IconoEnlaceState extends State<_IconoEnlace> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.88 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ColoresApp.principalMarca.withOpacity(
                  _pressed ? 0.65 : 0.45,
                ),
                blurRadius: _pressed ? 16 : 12,
                spreadRadius: _pressed ? 1.5 : 0.8,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.useFontAwesome
              ? FaIcon(widget.icon, size: widget.size, color: Colors.white)
              : Icon(widget.icon, size: widget.size, color: Colors.white),
        ),
      ),
    );
  }
}

/// Card limpia y minimalista para la sección "Lugares populares".
class _CardLugarPopular extends StatelessWidget {
  final String idLocal;
  final String nombre;
  final String avatar;
  final bool verificado;
  final String rubro;
  final String ciudad;

  const _CardLugarPopular({
    required this.idLocal,
    required this.nombre,
    required this.avatar,
    required this.verificado,
    required this.rubro,
    required this.ciudad,
  });

  String _capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final subtitulo = [
      if (rubro.isNotEmpty) _capitalizar(rubro),
      if (ciudad.isNotEmpty) ciudad,
    ].join(' · ');
    return CardSuperficieSocial(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => PantallaLocalPerfil(
              avatarUrl: avatar,
              nombreLocal: nombre,
              idLocal: idLocal.isEmpty ? null : idLocal,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AvatarSocial(url: avatar, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                    if (verificado)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 16,
                          color: ColoresApp.principalMarca,
                        ),
                      ),
                  ],
                ),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: ColoresApp.textoSecundario.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

/// Visualizador de fotos del local: fullscreen, fondo con blur, deslizar entre fotos, imagen al 95% del ancho centrada.
/// Acepta tanto URLs de red (http/https) como assets locales (para compatibilidad retroactiva).
class VisualizadorFotosLocal extends StatelessWidget {
  final List<String> fotos;
  final int indiceInicial;

  const VisualizadorFotosLocal({
    super.key,
    required this.fotos,
    this.indiceInicial = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final alto = MediaQuery.of(context).size.height;
    final anchoImagen = ancho * 0.95;

    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo con blur y oscurecimiento
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
          // PageView para deslizar fotos
          PageView.builder(
            controller: PageController(
              initialPage: indiceInicial.clamp(0, fotos.length - 1),
            ),
            itemCount: fotos.length,
            itemBuilder: (context, index) {
              final fotoUrl = fotos[index];
              return Center(
                child: GestureDetector(
                  onTap: () {}, // Evitar que el tap cierre al tocar la imagen
                  child: SizedBox(
                    width: anchoImagen,
                    height: alto,
                    child: fotoUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: fotoUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: ColoresApp.fondoSuperficie,
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 64,
                                  color: ColoresApp.textoSecundario,
                                ),
                              ),
                            ),
                          )
                        : Image.asset(
                            fotoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              color: ColoresApp.fondoSuperficie,
                              child: const Center(
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 64,
                                  color: ColoresApp.textoSecundario,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
          // Botón cerrar arriba
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
