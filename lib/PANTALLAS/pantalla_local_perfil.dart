/// Pantalla perfil del local: avatar, nombre, calificaciones, ubicación, fotos, promos/eventos, lugares similares.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:share_plus/share_plus.dart';
import '../core/auth_redirect.dart';
import '../core/constants.dart';
import '../core/flujo_bloqueo.dart';
import '../core/flujo_reporte.dart';
import '../core/horarios_local.dart';
import '../core/lanzador_externo.dart';
import '../core/servicio_impresiones.dart';
import '../core/servicio_locales_megusta.dart';
import '../core/supabase_client.dart';
import '../widgets/avatar_local.dart';
import '../widgets/boton_megusta_local.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import 'pantalla_resenas_locales.dart';
import 'pantalla_ver_evento.dart';
import '../widgets/social_ui.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/dialogo_fernecito.dart';

bool _avatarUrlEsAsset(String url) => url.startsWith('assets/');

class _CartaLocalItem {
  const _CartaLocalItem({
    required this.categoria,
    required this.nombre,
    this.descripcion = '',
    this.precio,
    this.precioHasta,
    this.moneda = 'ARS',
    this.tipoPrecio = 'fijo',
    this.destacado = false,
  });

  final String categoria;
  final String nombre;
  final String descripcion;
  final double? precio;
  final double? precioHasta;
  final String moneda;
  final String tipoPrecio;
  final bool destacado;

  factory _CartaLocalItem.fromMap(Map<String, dynamic> map) {
    double? n(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return _CartaLocalItem(
      categoria: (map['categoria'] ?? 'Otros').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      precio: n(map['precio']),
      precioHasta: n(map['precio_hasta']),
      moneda: (map['moneda'] ?? 'ARS').toString(),
      tipoPrecio: (map['tipo_precio'] ?? 'fijo').toString(),
      destacado: map['destacado'] == true,
    );
  }
}

class PantallaLocalPerfil extends StatefulWidget {
  final String avatarUrl;
  final String nombreLocal;
  final String? idLocal; // nullable so existing call sites still work
  /// Si true y hay carta, abre el sheet de carta al terminar de cargar.
  final bool abrirCartaAlInicio;

  const PantallaLocalPerfil({
    super.key,
    required this.avatarUrl,
    required this.nombreLocal,
    this.idLocal,
    this.abrirCartaAlInicio = false,
  });

  @override
  State<PantallaLocalPerfil> createState() => _PantallaLocalPerfilState();
}

class _PantallaLocalPerfilState extends State<PantallaLocalPerfil> {
  static const int _maxFotosLocales = 10;
  static final String _selectFotosLocales = List.generate(
    _maxFotosLocales,
    (i) => 'foto_local_${i + 1}',
  ).join(', ');

  bool _infoExpandida = true; // info del lugar desplegada por defecto
  bool _descripcionExpandida = false;

  // Loading state
  bool _cargando = true;
  bool _bloqueado = false;

  // Real data fields (todos mapean a columnas reales de `perfiles_locales`)
  String? _descripcion;
  String? _instagramUrl;
  String? _tiktokUrl;
  String? _sitioWebUrl;
  String? _telefonoWhatsapp;
  String? _whatsappLabel;
  String? _ciudad;
  String? _provincia;
  String? _direccion;
  String? _urlMaps;
  List<String> _rubros = [];
  HorariosLocal _horarios = {};
  bool _verificado = false;
  bool _esPionero = false;
  bool _mostrarCalificaciones = true;
  double? _calificacionPromedio;
  int _calificacionCantidad = 0;
  String? _bannerUrl;
  List<Map<String, dynamic>> _eventos = [];
  List<String> _fotosLocal = []; // URLs resueltas
  List<_CartaLocalItem> _cartaItems = [];
  String _avatarEffective = '';
  List<Map<String, dynamic>> _lugaresPopulares = [];
  int _cantidadMegusta = 0;
  bool _yoMegusta = false;
  bool _toggleMegusta = false;

  bool _visitaPerfilRegistrada = false;

  @override
  void initState() {
    super.initState();
    _avatarEffective = widget.avatarUrl;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _registrarVistaPerfil(),
    );
    _cargarDatos();
  }

  @override
  void dispose() {
    // Manda la visita sin esperar el timer de 30s (aditivo, no rompe cartelera).
    unawaited(ServicioImpresiones.instancia.flush(respetarIntervalo: false));
    super.dispose();
  }

  void _registrarVistaPerfil() {
    if (_visitaPerfilRegistrada) return;
    final id = widget.idLocal?.trim();
    if (id == null || id.isEmpty) return;
    _visitaPerfilRegistrada = true;
    ServicioImpresiones.instancia.registrarVisitaPerfil(idLocal: id);
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
            'url_instagram, url_tiktok, url_website, telefono_whatsapp, whatsapp_label, '
            'ciudad, provincia, direccion, url_maps, rubro, '
            'local_verificado, es_pionero, calificacion_promedio, calificacion_cantidad, '
            'mostrar_calificaciones, '
            'foto_perfil_url, url_foto_banner, estado_cuenta, '
            '$_selectFotosLocales, horarios_json',
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

      // 3) Resolver fotos locales (foto_local_1..10 → URLs públicas en bucket fotos_locales)
      final fotos = <String>[];
      for (var i = 1; i <= _maxFotosLocales; i++) {
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
                'id, nombre_local, foto_perfil_url, ciudad, provincia, local_verificado, es_pionero, rubro, fecha_creacion',
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
        final pionerosPorId = <String, bool>{};
        final verificadosPorId = <String, bool>{};
        final idsPopulares = rawPop
            .whereType<Map>()
            .map((p) => p['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (idsPopulares.isNotEmpty) {
          try {
            final extras = await sb
                .from('perfiles_locales')
                .select('id, local_verificado, es_pionero')
                .inFilter('id', idsPopulares);
            for (final row in extras as List) {
              final map = Map<String, dynamic>.from(row as Map);
              final id = map['id']?.toString() ?? '';
              if (id.isEmpty) continue;
              pionerosPorId[id] = map['es_pionero'] == true;
              verificadosPorId[id] = map['local_verificado'] == true;
            }
          } catch (e) {
            debugPrint('[LocalPerfil] extras pioneros populares: $e');
          }
        }
        populares = rawPop.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          final id = m['id']?.toString() ?? '';
          final esPionero =
              m['es_pionero'] == true || pionerosPorId[id] == true;
          final verificado =
              m['local_verificado'] == true ||
              verificadosPorId[id] == true ||
              esPionero;
          final avatarPath = m['foto_perfil_url']?.toString();
          return {
            'id': id,
            'nombre': m['nombre_local']?.toString() ?? 'Local',
            'avatar': _resolverPathStorage(sb, avatarPath, 'avatars_locales'),
            'ciudad': m['ciudad']?.toString() ?? '',
            'provincia': m['provincia']?.toString() ?? '',
            'verificado': verificado,
            'esPionero': esPionero,
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

      // 8) Carta/precios activos del local. Feature aditiva: si falla, no rompe el perfil.
      List<_CartaLocalItem> cartaItems = [];
      try {
        final cartaRaw = await sb
            .from('locales_carta_items')
            .select(
              'categoria, nombre, descripcion, precio, precio_hasta, moneda, tipo_precio, tags, destacado, orden',
            )
            .eq('id_local', widget.idLocal!)
            .eq('activo', true)
            .order('orden', ascending: true)
            .limit(100);
        cartaItems = (cartaRaw as List)
            .whereType<Map>()
            .map((e) => _CartaLocalItem.fromMap(Map<String, dynamic>.from(e)))
            .where((e) => e.nombre.trim().isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('[LocalPerfil] carta: $e');
      }

      if (!mounted) return;
      setState(() {
        _descripcion = local['descripcion_local']?.toString();
        _horarios = parseHorariosLocal(local['horarios_json']);
        _instagramUrl = local['url_instagram']?.toString();
        _tiktokUrl = local['url_tiktok']?.toString();
        _sitioWebUrl = local['url_website']?.toString();
        _telefonoWhatsapp = local['telefono_whatsapp']?.toString();
        _whatsappLabel = local['whatsapp_label']?.toString();
        _ciudad = local['ciudad']?.toString();
        _provincia = local['provincia']?.toString();
        _direccion = local['direccion']?.toString();
        _urlMaps = local['url_maps']?.toString();
        _rubros = rubrosList;
        _verificado = local['local_verificado'] == true;
        _esPionero = local['es_pionero'] == true;
        // Switch del local: si lo apagó, no mostramos su calificación.
        _mostrarCalificaciones = local['mostrar_calificaciones'] != false;
        _calificacionPromedio = (calNum != null && calNum > 0) ? calNum : null;
        _calificacionCantidad = calCantInt;
        _bannerUrl = bannerEff.isNotEmpty ? bannerEff : null;
        _eventos = eventos;
        _fotosLocal = fotos;
        _cartaItems = cartaItems;
        _avatarEffective = avatarEff;
        _lugaresPopulares = populares;
        _bloqueado =
            (local['estado_cuenta']?.toString() ?? 'activa') != 'activa';
        _cargando = false;
      });
      if (widget.abrirCartaAlInicio && cartaItems.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mostrarCartaLocal(context);
        });
      }
      _cargarMegusta();
    } catch (e, st) {
      debugPrint('[LocalPerfil] _cargarDatos error: $e\n$st');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMegusta() async {
    final id = widget.idLocal?.trim();
    if (id == null || id.isEmpty || _bloqueado) return;
    final est = await ServicioLocalesMegusta.instancia.estado(id);
    if (!mounted) return;
    setState(() {
      _cantidadMegusta = est.cantidad;
      _yoMegusta = est.yoMegusta;
    });
  }

  Future<void> _onToggleMegusta() async {
    final id = widget.idLocal?.trim();
    if (id == null || id.isEmpty || _toggleMegusta || _bloqueado) return;
    if (ServicioSupabase().usuarioActual == null) return;
    setState(() => _toggleMegusta = true);
    try {
      final est = await ServicioLocalesMegusta.instancia.toggle(id);
      if (!mounted || est == null) return;
      setState(() {
        _cantidadMegusta = est.cantidad;
        _yoMegusta = est.yoMegusta;
      });
    } catch (e) {
      debugPrint('[LocalPerfil] toggle megusta: $e');
    } finally {
      if (mounted) setState(() => _toggleMegusta = false);
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

  Future<void> _abrirUbicacion(BuildContext context) async {
    // Si el local cargó url_maps, lo usamos directo (Google Maps / Maps app).
    if (_urlMaps != null && _urlMaps!.isNotEmpty) {
      final u = Uri.tryParse(_urlMaps!);
      if (u != null && await _lanzarExterno(u)) {
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
    await _lanzarExterno(url);
  }

  Future<void> _abrirUrl(String urlString) async {
    var normalizada = urlString.trim();
    if (normalizada.isEmpty) return;
    if (!normalizada.startsWith('http://') &&
        !normalizada.startsWith('https://')) {
      normalizada = 'https://$normalizada';
    }
    final url = Uri.tryParse(normalizada);
    if (url == null) {
      _mostrarAvisoLink('El enlace no es válido.');
      return;
    }
    final ok = await _lanzarExterno(url);
    if (!ok && mounted) _mostrarAvisoLink('No pudimos abrir el enlace.');
  }

  Future<void> _abrirWhatsappLocal() async {
    final telefono = (_telefonoWhatsapp ?? '').replaceAll(RegExp(r'\D'), '');
    if (telefono.length < 10) return;
    final mensaje =
        'Hola! Vengo desde Fernecito App y quería consultar por ${widget.nombreLocal}.';
    final url = Uri.parse(
      'https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}',
    );
    final ok = await _lanzarExterno(url);
    if (!ok && mounted) _mostrarAvisoLink('No pudimos abrir WhatsApp.');
  }

  Future<bool> _lanzarExterno(Uri url) async {
    return lanzarExternoConFallback(url);
  }

  void _mostrarAvisoLink(String mensaje) {
    if (!mounted) return;
    showFernecitoDialog<void>(
      context: context,
      builder: (ctx) => DialogoFernecito(
        title: const Text('No se pudo abrir'),
        content: Text(mensaje),
        actions: [
          AccionDialogoFernecito(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _labelWhatsappPublico() {
    final label = _whatsappLabel?.trim() ?? '';
    return label.isEmpty ? 'Consultar por WhatsApp' : label;
  }

  void _mostrarCartaLocal(BuildContext context) {
    _mostrarCartaLocalSheet(
      context: context,
      nombreLocal: widget.nombreLocal,
      items: _cartaItems,
    );
  }

  /// Menú "3 puntitos" del local. Por ahora solo Reportar (oculto a la vista).
  void _abrirMenuLocal() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _reportarLocal();
            },
            child: const Text('Reportar local'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _bloquearLocal();
            },
            child: const Text('Bloquear local'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _compartirLocal() async {
    final nombre = widget.nombreLocal.trim().isEmpty
        ? 'este local'
        : widget.nombreLocal.trim();
    final base = kAuthRedirectWebProduccion.replaceAll(RegExp(r'/$'), '');
    await SharePlus.instance.share(
      ShareParams(
        text: 'Mirá $nombre en Fernecito 🍸\n$base',
      ),
    );
  }

  Future<void> _reportarLocal() async {
    final id = widget.idLocal;
    if (id == null || id.isEmpty) return;
    await mostrarFlujoReporte(
      context: context,
      entidad: 'este local',
      targetTipo: 'local',
      targetId: id,
    );
  }

  Future<void> _bloquearLocal() async {
    final id = widget.idLocal;
    if (id == null || id.isEmpty) return;
    final bloqueado = await mostrarFlujoBloqueo(
      context: context,
      entidad: 'este local',
      targetTipo: 'local',
      targetId: id,
    );
    // Al bloquear, volvemos atrás: ya no deberías ver este local.
    if (bloqueado && mounted) Navigator.of(context).maybePop();
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
                    child: Icon(
                      CupertinoIcons.back,
                      color: ColoresApp.principalMarca,
                    ),
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
                        AvatarLocal(
                          imageUrl: widget.avatarUrl,
                          size: 112,
                          placeholderIcon: CupertinoIcons.building_2_fill,
                        ),
                        const SizedBox(height: 14),
                        _NombreLocalPerfilHero(
                          nombre: nombre,
                          maxWidth: MediaQuery.sizeOf(context).width - 56,
                          fontSize: 20,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: ColoresApp.fondoSuperficie.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(18),
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

  /// Fondo sólido del banner mientras carga o si falla.
  Widget _fondoBannerReserva() =>
      const ColoredBox(color: ColoresApp.fondoPrincipal);

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching data
    if (_cargando) {
      return CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: FondoGradienteFernecito(
          corto: true,
          child: const FernecitoLoaderCentro(size: 36),
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
    // ~15% más alto que el hero base (0.43) para evitar overflow en iPhone.
    final bannerHeight = (screenHeight * 0.4945).clamp(368.0, 529.0).toDouble();

    final padding = MediaQuery.of(context).padding;
    // Responsive: pantallas estrechas reducen tamaños para evitar overflow
    final isNarrow = screenWidth < 400;
    final avatarSize = (isNarrow ? 72.0 : 100.0) * 1.15;
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
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.55, 0.85, 1.0],
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.65),
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _avatarUrlEsAsset(bannerSource)
                                ? Image.asset(
                                    bannerSource,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _fondoBannerReserva(),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: bannerSource,
                                    fit: BoxFit.cover,
                                    fadeInDuration: const Duration(
                                      milliseconds: 220,
                                    ),
                                    placeholder: (_, __) =>
                                        _fondoBannerReserva(),
                                    errorWidget: (_, __, ___) =>
                                        _fondoBannerReserva(),
                                  ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.58),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Contenido: avatar, nombre, puntuación, iconos (sin scroll interno)
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          padding.top + 14,
                          horizontalPadding,
                          8,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvatarLocal(
                                imageUrl: _avatarEffective,
                                size: avatarSize,
                                esPionero: _esPionero,
                                placeholderIcon: CupertinoIcons.building_2_fill,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              _NombreLocalPerfilHero(
                                nombre: nombreLocal.trim().isNotEmpty
                                    ? nombreLocal.trim()
                                    : 'Local',
                                maxWidth: screenWidth - horizontalPadding * 2,
                                fontSize: isNarrow ? 21 : 26,
                                isNarrow: isNarrow,
                                insignia: (_verificado || _esPionero)
                                    ? Icon(
                                        CupertinoIcons.checkmark_seal_fill,
                                        size: isNarrow ? 20 : 24,
                                        color: _esPionero
                                            ? const Color(0xFFE0B800)
                                            : ColoresApp.principalMarca,
                                      )
                                    : null,
                              ),
                              if (_mostrarCalificaciones)
                                const SizedBox(height: 7),
                              if (_mostrarCalificaciones)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: _calificacionPromedio == null
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const _EstrellasRating(
                                                valor: null,
                                                size: 16,
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                'Sin calificaciones aún',
                                                style: GoogleFonts.baloo2(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: ColoresApp
                                                      .textoSecundario,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _calificacionPromedio!
                                                    .toStringAsFixed(1),
                                                style: GoogleFonts.baloo2(
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.w900,
                                                  height: 0.95,
                                                  letterSpacing: -0.5,
                                                  color:
                                                      ColoresApp.textoPrincipal,
                                                ),
                                              ),
                                              _EstrellasRating(
                                                valor: _calificacionPromedio,
                                                size: 15,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$_calificacionCantidad ${_calificacionCantidad == 1 ? 'calificación' : 'calificaciones'}',
                                                style: GoogleFonts.baloo2(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: ColoresApp
                                                      .textoSecundario,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              SizedBox(height: isNarrow ? 13 : 16),
                              // Fila de iconos modernos sin contenedor (solo glow)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 4 : 8,
                                ),
                                child: Builder(
                                  builder: (_) {
                                    final sz = isNarrow ? 24.0 : 28.0;
                                    final sep = SizedBox(
                                      width: isNarrow ? 20 : 25,
                                    );
                                    final igOk =
                                        _instagramUrl != null &&
                                        _instagramUrl!.isNotEmpty;
                                    final ttOk =
                                        _tiktokUrl != null &&
                                        _tiktokUrl!.isNotEmpty;
                                    final webOk =
                                        _sitioWebUrl != null &&
                                        _sitioWebUrl!.isNotEmpty;
                                    final ubiOk =
                                        _ubicacionTextoComputed.isNotEmpty ||
                                        (_direccion ?? '').isNotEmpty ||
                                        (_urlMaps ?? '').isNotEmpty;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _IconoEnlace(
                                          icon: CupertinoIcons.location_solid,
                                          activo: ubiOk,
                                          onTap: ubiOk
                                              ? () => _abrirUbicacion(context)
                                              : null,
                                          size: sz,
                                        ),
                                        sep,
                                        _IconoEnlace(
                                          icon: FontAwesomeIcons.instagram,
                                          useFontAwesome: true,
                                          activo: igOk,
                                          onTap: igOk
                                              ? () => _abrirUrl(_instagramUrl!)
                                              : null,
                                          size: sz,
                                        ),
                                        sep,
                                        _IconoEnlace(
                                          icon: FontAwesomeIcons.tiktok,
                                          useFontAwesome: true,
                                          activo: ttOk,
                                          onTap: ttOk
                                              ? () => _abrirUrl(_tiktokUrl!)
                                              : null,
                                          size: sz,
                                        ),
                                        sep,
                                        _IconoEnlace(
                                          icon: CupertinoIcons.globe,
                                          activo: webOk,
                                          onTap: webOk
                                              ? () => _abrirUrl(_sitioWebUrl!)
                                              : null,
                                          size: sz,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: padding.top + 6,
                      right: horizontalPadding - 4,
                      child: Column(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(0, 36),
                            onPressed: _abrirMenuLocal,
                            child: Icon(
                              CupertinoIcons.ellipsis,
                              size: 22,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(0, 36),
                            onPressed: _compartirLocal,
                            child: Icon(
                              Icons.share_rounded,
                              size: 20,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.idLocal != null &&
                        widget.idLocal!.isNotEmpty &&
                        !_bloqueado)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: BotonMegustaLocalHero(
                            cantidad: _cantidadMegusta,
                            activo: _yoMegusta,
                            habilitado:
                                ServicioSupabase().usuarioActual != null,
                            cargando: _toggleMegusta,
                            onTap: _onToggleMegusta,
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
                  6,
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
                            if (_esPionero) ...[
                              _BadgeBestChoicePerfil(),
                              const SizedBox(height: 12),
                            ],
                            if (_descripcion != null &&
                                _descripcion!.trim().isNotEmpty)
                              _DescripcionLocalConFade(
                                texto: _descripcion!,
                                expandida: _descripcionExpandida,
                                onToggle: () => setState(
                                  () => _descripcionExpandida =
                                      !_descripcionExpandida,
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
                            if ((_telefonoWhatsapp ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 9),
                              _BotonWhatsappPublicoLocal(
                                label: _labelWhatsappPublico(),
                                onTap: _abrirWhatsappLocal,
                              ),
                            ],
                            _FilaCartaYHorarios(
                              estadoHorario: estadoHorarioLocal(_horarios),
                              horarios: _horarios,
                              cantidadCarta: _cartaItems.length,
                              onVerCarta: _cartaItems.isEmpty
                                  ? null
                                  : () => _mostrarCartaLocal(context),
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
                                        child: FernecitoLoader.inline(size: 16),
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
                                                child: FernecitoLoader.inline(
                                                  size: 16,
                                                ),
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
                      for (final loc in _lugaresPopulares.take(6))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CardLugarPopular(
                            idLocal: loc['id'] as String? ?? '',
                            nombre: loc['nombre'] as String? ?? 'Local',
                            avatar: loc['avatar'] as String? ?? '',
                            verificado: loc['verificado'] == true,
                            esPionero: loc['esPionero'] == true,
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

/// Fila de 5 estrellas pintadas según el promedio (con medias estrellas).
/// `valor` null => todas vacías (sin calificaciones).
class _EstrellasRating extends StatelessWidget {
  final double? valor;
  final double size;
  const _EstrellasRating({required this.valor, this.size = 15});

  @override
  Widget build(BuildContext context) {
    const dorado = Color(0xFFFFC107);
    final apagado = ColoresApp.textoSecundario.withValues(alpha: 0.45);
    final v = valor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final pos = i + 1;
        IconData icono;
        Color color;
        if (v == null || v < pos - 0.5) {
          icono = CupertinoIcons.star;
          color = apagado;
        } else if (v >= pos) {
          icono = CupertinoIcons.star_fill;
          color = dorado;
        } else {
          icono = CupertinoIcons.star_lefthalf_fill;
          color = dorado;
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.07),
          child: Icon(icono, size: size, color: color),
        );
      }),
    );
  }
}

/// Icono moderno sin contenedor, con glow sutil. Reemplaza el botón circular antiguo.
/// Se usa para ubicación, Instagram, TikTok, sitio web en el banner del local.
class _IconoEnlace extends StatefulWidget {
  final IconData icon;
  final bool useFontAwesome;
  final VoidCallback? onTap;
  final double size;
  final bool activo;

  const _IconoEnlace({
    required this.icon,
    this.onTap,
    this.useFontAwesome = false,
    this.size = 28,
    this.activo = true,
  });

  @override
  State<_IconoEnlace> createState() => _IconoEnlaceState();
}

class _IconoEnlaceState extends State<_IconoEnlace> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Desactivado (el local no cargó este enlace): icono apagado, sin glow ni tap.
    if (!widget.activo) {
      return Opacity(
        opacity: 0.25,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: widget.useFontAwesome
              ? FaIcon(widget.icon, size: widget.size, color: Colors.white)
              : Icon(widget.icon, size: widget.size, color: Colors.white),
        ),
      );
    }
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
  final bool esPionero;
  final String rubro;
  final String ciudad;

  const _CardLugarPopular({
    required this.idLocal,
    required this.nombre,
    required this.avatar,
    required this.verificado,
    required this.esPionero,
    required this.rubro,
    required this.ciudad,
  });

  static const _doradoPionero = Color(0xFFE0B800);

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
          AvatarLocal(imageUrl: avatar, size: 48, esPionero: esPionero),
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
                          color: esPionero
                              ? _doradoPionero
                              : ColoresApp.principalMarca,
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
                              child: FernecitoLoader.inline(size: 16),
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

/// Badge compacto Best Choice — primer ítem dentro de Info del lugar.
class _BadgeBestChoicePerfil extends StatelessWidget {
  static const _dorado = Color(0xFFE0B800);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _dorado.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.star_fill, size: 12, color: _dorado),
          const SizedBox(width: 5),
          Text(
            'Best Choice',
            style: GoogleFonts.baloo2(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _dorado,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonWhatsappPublicoLocal extends StatelessWidget {
  const _BotonWhatsappPublicoLocal({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF25D366);
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FontAwesomeIcons.whatsapp, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaCartaYHorarios extends StatelessWidget {
  const _FilaCartaYHorarios({
    required this.estadoHorario,
    required this.horarios,
    required this.cantidadCarta,
    this.onVerCarta,
  });

  final EstadoHorarioLocal estadoHorario;
  final HorariosLocal horarios;
  final int cantidadCarta;
  final VoidCallback? onVerCarta;

  @override
  Widget build(BuildContext context) {
    final mostrarHorario = estadoHorario.tieneHorarios;
    final mostrarCarta = onVerCarta != null && cantidadCarta > 0;
    if (!mostrarHorario && !mostrarCarta) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (mostrarCarta)
            Expanded(
              child: _BotonVerCartaLocal(
                cantidad: cantidadCarta,
                onTap: onVerCarta!,
              ),
            ),
          if (mostrarCarta && mostrarHorario) const SizedBox(width: 8),
          if (mostrarHorario)
            Expanded(
              child: _BadgeEstadoHorarioPublico(
                estado: estadoHorario,
                horarios: horarios,
                compactoFila: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonVerCartaLocal extends StatelessWidget {
  const _BotonVerCartaLocal({required this.cantidad, required this.onTap});

  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1E),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.list_bullet,
                    size: 14,
                    color: Color(0xFFFFD166),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ver carta',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFD166),
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                cantidad == 1 ? '1 item' : '$cantidad items',
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFD166).withValues(alpha: 0.75),
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _mostrarCartaLocalSheet({
  required BuildContext context,
  required String nombreLocal,
  required List<_CartaLocalItem> items,
}) {
  if (items.isEmpty) return;
  final grupos = <String, List<_CartaLocalItem>>{};
  for (final item in items) {
    final key = item.categoria.trim().isEmpty ? 'Otros' : item.categoria.trim();
    grupos.putIfAbsent(key, () => <_CartaLocalItem>[]).add(item);
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                bottom: media.viewPadding.bottom > 0 ? 8 : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFD166,
                          ).withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.list_bullet,
                          size: 17,
                          color: Color(0xFFFFD166),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carta de $nombreLocal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.baloo2(
                                color: ColoresApp.textoPrincipal,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                            Text(
                              'Precios orientativos cargados por el local',
                              style: GoogleFonts.baloo2(
                                color: ColoresApp.textoSecundario,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final entry in grupos.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 7),
                      child: Text(
                        entry.key,
                        style: GoogleFonts.baloo2(
                          color: const Color(0xFFFFD166),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    for (final item in entry.value)
                      _CartaLocalItemTile(item: item),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CartaLocalItemTile extends StatelessWidget {
  const _CartaLocalItemTile({required this.item});

  final _CartaLocalItem item;

  String _precio() {
    final precio = item.precio;
    if (precio == null) return 'Consultar';
    final p = precio.round().toString();
    if (item.tipoPrecio == 'desde') return 'Desde \$$p';
    if (item.tipoPrecio == 'rango' && item.precioHasta != null) {
      return '\$$p - \$${item.precioHasta!.round()}';
    }
    if (item.tipoPrecio == 'aproximado') return '~\$$p';
    return '\$$p';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF202024),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          color: ColoresApp.textoPrincipal,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                    if (item.destacado) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        CupertinoIcons.star_fill,
                        size: 12,
                        color: Color(0xFFFFD166),
                      ),
                    ],
                  ],
                ),
                if (item.descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                      fontSize: 12,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _precio(),
            style: GoogleFonts.baloo2(
              color: const Color(0xFFFFD166),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeEstadoHorarioPublico extends StatelessWidget {
  const _BadgeEstadoHorarioPublico({
    required this.estado,
    required this.horarios,
    this.compactoFila = false,
  });

  final EstadoHorarioLocal estado;
  final HorariosLocal horarios;
  final bool compactoFila;

  @override
  Widget build(BuildContext context) {
    if (!estado.tieneHorarios) return const SizedBox.shrink();
    final color = estado.abierto
        ? const Color(0xFF27D66D)
        : ColoresApp.textoSecundario;
    return Padding(
      padding: EdgeInsets.only(top: compactoFila ? 0 : 12),
      child: GestureDetector(
        onTap: () => _mostrarHorariosPublicos(context, horarios),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1E),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.clock_fill, size: 14, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        estado.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: estado.abierto
                              ? color
                              : ColoresApp.textoPrincipal,
                          height: 1.05,
                        ),
                      ),
                      Text(
                        estado.detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textoSecundario,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 12,
                  color: ColoresApp.textoSecundario,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static void _mostrarHorariosPublicos(
    BuildContext context,
    HorariosLocal horarios,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) {
        final estado = estadoHorarioLocal(horarios);
        final media = MediaQuery.of(ctx);
        final maxHeight = media.size.height * 0.82;

        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: media.viewPadding.bottom > 0 ? 8 : 0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color:
                                (estado.abierto
                                        ? const Color(0xFF27D66D)
                                        : ColoresApp.textoSecundario)
                                    .withValues(alpha: 0.13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.clock_fill,
                            size: 17,
                            color: estado.abierto
                                ? const Color(0xFF27D66D)
                                : ColoresApp.textoSecundario,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                estado.titulo,
                                style: GoogleFonts.baloo2(
                                  color: ColoresApp.textoPrincipal,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              Text(
                                estado.detalle,
                                style: GoogleFonts.baloo2(
                                  color: ColoresApp.textoSecundario,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(CupertinoIcons.xmark),
                          color: ColoresApp.textoSecundario,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var dia = 0; dia < 7; dia++) ...[
                      _FilaHorarioPublica(
                        dia: nombresDiasHorarios[dia],
                        texto: resumenHorariosDia(horarios[dia] ?? const []),
                        destacado: dia == DateTime.now().weekday - 1,
                      ),
                      if (dia != 6) const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilaHorarioPublica extends StatelessWidget {
  const _FilaHorarioPublica({
    required this.dia,
    required this.texto,
    required this.destacado,
  });

  final String dia;
  final String texto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: destacado
            ? ColoresApp.principalMarca.withValues(alpha: 0.13)
            : const Color(0xFF202024),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              dia,
              style: GoogleFonts.baloo2(
                color: destacado
                    ? ColoresApp.principalMarca
                    : ColoresApp.textoSecundario,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              textAlign: TextAlign.right,
              style: GoogleFonts.baloo2(
                color: ColoresApp.textoPrincipal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DescripcionLocalConFade extends StatelessWidget {
  const _DescripcionLocalConFade({
    required this.texto,
    required this.expandida,
    required this.onToggle,
  });

  final String texto;
  final bool expandida;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const maxLines = 6;
    final style = GoogleFonts.baloo2(
      fontSize: 14,
      height: 1.4,
      color: ColoresApp.textoPrincipal.withValues(alpha: 0.95),
    );
    final necesitaVerMas = texto.trim().length > 210;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Text(
              texto,
              maxLines: expandida ? null : maxLines,
              overflow: expandida ? TextOverflow.visible : TextOverflow.clip,
              style: style,
            ),
            if (!expandida && necesitaVerMas)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 34,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00101010), Color(0xFF101010)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (necesitaVerMas) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expandida ? 'Ver menos' : 'Ver más',
              style: GoogleFonts.baloo2(
                color: ColoresApp.principalMarca,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Nombre del local en hero: salto temprano + insignia inline al final.
class _NombreLocalPerfilHero extends StatelessWidget {
  const _NombreLocalPerfilHero({
    required this.nombre,
    required this.maxWidth,
    required this.fontSize,
    this.isNarrow = false,
    this.insignia,
  });

  final String nombre;
  final double maxWidth;
  final double fontSize;
  final bool isNarrow;
  final Widget? insignia;

  static const double _espacioInsignia = 8;

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: ColoresApp.textoPrincipal,
      height: 1.2,
    );
    final textDirection = Directionality.of(context);
    final reservaTrailing = FormatoNombreLocalHero.reservaTrailingInsignia(
      tieneInsignia: insignia != null,
      fontSize: fontSize,
      isNarrow: isNarrow,
    );
    final nombreMostrado = FormatoNombreLocalHero.paraDisplay(
      nombre: nombre,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textDirection: textDirection,
      reservaTrailing: reservaTrailing,
    );

    final trailing = <InlineSpan>[
      if (insignia != null)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: _espacioInsignia),
            child: insignia!,
          ),
        ),
    ];

    return SizedBox(
      width: maxWidth,
      child: Text.rich(
        TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: nombreMostrado),
            ...trailing,
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
