import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, FunctionException;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../widgets/boton_compartir_evento.dart';
import 'pantalla_actividad.dart';
import 'pantalla_local_perfil.dart';
import 'pantalla_pools.dart';

/// Logo de local por defecto (assets/mockups/perfiles_local).
const String _logoLocalDefault =
    'assets/imagenes/mockups/perfiles_local/Cuatro-Catorce---Blanco.png';

bool _avatarUrlEsAsset(String url) => url.startsWith('assets/');

/// Misma lista que en pantalla_home para que el flyer sea el mismo que en la cartelera.
const List<String> _flyersMockup = [
  'assets/imagenes/mockups/Screenshot_20260202_013949_Instagram.jpg',
  'assets/imagenes/mockups/Screenshot_20260202_014218_Instagram.jpg',
  'assets/imagenes/mockups/Screenshot_20260202_014730_Instagram.jpg',
  'assets/imagenes/mockups/Screenshot_20260202_015122_Instagram.jpg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 03.00.33.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.09 (1).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.09 (2).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.09 (3).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.09.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.10 (1).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.10.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.11.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.06.48.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-02 at 23.07.37.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.43.57.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.00.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.01.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.03 (1).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.03 (2).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.03.jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.04 (1).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.04 (2).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.04 (3).jpeg',
  'assets/imagenes/mockups/WhatsApp Image 2026-02-06 at 16.44.04.jpeg',
];

class PantallaVerEvento extends StatefulWidget {
  final Map<String, dynamic> evento;

  /// Si viene de un QR de invitación de RRPP, este es el id_invitacion opaco.
  /// Cuando está presente, "Reservar" entra DIRECTO como aceptada (vía edge
  /// invitacion_rrpp) en vez de pasar por el flujo normal de solicitar_asistencia.
  final String? idInvitacionRrpp;

  const PantallaVerEvento({
    super.key,
    required this.evento,
    this.idInvitacionRrpp,
  });

  @override
  State<PantallaVerEvento> createState() => _PantallaVerEventoState();
}

class _PantallaVerEventoState extends State<PantallaVerEvento> {
  List<Map<String, dynamic>> _squadsUsuario = [];
  bool _enviandoReserva = false;
  List<Map<String, dynamic>> _promos = [];
  Map<String, dynamic>? _miToken;
  Map<String, dynamic>? _infoLocal;
  String? _localAvatarResuelto;
  double? _calificacionPromedio;
  int? _calificacionCantidad;
  bool _localVerificado = false;
  bool _localEsPionero = false;
  String? _ubicacionLocal;
  bool _eventoOcultoPorModeracion = false;
  // _eventosOpciones removido: ahora vive en _CarruselMasEventos (widget independiente).

  // Campos extra del evento traídos vía query directa (no vienen en el Map de cartelera)
  int? _edadMinima;
  String? _advertenciasEvento;
  String? _urlCompraEntradas;
  String? _tipoEventoCargado;
  bool _tienePromoCargado = false;

  /// Modo del evento: 'simple' = vidriera informativa (sin reservas ni promos).
  String? _modoEventoCargado;
  bool get _esEventoSimple => _modoEventoCargado == 'simple';

  /// Cupos desde tabla `eventos` (sobreescribe lo que venga del mapa de navegación).
  int? _cuposLibresServidor;
  bool? _cupoLimitadoServidor;

  StreamSubscription? _authSub;

  /// Id del evento alineado con `eventos.id_evento` / tokens (`id` o `id_evento` en el mapa).
  String _idEventoClave() {
    final m = widget.evento;
    final a = m['id']?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    return m['id_evento']?.toString().trim() ?? '';
  }

  bool get _esModoInvitacion =>
      widget.idInvitacionRrpp != null && widget.idInvitacionRrpp!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _authSub = ServicioSupabase().cliente.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      switch (data.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userUpdated:
          _cargarDatos();
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    try {
      final sb = ServicioSupabase().cliente;
      // Refresh de sesión por las dudas (si el JWT está por expirar, lo renueva)
      try {
        final session = sb.auth.currentSession;
        if (session != null && session.isExpired) {
          debugPrint('🔄 Sesión expirada, refrescando…');
          await sb.auth.refreshSession();
        }
      } catch (e) {
        debugPrint('⚠️ Error refrescando sesión: $e');
      }
      final userId = sb.auth.currentUser?.id;
      final session = sb.auth.currentSession;
      final eventoId = _idEventoClave();
      var idLocal = widget.evento['idLocal']?.toString();
      _eventoOcultoPorModeracion = false;
      debugPrint(
        '🔍 pantalla_ver_evento _cargarDatos:'
        ' eventoId=$eventoId idLocal=$idLocal userId=$userId'
        ' sessionValid=${session != null && !session.isExpired}',
      );

      // 0. Cargar campos extra del evento (incluye `tiene_promo` para saber si el local
      //    marcó que el evento tiene promo, aunque la consulta a `promociones` falle).
      if (eventoId.isNotEmpty) {
        try {
          final extra = await sb
              .from('eventos')
              .select('*')
              .eq('id_evento', eventoId)
              .maybeSingle();
          if (extra != null) {
            final idLocalExtra = extra['id_local']?.toString().trim() ?? '';
            if ((idLocal == null || idLocal.isEmpty) &&
                idLocalExtra.isNotEmpty) {
              idLocal = idLocalExtra;
            }
            final emRaw = extra['edad_minima'];
            _edadMinima = emRaw is int
                ? emRaw
                : (emRaw != null ? int.tryParse(emRaw.toString()) : null);
            final adv = extra['advertencias_evento']?.toString();
            _advertenciasEvento = (adv != null && adv.trim().isNotEmpty)
                ? adv.trim()
                : null;
            final url = extra['url_compra_entradas']?.toString();
            _urlCompraEntradas = (url != null && url.trim().isNotEmpty)
                ? url.trim()
                : null;
            final tipo = extra['tipo_evento']?.toString();
            _tipoEventoCargado = (tipo != null && tipo.trim().isNotEmpty)
                ? tipo.trim()
                : null;
            _tienePromoCargado = extra['tiene_promo'] == true;
            final modo = extra['modo_evento']?.toString();
            _modoEventoCargado = (modo != null && modo.trim().isNotEmpty)
                ? modo.trim()
                : null;
            final rawMax = extra['cupo_lista_max'];
            final maxParsed = rawMax is int
                ? rawMax
                : (rawMax != null ? int.tryParse(rawMax.toString()) : null);
            final rawUsados = extra['cupo_lista_usados'];
            final usadosParsed = rawUsados is int
                ? rawUsados
                : int.tryParse(rawUsados?.toString() ?? '') ?? 0;
            if (maxParsed != null) {
              _cuposLibresServidor = maxParsed - usadosParsed;
              _cupoLimitadoServidor = true;
            } else {
              _cuposLibresServidor = null;
              _cupoLimitadoServidor = null;
            }
            debugPrint(
              '🎯 evento extra: tiene_promo=$_tienePromoCargado'
              ' edad_minima=$_edadMinima tipo=$_tipoEventoCargado'
              ' advert="${_advertenciasEvento ?? ""}" url_entradas=${_urlCompraEntradas != null}'
              ' cupos_libres=$_cuposLibresServidor',
            );
          } else {
            debugPrint(
              '⚠️ No se encontró el evento $eventoId en tabla eventos',
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error cargando campos extra evento: $e');
        }
      } else {
        debugPrint('⚠️ eventoId vacío — no se puede consultar Supabase');
      }

      if (idLocal != null && idLocal.isNotEmpty) {
        final localEstado = await sb
            .from('perfiles_locales')
            .select('estado_cuenta')
            .eq('id', idLocal)
            .maybeSingle();
        final estadoCuenta =
            localEstado?['estado_cuenta']?.toString() ?? 'activa';
        if (estadoCuenta != 'activa') {
          _eventoOcultoPorModeracion = true;
          _promos = [];
          _miToken = null;
          _squadsUsuario = [];
          return;
        }
      }

      // 1. Squads donde soy miembro aceptado (RPC squad_listar_mios).
      try {
        final mios = await ServicioSquads().misSquads();
        _squadsUsuario = mios
            .map((s) => {'id_squad': s.idGrupo, 'nombre_squad': s.nombre})
            .toList();
      } catch (e) {
        debugPrint('⚠️ Error cargando squads (squad_listar_mios): $e');
        _squadsUsuario = [];
      }

      // 2. Cargar promos del evento. Estrategia:
      //    - Primero hago una query global de diagnóstico (cuántas promos visibles).
      //    - Luego query específica del evento.
      //    - Logueo cada paso para diagnóstico.
      if (eventoId.isNotEmpty) {
        // 2a. Diagnóstico: count global. Si el user es authenticated y la RLS funciona,
        //     debería ver >0 promos en total. Si ve 0, hay problema de auth/RLS.
        try {
          final allPromos = await sb
              .from('promociones')
              .select('id_evento, estado_promocion');
          final allList = List<Map<String, dynamic>>.from(allPromos as List);
          final eventosUnicos = allList
              .map((p) => p['id_evento']?.toString())
              .toSet();
          debugPrint(
            '🔬 Diagnóstico global: ${allList.length} promos visibles'
            ' en ${eventosUnicos.length} eventos distintos',
          );
          if (allList.isEmpty) {
            debugPrint(
              '🚨 ATENCIÓN: el user NO ve NINGUNA promo. Probable problema'
              ' de auth/RLS. Verificar sesión.',
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error en diagnóstico global de promos: $e');
        }

        // 2b. Query específica del evento
        try {
          final promosRes = await sb
              .from('promociones')
              .select('*')
              .eq('id_evento', eventoId);
          final lista = List<Map<String, dynamic>>.from(promosRes as List);
          debugPrint(
            '🎁 Promociones encontradas para evento $eventoId: ${lista.length}'
            ' (estados: ${lista.map((p) => p["estado_promocion"]).toList()})',
          );
          // Filtrar solo activas para mostrar al usuario
          _promos = lista
              .where(
                (p) =>
                    (p['estado_promocion']?.toString().toLowerCase() ??
                        'activa') ==
                    'activa',
              )
              .toList();
          debugPrint('🎁 Promos activas finales: ${_promos.length}');
        } catch (e, st) {
          debugPrint('⚠️ Error cargando promos del evento $eventoId: $e\n$st');
          _promos = [];
        }
      } else {
        _promos = [];
      }

      // 3. Token de lista para este evento (orden reciente; limit 1 evita fallo por duplicados)
      _miToken = null;
      if (userId != null && eventoId.isNotEmpty) {
        try {
          final tokenRows = await sb
              .from('tokens_asistencia')
              .select('id_token, codigo_puerta, estado_token')
              .eq('id_evento', eventoId)
              .eq('id_usuario', userId)
              .order('fecha_creacion', ascending: false)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(tokenRows as List);
          _miToken = list.isEmpty
              ? null
              : Map<String, dynamic>.from(list.first);
          debugPrint(
            '🎫 tokens_asistencia evento=$eventoId → '
            '${_miToken != null ? _miToken!['estado_token'] : 'sin fila'} (rows=${list.length})',
          );
        } catch (e, st) {
          debugPrint('⚠️ Error cargando token asistencia: $e\n$st');
          _miToken = null;
        }
      } else {
        debugPrint(
          '🎫 sin consulta token: userId=${userId != null} eventoIdEmpty=${eventoId.isEmpty}',
        );
      }

      // 4. Cargar info real del local desde Supabase (incluye verificación + rating)
      if (idLocal != null && idLocal.isNotEmpty) {
        try {
          final localRes = await sb
              .from('perfiles_locales')
              .select(
                'id, nombre_local, foto_perfil_url, local_verificado, plan_suscripcion, calificacion_promedio, calificacion_cantidad, ciudad, provincia, descripcion_local',
              )
              .eq('id', idLocal)
              .maybeSingle();
          if (localRes != null) {
            _infoLocal = Map<String, dynamic>.from(localRes);
            final path = _infoLocal!['foto_perfil_url']?.toString() ?? '';
            _localAvatarResuelto = path.isEmpty || path.startsWith('http')
                ? path
                : sb.storage.from('avatars_locales').getPublicUrl(path);
            final cal = _infoLocal!['calificacion_promedio'];
            _calificacionPromedio = cal != null
                ? (cal as num).toDouble()
                : null;
            final ccant = _infoLocal!['calificacion_cantidad'];
            _calificacionCantidad = ccant is int
                ? ccant
                : (ccant != null ? int.tryParse(ccant.toString()) : null);
            _localVerificado = _infoLocal!['local_verificado'] == true;
            _localEsPionero =
                (_infoLocal!['plan_suscripcion']?.toString() ?? '')
                    .toLowerCase()
                    .contains('pionero');
            final ciudad = _infoLocal!['ciudad']?.toString();
            final provincia = _infoLocal!['provincia']?.toString();
            if (ciudad != null && ciudad.isNotEmpty) {
              _ubicacionLocal = provincia != null && provincia.isNotEmpty
                  ? '$ciudad, $provincia'
                  : ciudad;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error cargando local: $e');
          // Fallback minimal sin columnas opcionales
          try {
            final localRes = await sb
                .from('perfiles_locales')
                .select('id, nombre_local, foto_perfil_url, local_verificado')
                .eq('id', idLocal)
                .maybeSingle();
            if (localRes != null) {
              _infoLocal = Map<String, dynamic>.from(localRes);
              final path = _infoLocal!['foto_perfil_url']?.toString() ?? '';
              _localAvatarResuelto = path.isEmpty || path.startsWith('http')
                  ? path
                  : sb.storage.from('avatars_locales').getPublicUrl(path);
              _localVerificado = _infoLocal!['local_verificado'] == true;
            }
          } catch (_) {
            /* silently ignore */
          }
        }
      }

      // 5. "Más eventos para vos" se carga en su propio widget (_CarruselMasEventos).
    } catch (e) {
      // silently ignore load errors, keep whatever data we have
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// Flyer de fallback por evento usando mockups.
  String _flyerAssetParaEvento(Map<String, dynamic> e) {
    final yaAsignado = e['flyerAsset'];
    if (yaAsignado is String && yaAsignado.isNotEmpty) return yaAsignado;
    final i = e.hashCode.abs() % _flyersMockup.length;
    return _flyersMockup[i];
  }

  /// Parsea ISO a DateTime local. Devuelve null si vacío o inválido.
  DateTime? _parseFecha(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Mapa de evento para la tarjeta de reserva: cupos frescos desde servidor si existen.
  Map<String, dynamic> _eventoParaTarjetaReserva() {
    final m = Map<String, dynamic>.from(widget.evento);
    if (_cuposLibresServidor != null) {
      m['cuposLibres'] = _cuposLibresServidor;
      m['cupoLimitado'] = _cupoLimitadoServidor == true;
    }
    return m;
  }

  /// Normaliza el cuerpo de error de una Edge (Map o JSON en string).
  Map<String, dynamic>? _detallesEdge(dynamic details) {
    if (details == null) return null;
    if (details is Map) return Map<String, dynamic>.from(details);
    if (details is String && details.trim().isNotEmpty) {
      try {
        final d = jsonDecode(details);
        if (d is Map) return Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    return null;
  }

  bool _reservaActivaDesdeToken(Map<String, dynamic>? token) {
    if (token == null) return false;
    final est = token['estado_token']?.toString();
    return est != 'rechazada' && est != 'cancelada';
  }

  Future<Map<String, dynamic>?> _fetchTokenAsistenciaActual() async {
    final sb = ServicioSupabase().cliente;
    final userId = sb.auth.currentUser?.id;
    final eventoId = _idEventoClave();
    if (userId == null || eventoId.isEmpty) return null;
    try {
      final tokenRows = await sb
          .from('tokens_asistencia')
          .select('id_token, codigo_puerta, estado_token')
          .eq('id_evento', eventoId)
          .eq('id_usuario', userId)
          .order('fecha_creacion', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(tokenRows as List);
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list.first);
    } catch (e) {
      debugPrint('⚠️ _fetchTokenAsistenciaActual: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_eventoOcultoPorModeracion) {
      return _buildEventoNoDisponible(context);
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxFlyerHeight = screenHeight * 0.70;
    final flyerUrl = widget.evento['flyer']?.toString() ?? '';
    final flyerAsset = _flyerAssetParaEvento(widget.evento);
    // Preferir datos reales del local (cargados desde Supabase); caer en los del evento si no hay
    final localAvatarRaw = _localAvatarResuelto?.isNotEmpty == true
        ? _localAvatarResuelto!
        : (widget.evento['avatarLocal']?.toString() ?? '');
    final localAvatar = localAvatarRaw.isNotEmpty
        ? localAvatarRaw
        : _logoLocalDefault;
    final localNombre =
        (_infoLocal?['nombre_local']?.toString().isNotEmpty == true
            ? _infoLocal!['nombre_local'].toString()
            : widget.evento['nombreLocal']?.toString()) ??
        'Local';
    final calificacion = _calificacionPromedio;
    final ubicacion = _ubicacionLocal;
    final fechaInicioDT = _parseFecha(widget.evento['fechaInicio']?.toString());
    final eventoParaTarjeta = _eventoParaTarjetaReserva();
    final idEvActual = _idEventoClave();

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(onRefresh: _cargarDatos),
              if (widget.idInvitacionRrpp != null &&
                  widget.idInvitacionRrpp!.isNotEmpty)
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _BannerInvitacionRrpp(),
                    ),
                  ),
                ),
              // —— 1) Contenedor flyer: pegado al top, centrado, max 70% alto, glow, sin nada encima ——
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxFlyerHeight),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: ColoresApp.principalMarca.withOpacity(
                                  0.35,
                                ),
                                blurRadius: 28,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: flyerUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: flyerUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: ColoresApp.fondoSuperficie,
                                        child: const Center(
                                          child: CupertinoActivityIndicator(),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Image.asset(
                                        flyerAsset,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: ColoresApp.fondoSuperficie,
                                          child: const Icon(
                                            CupertinoIcons.photo,
                                            size: 64,
                                            color: ColoresApp.textoSecundario,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Image.asset(
                                      flyerAsset,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: ColoresApp.fondoSuperficie,
                                        child: const Icon(
                                          CupertinoIcons.photo,
                                          size: 64,
                                          color: ColoresApp.textoSecundario,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // —— 2) Info: tarjeta título + descripción, tarjeta reserva+promos, tarjeta del local ——
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Tarjeta evento: título, descripción, fecha inicio + chips info
                    _TarjetaInfoEvento(
                      titulo: widget.evento['titulo'] ?? 'Evento',
                      descripcion: widget.evento['descripcion'] ?? '',
                      fechaInicio: fechaInicioDT,
                      edadMinima: _edadMinima,
                      tipoEvento:
                          _tipoEventoCargado ??
                          widget.evento['tipoEvento']?.toString(),
                      advertencias: _advertenciasEvento,
                    ),
                    const SizedBox(height: 12),
                    BotonCompartirEvento(
                      idEvento: idEvActual,
                      titulo: widget.evento['titulo']?.toString() ?? 'Evento',
                      nombreLocal: localNombre,
                      fechaIso: widget.evento['fechaInicio']?.toString(),
                      ciudad: widget.evento['ciudadEvento']?.toString(),
                    ),
                    const SizedBox(height: 16),

                    // Tarjeta Reserva lista + Ver promos + Comprar entradas
                    _TarjetaReservaYPromos(
                      evento: eventoParaTarjeta,
                      esModoSimple: _esEventoSimple,
                      miToken: _miToken,
                      esModoInvitacion: _esModoInvitacion,
                      onReservaLista: _abrirBottomSheetReserva,
                      onVerMiReserva: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const PantallaActividad(),
                          ),
                        );
                      },
                      onVerPromos: _abrirBottomSheetPromos,
                      onVerQR: _miToken != null
                          ? () => _abrirBottomSheetQR(
                              _miToken!['codigo_puerta']?.toString() ?? '',
                            )
                          : null,
                      onComprarEntradas:
                          (_urlCompraEntradas != null &&
                              _urlCompraEntradas!.isNotEmpty)
                          ? () => _abrirUrlExterna(_urlCompraEntradas!)
                          : null,
                      enviandoReserva: _enviandoReserva,
                      promosCount: _promos.length,
                      mostrarBotonPromos:
                          !_esModoInvitacion &&
                          (_promos.isNotEmpty ||
                              _tienePromoCargado ||
                              widget.evento['tienePromo'] == true),
                    ),
                    if (!_esModoInvitacion) ...[
                      const SizedBox(height: 16),
                      _BotonPoolsEvento(
                        onTap: () {
                          final idEv = _idEventoClave();
                          if (idEv.isEmpty) return;
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => PantallaPools(
                                idEvento: idEv,
                                nombreEvento:
                                    widget.evento['titulo']?.toString() ??
                                    'Evento',
                                flyerUrl: flyerUrl.isNotEmpty
                                    ? flyerUrl
                                    : flyerAsset,
                                nombreLocal: localNombre,
                                avatarLocal: localAvatar,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _CardLocalDetalle(
                        avatar: localAvatar,
                        nombre: localNombre,
                        verificado: _localVerificado,
                        esPionero: _localEsPionero,
                        calificacion: calificacion,
                        cantidadCalificaciones: _calificacionCantidad,
                        ubicacion: ubicacion,
                        onVerLocal: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => PantallaLocalPerfil(
                                avatarUrl: localAvatar,
                                nombreLocal: localNombre,
                                idLocal: widget.evento['idLocal'] as String?,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      _CarruselMasEventos(
                        idEventoActual: idEvActual.isEmpty ? null : idEvActual,
                      ),
                    ],
                    const SizedBox(height: 84),
                  ]),
                ),
              ),
            ],
          ),

          // Overlay full-screen mientras se envía la reserva
          if (_enviandoReserva)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: _OverlayCargando(
                      mensaje: _esModoInvitacion
                          ? 'Entrando a la lista…'
                          : 'Reservando tu lugar…',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _mensajeErrorReserva(dynamic e) {
    final raw = e.toString();
    debugPrint('🐛 Reserva error RAW: $raw');

    String code = '';
    String? edgeError;

    final dynamic details = e is FunctionException
        ? e.details
        : () {
            try {
              return (e as dynamic).details;
            } catch (_) {
              return null;
            }
          }();
    final map = _detallesEdge(details);
    if (map != null) {
      code = map['code']?.toString().toLowerCase() ?? '';
      edgeError = map['error']?.toString() ?? map['message']?.toString();
    }

    // Fallback: parsear el formato "Exception: status|code|msg"
    if (code.isEmpty) {
      final partes = raw.replaceAll('Exception: ', '').split('|');
      if (partes.length > 2) code = partes[1].trim().toLowerCase();
    }

    // Fallback final: regex sobre el texto crudo
    if (code.isEmpty) {
      final m = RegExp(r'code:\s*([a-z_]+)').firstMatch(raw.toLowerCase());
      if (m != null) code = m.group(1) ?? '';
    }

    debugPrint('🐛 Code parseado: "$code" edgeError: $edgeError');

    final lower = raw.toLowerCase();

    switch (code) {
      case 'invalid_jwt':
      case 'missing_authorization':
        return 'Tu sesión expiró. Cerrá sesión y volvé a entrar para reservar.';
      case 'user_profile_not_found':
        return 'Necesitás completar tu perfil antes de reservar. Andá a Mi Perfil y completá los datos.';
      case 'account_suspended':
        return 'Tu cuenta está suspendida. Contactá a soporte.';
      case 'invitacion_not_found':
      case 'invitacion_revocada':
      case 'invitacion_sin_permiso':
        return edgeError ?? 'Esta invitación ya no es válida.';
      case 'rrpp_self_invite':
        return 'No podés usar tu propia invitación.';
      case 'rate_limit_exceeded':
        return 'Demasiados intentos. Esperá un instante e intentá de nuevo.';
      case 'event_ended':
        return 'El evento ya finalizó.';
      case 'underage':
        return edgeError ??
            'No cumplís con la edad mínima requerida para este evento.';
      case 'event_not_found':
        return 'Este evento ya no está disponible.';
      case 'event_not_published':
        return 'Este evento no está publicado.';
      case 'event_started':
        return 'El evento ya comenzó, no se puede reservar.';
      case 'squad_disabled':
        return 'Este evento no permite reservar como squad.';
      case 'not_group_member':
        return 'No sos miembro aceptado de ese squad.';
      case 'list_full':
        return 'No quedan cupos disponibles para este evento.';
      case 'counter_retry_conflict':
        return 'El cupo cambió mientras reservabas. Probá de nuevo.';
      case 'duplicate_token':
        return 'Ya tenés una reserva para este evento. Revisá tu Actividad.';
    }

    if (lower.contains('duplicate') || lower.contains('409')) {
      return 'Ya tenés una reserva para este evento. Podés verla en Actividad.';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
    }
    return 'No se pudo reservar. Intentá de nuevo en unos momentos.';
  }

  bool _errorReservaRecuperable(dynamic e) {
    final raw = e.toString().toLowerCase();
    const noRecuperables = [
      'account_suspended',
      'invitacion_not_found',
      'invitacion_revocada',
      'invitacion_sin_permiso',
      'rrpp_self_invite',
      'rate_limit_exceeded',
      'underage',
      'user_profile_not_found',
    ];
    for (final code in noRecuperables) {
      if (raw.contains(code)) return false;
    }
    if (e is FunctionException) {
      final map = _detallesEdge(e.details);
      final code = map?['code']?.toString().toLowerCase() ?? '';
      if (noRecuperables.contains(code)) return false;
    }
    return true;
  }

  void _abrirBottomSheetReserva() {
    if (_eventoOcultoPorModeracion) {
      _mostrarError('Este evento ya no está disponible.');
      return;
    }
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _BottomSheetReservaLista(
        evento: widget.evento,
        squads: _squadsUsuario,
        edadMinima: _edadMinima,
        esModoInvitacion: _esModoInvitacion,
        onReservaExitosa: (String? idSquad) async {
          // Cerramos el bottomsheet
          Navigator.of(ctx).pop();
          if (!mounted) return;
          // Lanzamos el flujo de reserva en una función separada (más limpio)
          await _ejecutarReserva(idSquad);
        },
      ),
    );
  }

  /// Flujo de reserva: validar sesión → Edge `solicitar_asistencia` → éxito con modal o error.
  /// Si la Edge responde error pero ya existe fila en `tokens_asistencia`, tratamos como éxito
  /// (evita falsos negativos por status HTTP / parsing).
  Future<void> _ejecutarReserva(String? idSquad) async {
    setState(() => _enviandoReserva = true);

    final sb = ServicioSupabase().cliente;
    final userId = sb.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _enviandoReserva = false);
      if (mounted) {
        _mostrarError(
          'Tu sesión expiró. Cerrá sesión y volvé a entrar para reservar.',
        );
      }
      return;
    }

    final idEvento = _idEventoClave();
    if (idEvento.isEmpty) {
      if (mounted) setState(() => _enviandoReserva = false);
      if (mounted) _mostrarError('No se pudo identificar el evento.');
      return;
    }

    // Modo invitación de RRPP: distinto endpoint y body (entra directo aceptada).
    final esInvitacion =
        widget.idInvitacionRrpp != null && widget.idInvitacionRrpp!.isNotEmpty;
    final funcionReserva = esInvitacion
        ? 'invitacion_rrpp'
        : 'solicitar_asistencia';

    final body = <String, dynamic>{};
    if (esInvitacion) {
      body['accion'] = 'reservar';
      body['id_invitacion'] = widget.idInvitacionRrpp;
    } else {
      body['id_evento'] = idEvento;
    }
    if (idSquad != null && idSquad.isNotEmpty) body['id_grupo'] = idSquad;

    dynamic responseData;
    var invokeOk = false;

    try {
      final edgeResponse = await sb.functions.invoke(
        funcionReserva,
        body: body,
      );
      debugPrint(
        '📨 $funcionReserva status=${edgeResponse.status}'
        ' data=${edgeResponse.data}',
      );
      invokeOk = true;
      responseData = edgeResponse.data;
    } on FunctionException catch (fe) {
      debugPrint(
        '📨 $funcionReserva FunctionException status=${fe.status}'
        ' details=${fe.details}',
      );
      if (_errorReservaRecuperable(fe)) {
        final recovered = await _fetchTokenAsistenciaActual();
        if (_reservaActivaDesdeToken(recovered)) {
          invokeOk = true;
          responseData = null;
          _miToken = recovered;
        } else {
          if (mounted) setState(() => _enviandoReserva = false);
          if (mounted) _mostrarError(_mensajeErrorReserva(fe));
          return;
        }
      } else {
        if (mounted) setState(() => _enviandoReserva = false);
        if (mounted) _mostrarError(_mensajeErrorReserva(fe));
        return;
      }
    } catch (e) {
      debugPrint('📨 solicitar_asistencia error: $e');
      if (_errorReservaRecuperable(e)) {
        final recovered = await _fetchTokenAsistenciaActual();
        if (_reservaActivaDesdeToken(recovered)) {
          invokeOk = true;
          responseData = null;
          _miToken = recovered;
        } else {
          if (mounted) setState(() => _enviandoReserva = false);
          if (mounted) _mostrarError(_mensajeErrorReserva(e));
          return;
        }
      } else {
        if (mounted) setState(() => _enviandoReserva = false);
        if (mounted) _mostrarError(_mensajeErrorReserva(e));
        return;
      }
    }

    if (!invokeOk) return;

    try {
      final data = responseData;
      if (data is Map && data['token'] is Map) {
        _miToken = Map<String, dynamic>.from(data['token'] as Map);
      } else if (data is Map && data['codigo_puerta'] != null) {
        _miToken = {
          'estado_token': data['estado']?.toString() ?? 'aceptada',
          'codigo_puerta': data['codigo_puerta']?.toString(),
        };
      } else {
        final fresh = await _fetchTokenAsistenciaActual();
        if (fresh != null) _miToken = fresh;
      }
    } catch (_) {
      final fresh = await _fetchTokenAsistenciaActual();
      if (fresh != null) _miToken = fresh;
    }

    if (mounted) {
      setState(() => _enviandoReserva = false);
      _mostrarDialogoReservaExitosa(context);
    }

    _cargarDatos().catchError(
      (Object e) => debugPrint('⚠️ reload tras reserva (ignorable): $e'),
    );
  }

  void _mostrarDialogoReservaExitosa(BuildContext sheetContext) {
    HapticFeedback.mediumImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.85 + 0.15 * curved.value,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 22),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(
                        ColoresApp.fondoSuperficie,
                        ColoresApp.principalMarca,
                        0.12,
                      )!,
                      ColoresApp.fondoSuperficie,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: ColoresApp.principalMarca.withOpacity(0.35),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColoresApp.principalMarca.withOpacity(0.35),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Check grande animado
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            ColoresApp.principalMarca.withOpacity(0.4),
                            ColoresApp.principalMarca.withOpacity(0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: ColoresApp.principalMarca,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ColoresApp.principalMarca.withOpacity(
                                0.55,
                              ),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 36,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _esModoInvitacion
                          ? '¡Estás en la lista!'
                          : '¡Reserva enviada!',
                      style: GoogleFonts.baloo2(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _esModoInvitacion
                          ? 'Entraste directo con la invitación. '
                                'Mostrá tu QR en Actividad cuando llegues al local.'
                          : 'Vas a ver el estado de confirmación en tu Actividad. '
                                'Es posible que validen tu edad e identidad en el local.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        color: ColoresApp.textoSecundario,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            color: ColoresApp.fondoPrincipal,
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Aceptar',
                              style: GoogleFonts.baloo2(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.textoPrincipal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            color: ColoresApp.principalMarca,
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => PantallaActividad(),
                                ),
                              );
                            },
                            child: Text(
                              'Ir a Actividad',
                              style: GoogleFonts.baloo2(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarError(String msg) {
    HapticFeedback.heavyImpact();
    // Detectar tono según el contenido (error blando vs error duro)
    final lower = msg.toLowerCase();
    final esEdad = lower.contains('edad');
    final esPerfil = lower.contains('perfil');
    final esCupo = lower.contains('cupo');
    final esSesion = lower.contains('sesión') || lower.contains('sesion');
    IconData icono;
    Color color;
    String titulo;
    if (esEdad) {
      icono = CupertinoIcons.person_crop_circle_badge_exclam;
      color = ColoresApp.flashPromo;
      titulo = 'Edad mínima requerida';
    } else if (esPerfil) {
      icono = CupertinoIcons.person_circle_fill;
      color = ColoresApp.principalMarca;
      titulo = 'Completá tu perfil';
    } else if (esCupo) {
      icono = CupertinoIcons.flame_fill;
      color = ColoresApp.peligroMarca;
      titulo = 'Sin cupo disponible';
    } else if (esSesion) {
      icono = CupertinoIcons.lock_fill;
      color = ColoresApp.peligroMarca;
      titulo = 'Sesión expirada';
    } else {
      icono = CupertinoIcons.exclamationmark_triangle_fill;
      color = ColoresApp.peligroMarca;
      titulo = 'No pudimos reservar';
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.88 + 0.12 * curved.value,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 32,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icono, size: 36, color: color),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      titulo,
                      style: GoogleFonts.baloo2(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 13.5,
                        color: ColoresApp.textoSecundario,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (esPerfil) ...[
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: ColoresApp.principalMarca,
                        borderRadius: BorderRadius.circular(14),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          // No tengo ruta directa a perfil acá, cierro y dejo que el user
                          // navegue. Si tenés ruta nombrada, descomentá:
                          // Navigator.pushNamed(context, '/mi-perfil');
                        },
                        child: Text(
                          'Ir a Mi Perfil',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      color: ColoresApp.fondoPrincipal,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Entendido',
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
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
        );
      },
    );
  }

  Widget _buildEventoNoDisponible(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, padding.top + 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Icon(
                    CupertinoIcons.back,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ColoresApp.textoSecundario.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_shield_fill,
                      size: 38,
                      color: ColoresApp.textoSecundario,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Evento no disponible',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este evento está temporalmente oculto por moderación.',
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
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirBottomSheetPromos() {
    // MODO LECTURA. El sheet carga las promos DIRECTO de Supabase cuando se abre,
    // sin depender del cache _promos del state. Así garantizamos siempre data fresh.
    final tokenAceptado = listaPermitePromosUsuario(
      _miToken?['estado_token']?.toString(),
    );
    final eventoId = _idEventoClave();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BottomSheetVerPromos(
        eventoId: eventoId,
        tokenAceptado: tokenAceptado,
      ),
    );
  }

  // NOTA: la reserva de promos vive en pantalla_actividad (Sprint 4).
  // En ver_evento las promos son SOLO LECTURA.

  Future<void> _abrirUrlExterna(String rawUrl) async {
    var url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _mostrarError('Link inválido para comprar entradas.');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('No se pudo abrir');
    } catch (_) {
      if (mounted)
        _mostrarError('No pudimos abrir el link. Probá copiarlo del local.');
    }
  }

  void _abrirBottomSheetQR(String codigo) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _BottomSheetMiQR(
        codigo: codigo,
        tituloEvento: widget.evento['titulo']?.toString() ?? 'Evento',
      ),
    );
  }
}

/// Tarjeta con info del evento: título, descripción, fecha de inicio (única línea),
/// y chips de info (tipo, edad mínima, advertencias).
class _TarjetaInfoEvento extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final DateTime? fechaInicio;
  final int? edadMinima;
  final String? tipoEvento;
  final String? advertencias;

  const _TarjetaInfoEvento({
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    this.edadMinima,
    this.tipoEvento,
    this.advertencias,
  });

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _meses = [
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

  String _fechaCompacta(DateTime f) {
    final dia = _dias[f.weekday - 1];
    final mes = _meses[f.month - 1];
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    return '$dia ${f.day} $mes · $hh:$mm';
  }

  String _capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (fechaInicio != null) {
      chips.add(
        _ChipInfo(
          icono: CupertinoIcons.calendar,
          texto: _fechaCompacta(fechaInicio!),
          acento: true,
        ),
      );
    }
    if (edadMinima != null && edadMinima! > 0) {
      chips.add(
        _ChipInfo(
          icono: CupertinoIcons.person_crop_circle_badge_exclam,
          texto: '+$edadMinima',
          acento: false,
          destacado: true,
        ),
      );
    }
    if (tipoEvento != null && tipoEvento!.isNotEmpty) {
      chips.add(
        _ChipInfo(
          icono: CupertinoIcons.tag_fill,
          texto: _capitalizar(tipoEvento!),
          acento: false,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SuperficiesApp.card(radius: 20, temaTint: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.baloo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoPrincipal,
              height: 1.15,
              letterSpacing: -0.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (descripcion.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: GoogleFonts.baloo2(
                fontSize: 13.5,
                height: 1.4,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          if (advertencias != null && advertencias!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: ColoresApp.flashPromo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ColoresApp.flashPromo.withOpacity(0.45),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_circle_fill,
                    size: 16,
                    color: ColoresApp.flashPromo,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advertencias!,
                      style: GoogleFonts.baloo2(
                        fontSize: 12.5,
                        color: ColoresApp.textoPrincipal,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({
    required this.icono,
    required this.texto,
    this.acento = false,
    this.destacado = false,
  });
  final IconData icono;
  final String texto;
  final bool acento;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado
        ? ColoresApp.flashPromo
        : (acento ? ColoresApp.principalMarca : ColoresApp.textoSecundario);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            texto,
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta entre info evento y local: FOMO "lugares quedan" + Reservar lista + Ver promos + Comprar entradas.
class _TarjetaReservaYPromos extends StatelessWidget {
  final Map<String, dynamic> evento;
  final Map<String, dynamic>? miToken;
  final VoidCallback onReservaLista;
  final VoidCallback onVerMiReserva;
  final VoidCallback onVerPromos;
  final VoidCallback? onVerQR;
  final VoidCallback? onComprarEntradas;
  final bool enviandoReserva;
  final int promosCount;
  final bool mostrarBotonPromos;
  final bool esModoInvitacion;
  final bool esModoSimple;

  const _TarjetaReservaYPromos({
    required this.evento,
    this.esModoSimple = false,
    required this.miToken,
    required this.onReservaLista,
    required this.onVerMiReserva,
    required this.onVerPromos,
    this.onVerQR,
    this.onComprarEntradas,
    this.enviandoReserva = false,
    this.promosCount = 0,
    this.mostrarBotonPromos = false,
    this.esModoInvitacion = false,
  });

  @override
  Widget build(BuildContext context) {
    // Modo simple (vidriera): el evento es solo informativo, sin reservas ni promos.
    if (esModoSimple) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: SuperficiesApp.card(radius: 20, temaTint: 0.2),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.info_circle_fill,
              size: 22,
              color: ColoresApp.textoSecundario,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'El local no fijó reservas para este evento.',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final cupoLimitado = evento['cupoLimitado'] == true;
    final cuposLibres = evento['cuposLibres'] as int?;
    final tokenEstado = miToken?['estado_token']?.toString();
    final tokenAceptado = tokenEstado == 'aceptada';
    final yaReservadoActivo =
        miToken != null &&
        tokenEstado != 'rechazada' &&
        tokenEstado != 'cancelada';
    final puedeReservarDeNuevo =
        miToken == null ||
        tokenEstado == 'rechazada' ||
        tokenEstado == 'cancelada';
    final yaReservado = yaReservadoActivo;
    final labelEntrar = esModoInvitacion ? 'Entrar a lista' : 'Reservar lista';
    final labelProcesando = esModoInvitacion ? 'Entrando…' : 'Reservando…';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperficiesApp.card(radius: 20, temaTint: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chip FOMO: solo mostrar si cupo limitado (no en invitación)
          if (cupoLimitado && !esModoInvitacion) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ColoresApp.peligroMarca.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.flame_fill,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Solo quedan ${cuposLibres ?? 0} 🔥',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (miToken != null) ...[
            _buildEstadoBadge(tokenEstado),
            const SizedBox(height: 12),
          ],

          if (yaReservadoActivo) ...[
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onVerMiReserva,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoPrincipal,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: ColoresApp.principalMarca,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.square_list_fill,
                      size: 20,
                      color: ColoresApp.principalMarca,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ver mi reserva',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (tokenEstado == 'aceptada' && onVerQR != null) ...[
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onVerQR,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: ColoresApp.principalMarca.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.qrcode,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ver mi QR de entrada',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          if (puedeReservarDeNuevo)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: enviandoReserva ? null : onReservaLista,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: enviandoReserva
                      ? ColoresApp.principalMarca.withOpacity(0.7)
                      : ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: ColoresApp.principalMarca.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (enviandoReserva)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(color: Colors.white),
                      )
                    else
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 20,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      enviandoReserva ? labelProcesando : labelEntrar,
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (puedeReservarDeNuevo) const SizedBox(height: 12),

          // Botón promos: aparece si el evento tiene promo (flag local) o ya cargamos rows.
          // El sheet se encarga del empty state.
          if (mostrarBotonPromos)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onVerPromos,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C42),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C42).withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.gift_fill,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      promosCount > 0
                          ? 'Ver promos ($promosCount)'
                          : 'Ver promos del evento',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (mostrarBotonPromos && !tokenAceptado && !yaReservado) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Podés acceder a las promos reservando lista',
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  color: ColoresApp.textoSecundario,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (onComprarEntradas != null) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onComprarEntradas,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoPrincipal.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: ColoresApp.principalMarca.withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.cart_fill,
                      size: 17,
                      color: ColoresApp.principalMarca,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Comprar entrada',
                      style: GoogleFonts.baloo2(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.arrow_up_right_square,
                      size: 14,
                      color: ColoresApp.textoSecundario,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoBadge(String? estado) {
    Color color;
    String texto;
    switch (estado) {
      case 'aceptada':
        color = const Color(0xFF34C759);
        texto = 'Lista confirmada ✓';
        break;
      case 'pendiente':
        color = const Color(0xFFFFCC00);
        texto = 'En lista de espera';
        break;
      case 'canjeada':
        color = const Color(0xFF8E8E93);
        texto = 'Ya ingresaste';
        break;
      case 'rechazada':
        color = const Color(0xFFFF3B30);
        texto = 'Solicitud rechazada';
        break;
      default:
        color = ColoresApp.textoSecundario;
        texto = 'Estado desconocido';
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        ),
        child: Text(
          texto,
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Botón/tarjeta para ver el Pool del evento (quiénes van).
class _BotonPoolsEvento extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonPoolsEvento({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: SuperficiesApp.card(radius: 20, temaTint: 0.2),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.principalMarca.withValues(alpha: 0.15),
                border: Border.all(
                  color: ColoresApp.principalMarca.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                CupertinoIcons.person_2_fill,
                size: 22,
                color: ColoresApp.principalMarca,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver el Pool',
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mirá quiénes van a este evento',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: ColoresApp.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: reservar lista (solo/squad, checkbox edad, confirmar).
class _BottomSheetReservaLista extends StatefulWidget {
  final Map<String, dynamic> evento;
  final List<Map<String, dynamic>> squads;
  final int? edadMinima;
  final bool esModoInvitacion;
  final Function(String? idSquad) onReservaExitosa;

  const _BottomSheetReservaLista({
    required this.evento,
    required this.squads,
    required this.onReservaExitosa,
    this.edadMinima,
    this.esModoInvitacion = false,
  });

  @override
  State<_BottomSheetReservaLista> createState() =>
      _BottomSheetReservaListaState();
}

class _BottomSheetReservaListaState extends State<_BottomSheetReservaLista> {
  bool _vasSolo = true;
  Map<String, dynamic>? _squadSeleccionado;
  bool _confirmoEdad = false;

  @override
  Widget build(BuildContext context) {
    final marginNavbar = 58.0 + MediaQuery.of(context).padding.bottom + 4;
    return Padding(
      padding: EdgeInsets.only(bottom: marginNavbar),
      child: Container(
        decoration: SuperficiesApp.bottomSheet(topRadius: 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.esModoInvitacion ? 'Entrar a lista' : 'Reservar lista',
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Cómo vas?',
                  style: GoogleFonts.baloo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() {
                        _vasSolo = true;
                        _squadSeleccionado = null;
                      }),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _vasSolo
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            color: _vasSolo
                                ? ColoresApp.principalMarca
                                : ColoresApp.textoSecundario,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Solo',
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() {
                        _vasSolo = false;
                        _squadSeleccionado ??= widget.squads.isNotEmpty
                            ? widget.squads.first
                            : null;
                      }),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _vasSolo
                                ? CupertinoIcons.circle
                                : CupertinoIcons.checkmark_circle_fill,
                            color: _vasSolo
                                ? ColoresApp.textoSecundario
                                : ColoresApp.principalMarca,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Con squad',
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Squad: lista inline (sin modal anidado, evita crash)
                if (!_vasSolo && widget.squads.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoPrincipal,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ColoresApp.principalMarca.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: widget.squads.map((s) {
                        final seleccionado =
                            _squadSeleccionado?['id_squad'] == s['id_squad'];
                        final nombre = s['nombre_squad']?.toString() ?? '';
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: () =>
                              setState(() => _squadSeleccionado = s),
                          child: Row(
                            children: [
                              Icon(
                                seleccionado
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.circle,
                                color: seleccionado
                                    ? ColoresApp.principalMarca
                                    : ColoresApp.textoSecundario,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nombre,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 14,
                                    color: ColoresApp.textoPrincipal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Si el evento tiene edad mínima, lo destacamos arriba del checkbox
                if (widget.edadMinima != null && widget.edadMinima! > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.flashPromo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ColoresApp.flashPromo.withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.person_crop_circle_badge_exclam,
                          size: 18,
                          color: ColoresApp.flashPromo,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edad mínima: ${widget.edadMinima} años',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: ColoresApp.textoPrincipal,
                                ),
                              ),
                              Text(
                                'Si no la cumplís, no vas a poder ingresar al evento.',
                                style: GoogleFonts.baloo2(
                                  fontSize: 11.5,
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
                  const SizedBox(height: 12),
                ],
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _confirmoEdad = !_confirmoEdad),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _confirmoEdad
                            ? CupertinoIcons.checkmark_square_fill
                            : CupertinoIcons.square,
                        color: _confirmoEdad
                            ? ColoresApp.principalMarca
                            : ColoresApp.textoSecundario,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.edadMinima != null && widget.edadMinima! > 0
                                ? 'Confirmo que yo y/o mi squad tenemos al menos ${widget.edadMinima} años.'
                                : 'Confirmo que yo y/o mi squad cumplimos con la edad mínima que establece el evento.',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _confirmoEdad
                      ? () {
                          final idSquad = _vasSolo
                              ? null
                              : _squadSeleccionado?['id_squad']?.toString();
                          widget.onReservaExitosa(idSquad);
                        }
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _confirmoEdad
                          ? ColoresApp.principalMarca
                          : ColoresApp.textoSecundario.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        widget.esModoInvitacion
                            ? 'Entrar a lista'
                            : 'Reservar lista!',
                        style: GoogleFonts.baloo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: lista de promos con título, fechas, descripción, botón Obtener mi promo QR.
/// Bottomsheet de promos en MODO LECTURA (pantalla_ver_evento).
///
/// Carga las promos DIRECTO de Supabase al abrirse (no depende de cache).
/// Solo muestra la info de cada promo. La reserva se hace desde pantalla_actividad.
class _BottomSheetVerPromos extends StatefulWidget {
  final String eventoId;
  final bool tokenAceptado;

  const _BottomSheetVerPromos({
    required this.eventoId,
    required this.tokenAceptado,
  });

  @override
  State<_BottomSheetVerPromos> createState() => _BottomSheetVerPromosState();
}

class _BottomSheetVerPromosState extends State<_BottomSheetVerPromos> {
  bool _cargando = true;
  List<Map<String, dynamic>> _promos = const [];
  String? _errorMsg;
  int _intentos = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });
    try {
      _intentos++;
      final sb = ServicioSupabase().cliente;
      debugPrint(
        '🎁 [BottomSheet] Cargando promos para evento "${widget.eventoId}"'
        ' (intento $_intentos)',
      );
      final res = await sb
          .from('promociones')
          .select(
            'id_promocion, id_evento, id_local, titulo_promocion, descripcion_promocion,'
            ' fecha_inicio, fecha_fin, cupos_totales, cupos_usados, modo_uso, estado_promocion',
          )
          .eq('id_evento', widget.eventoId);
      final lista = List<Map<String, dynamic>>.from(res as List);
      debugPrint(
        '🎁 [BottomSheet] Promos crudas: ${lista.length}'
        ' (estados: ${lista.map((p) => p["estado_promocion"]).toList()})',
      );
      final activas = lista
          .where(
            (p) =>
                (p['estado_promocion']?.toString().toLowerCase() ?? 'activa') ==
                'activa',
          )
          .toList();
      debugPrint('🎁 [BottomSheet] Promos activas finales: ${activas.length}');
      if (mounted) {
        setState(() {
          _promos = activas;
          _cargando = false;
        });
      }
    } catch (e, st) {
      debugPrint('⚠️ [BottomSheet] Error: $e\n$st');
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _cargando = false;
        });
      }
    }
  }

  String _formatearFechaPromo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      const meses = [
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
      final dia = dias[dt.weekday - 1];
      final mes = meses[dt.month - 1];
      final hora =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$dia ${dt.day} $mes, $hora';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height * 0.78;
    final marginNavbar = 58.0 + MediaQuery.of(context).padding.bottom + 4;

    return Padding(
      padding: EdgeInsets.only(bottom: marginNavbar),
      child: Container(
        height: altura,
        decoration: SuperficiesApp.bottomSheet(topRadius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ColoresApp.textoSecundario.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.gift_fill,
                    color: Color(0xFFFF8C42),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Promos del evento',
                    style: GoogleFonts.baloo2(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  if (!_cargando) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${_promos.length})',
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: ColoresApp.textoSecundario,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            // Badge informativo
            if (_promos.isNotEmpty && !_cargando)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: widget.tokenAceptado
                        ? const Color(0xFF34C759).withOpacity(0.12)
                        : ColoresApp.principalMarca.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.tokenAceptado
                          ? const Color(0xFF34C759).withOpacity(0.45)
                          : ColoresApp.principalMarca.withOpacity(0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.tokenAceptado
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.info_circle_fill,
                        size: 16,
                        color: widget.tokenAceptado
                            ? const Color(0xFF34C759)
                            : ColoresApp.principalMarca,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.tokenAceptado
                              ? 'Tu lista está confirmada. Reservá tus promos desde Mi Actividad.'
                              : 'Podés acceder a las promos reservando lista en este evento.',
                          style: GoogleFonts.baloo2(
                            fontSize: 12.5,
                            color: ColoresApp.textoPrincipal,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _buildContenido()),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 12),
            Text(
              'Cargando promos…',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
        ),
      );
    }
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: ColoresApp.peligroMarca.withOpacity(0.85),
              ),
              const SizedBox(height: 14),
              Text(
                'No pudimos cargar las promos',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                color: ColoresApp.principalMarca,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),
                borderRadius: BorderRadius.circular(20),
                onPressed: _cargar,
                child: Text(
                  'Reintentar',
                  style: GoogleFonts.baloo2(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_promos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.gift,
                size: 56,
                color: ColoresApp.textoSecundario.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay promos cargadas todavía',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El local indicó que el evento tendrá promos pero aún no las publicó. Volvé a revisar más tarde.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  color: ColoresApp.textoSecundario,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              CupertinoButton(
                onPressed: _cargar,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Text(
                  'Reintentar',
                  style: GoogleFonts.baloo2(
                    color: ColoresApp.principalMarca,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      itemCount: _promos.length,
      itemBuilder: (context, index) {
        return _PromoCardLectura(
          promo: _promos[index],
          formatearFecha: _formatearFechaPromo,
        );
      },
    );
  }
}

/// Card de promo en modo LECTURA. Solo info. La reserva se hace desde actividad.
class _PromoCardLectura extends StatelessWidget {
  const _PromoCardLectura({required this.promo, required this.formatearFecha});
  final Map<String, dynamic> promo;
  final String Function(String?) formatearFecha;

  @override
  Widget build(BuildContext context) {
    final titulo = promo['titulo_promocion']?.toString() ?? 'Promo';
    final descripcion =
        promo['descripcion_promocion']?.toString() ??
        promo['descripcion_promo']?.toString() ??
        '';
    final fechaIni = formatearFecha(promo['fecha_inicio']?.toString());
    final fechaFin = formatearFecha(promo['fecha_fin']?.toString());
    final cupoTotal = promo['cupos_totales'] as int?;
    final cupoUsados = (promo['cupos_usados'] as int?) ?? 0;
    final cuposLibres = cupoTotal != null ? cupoTotal - cupoUsados : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SuperficiesApp.card(
          radius: 18,
          temaTint: 0.18,
          sombraAlpha: 0.12,
          sombraBlur: 8,
          sombraOffsetY: 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C42).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    CupertinoIcons.gift_fill,
                    size: 16,
                    color: Color(0xFFFF8C42),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: GoogleFonts.baloo2(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cuposLibres != null &&
                    cuposLibres > 0 &&
                    cuposLibres <= 15) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.peligroMarca.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.flame_fill,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$cuposLibres',
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (fechaIni.isNotEmpty || fechaFin.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.calendar,
                    size: 13,
                    color: ColoresApp.textoSecundario,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fechaIni.isNotEmpty && fechaFin.isNotEmpty
                          ? '$fechaIni — $fechaFin'
                          : (fechaIni.isNotEmpty ? fechaIni : fechaFin),
                      style: GoogleFonts.baloo2(
                        fontSize: 12,
                        color: ColoresApp.textoSecundario,
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
                  color: ColoresApp.textoSecundario,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: QR del token del usuario para este evento.
class _BottomSheetMiQR extends StatelessWidget {
  final String codigo;
  final String tituloEvento;

  const _BottomSheetMiQR({required this.codigo, required this.tituloEvento});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SuperficiesApp.bottomSheet(topRadius: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mi QR de entrada',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ColoresApp.textoPrincipal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                tituloEvento,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: ColoresApp.textoSecundario,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: codigo.isNotEmpty
                      ? QrImageView(
                          data: codigo,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        )
                      : const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: Icon(
                              CupertinoIcons.qrcode,
                              size: 80,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  codigo.isNotEmpty ? codigo : '—',
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Mostrá este código en la puerta',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: ColoresApp.textoSecundario,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: ColoresApp.fondoSuperficie,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      'Cerrar',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
                      ),
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
}

/// Card para "Más opciones": flyer real + título + local.
/// Card minimal solo-flyer para el carrusel "Más opciones para vos".
/// Sin título ni avatar — solo el flyer con badge promo si aplica.
class _CardMasOpcionesReal extends StatelessWidget {
  final String flyerUrl;
  final bool tienePromo;

  const _CardMasOpcionesReal({required this.flyerUrl, this.tienePromo = false});

  @override
  Widget build(BuildContext context) {
    const w = 144.0;
    const hFlyer = w / (9 / 14);
    const radius = 16.0;

    return SizedBox(
      width: w,
      child: Container(
        width: w,
        height: hFlyer,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: ColoresApp.principalMarca.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              flyerUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: flyerUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: ColoresApp.fondoSuperficie,
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: ColoresApp.fondoSuperficie,
                        child: const Icon(
                          CupertinoIcons.photo,
                          color: ColoresApp.textoSecundario,
                          size: 32,
                        ),
                      ),
                    )
                  : Container(
                      color: ColoresApp.fondoSuperficie,
                      child: const Icon(
                        CupertinoIcons.photo,
                        color: ColoresApp.textoSecundario,
                        size: 32,
                      ),
                    ),
              if (tienePromo)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.promoMarca,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.gift_fill,
                          size: 10,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Promo',
                          style: GoogleFonts.baloo2(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card enriquecida del local — estética alineada a las cards de suscripción
/// de la app de locales (gradiente + borde de color del tema, chips, rating).
class _CardLocalDetalle extends StatelessWidget {
  const _CardLocalDetalle({
    required this.avatar,
    required this.nombre,
    required this.verificado,
    required this.esPionero,
    required this.calificacion,
    required this.cantidadCalificaciones,
    required this.ubicacion,
    required this.onVerLocal,
  });
  final String avatar;
  final String nombre;
  final bool verificado;
  final bool esPionero;
  final double? calificacion;
  final int? cantidadCalificaciones;
  final String? ubicacion;
  final VoidCallback onVerLocal;

  // Color dorado distintivo para los locales pioneros.
  static const Color _colorPionero = Color(0xFFE0B800);

  @override
  Widget build(BuildContext context) {
    final tema = ColoresApp.principalMarca;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tema.withValues(alpha: 0.20), ColoresApp.fondoSuperficie],
        ),
        border: Border.all(color: tema.withValues(alpha: 0.40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tema.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(avatar: avatar, esPionero: esPionero),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORGANIZA',
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoSecundario,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            nombre,
                            style: GoogleFonts.baloo2(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.textoPrincipal,
                              letterSpacing: -0.4,
                              height: 1.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (verificado) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 17,
                            color: tema,
                          ),
                        ],
                      ],
                    ),
                    if (ubicacion != null && ubicacion!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            size: 12,
                            color: tema,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ubicacion!,
                              style: GoogleFonts.baloo2(
                                fontSize: 12.5,
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
          const SizedBox(height: 14),
          // Chips de estado (pionero / verificado)
          if (esPionero || verificado)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (esPionero)
                    _ChipEstadoLocal(
                      icono: CupertinoIcons.rosette,
                      texto: 'Pionero',
                      color: _colorPionero,
                    ),
                  if (verificado)
                    _ChipEstadoLocal(
                      icono: CupertinoIcons.checkmark_seal_fill,
                      texto: 'Verificado',
                      color: tema,
                    ),
                ],
              ),
            ),
          // Rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: ColoresApp.fondoPrincipal.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _RatingEstrellas(
              calificacion: calificacion,
              cantidad: cantidadCalificaciones,
            ),
          ),
          const SizedBox(height: 12),
          // Botón ver local
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onVerLocal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: tema,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: tema.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.bag_fill,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ver local',
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado del local (pionero / verificado), estilo app de locales.
class _ChipEstadoLocal extends StatelessWidget {
  const _ChipEstadoLocal({
    required this.icono,
    required this.texto,
    required this.color,
  });
  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatar, this.esPionero = false});
  final String avatar;
  final bool esPionero;

  @override
  Widget build(BuildContext context) {
    final color = esPionero
        ? _CardLocalDetalle._colorPionero
        : ColoresApp.principalMarca;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: _avatarUrlEsAsset(avatar)
            ? Image.asset(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: ColoresApp.fondoSuperficie,
                  child: const Icon(
                    CupertinoIcons.bag_fill,
                    color: ColoresApp.textoSecundario,
                    size: 26,
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: avatar,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: ColoresApp.fondoSuperficie,
                  child: const CupertinoActivityIndicator(),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: ColoresApp.fondoSuperficie,
                  child: const Icon(
                    CupertinoIcons.bag_fill,
                    color: ColoresApp.textoSecundario,
                    size: 26,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RatingEstrellas extends StatelessWidget {
  const _RatingEstrellas({required this.calificacion, required this.cantidad});
  final double? calificacion;
  final int? cantidad;

  @override
  Widget build(BuildContext context) {
    final c = calificacion;
    final estrellas = <Widget>[];
    if (c == null) {
      for (var i = 0; i < 5; i++) {
        estrellas.add(
          Icon(
            CupertinoIcons.star,
            size: 18,
            color: ColoresApp.textoSecundario.withOpacity(0.45),
          ),
        );
      }
      return Row(
        children: [
          ...estrellas,
          const SizedBox(width: 8),
          Text(
            'Sin calificaciones aún',
            style: GoogleFonts.baloo2(
              fontSize: 12,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      );
    }
    for (var i = 0; i < 5; i++) {
      final pos = i + 1;
      IconData icono;
      if (c >= pos) {
        icono = CupertinoIcons.star_fill;
      } else if (c >= pos - 0.5) {
        icono = CupertinoIcons.star_lefthalf_fill;
      } else {
        icono = CupertinoIcons.star;
      }
      estrellas.add(Icon(icono, size: 18, color: const Color(0xFFFFC107)));
    }
    return Row(
      children: [
        ...estrellas,
        const SizedBox(width: 8),
        Text(
          c.toStringAsFixed(1),
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: ColoresApp.textoPrincipal,
          ),
        ),
        if (cantidad != null && cantidad! > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($cantidad)',
            style: GoogleFonts.baloo2(
              fontSize: 12,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}

/// Overlay reusable mientras se envía una acción de red.
class _OverlayCargando extends StatelessWidget {
  const _OverlayCargando({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CupertinoActivityIndicator(
              color: ColoresApp.principalMarca,
              radius: 16,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mensaje,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Carrusel "Más eventos para vos" — widget independiente con su propia query.
// Se monta al entrar a pantalla_ver_evento y consulta directamente Supabase.
// Trae las últimas rows de la tabla `eventos` (por fecha_subida desc), excluye
// el evento actual, y muestra solo el flyer en un carrusel horizontal.
// Al tocar una card, navega a PantallaVerEvento con ese evento.
// ============================================================================

class _CarruselMasEventos extends StatefulWidget {
  final String? idEventoActual;
  const _CarruselMasEventos({this.idEventoActual});

  @override
  State<_CarruselMasEventos> createState() => _CarruselMasEventosState();
}

class _CarruselMasEventosState extends State<_CarruselMasEventos> {
  bool _cargando = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final sb = ServicioSupabase().cliente;
      final res = await sb
          .from('eventos')
          .select(
            'id_evento, titulo_evento, descripcion_evento, url_flyer, jerarquia, '
            'tiene_promo, id_local, fecha_inicio, fecha_fin, cupo_lista_max, '
            'cupo_lista_usados, modo_lista, ciudad_evento, provincia_evento, '
            'perfiles_locales!eventos_id_local_fkey!inner(estado_cuenta)',
          )
          .eq('perfiles_locales.estado_cuenta', 'activa')
          .order('fecha_subida', ascending: false)
          .limit(6);
      final lista = List<Map<String, dynamic>>.from(res as List);
      debugPrint('🎬 _CarruselMasEventos: ${lista.length} rows traídas');
      final filtrada = lista
          .where(
            (e) =>
                (e['id_evento']?.toString() ?? '') !=
                (widget.idEventoActual ?? '___'),
          )
          .take(5)
          .toList();
      if (!mounted) return;
      setState(() {
        _items = filtrada;
        _cargando = false;
      });
      debugPrint('🎬 _CarruselMasEventos: ${_items.length} cards listas');
    } catch (e) {
      debugPrint('⚠️ _CarruselMasEventos error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Map<String, dynamic> _mapeoParaNavegacion(Map<String, dynamic> row) {
    final cupoMax = row['cupo_lista_max'] as int?;
    final cupoUsados = (row['cupo_lista_usados'] as int?) ?? 0;
    return {
      'id': row['id_evento']?.toString() ?? '',
      'titulo': row['titulo_evento']?.toString() ?? 'Evento',
      'descripcion': row['descripcion_evento']?.toString() ?? '',
      'flyer': row['url_flyer']?.toString() ?? '',
      'jerarquia': row['jerarquia']?.toString() ?? 'gratis',
      'tienePromo': row['tiene_promo'] == true,
      'cupoMax': cupoMax,
      'cuposLibres': cupoMax != null ? cupoMax - cupoUsados : null,
      'cupoLimitado': cupoMax != null,
      'modoLista': row['modo_lista']?.toString() ?? 'auto',
      'fechaInicio': row['fecha_inicio'],
      'fechaFin': row['fecha_fin'],
      'idLocal': row['id_local']?.toString(),
      'ciudadEvento': row['ciudad_evento']?.toString(),
      'provinciaEvento': row['provincia_evento']?.toString(),
      'nombreLocal': 'Local',
      'avatarLocal': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 11),
              const SizedBox(height: 8),
              Text(
                'Cargando más eventos…',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.sparkles,
              size: 18,
              color: ColoresApp.principalMarca,
            ),
            const SizedBox(width: 6),
            Text(
              'Más eventos para vos',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 144 * (14 / 9),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final row = _items[index];
              final flyer = row['url_flyer']?.toString() ?? '';
              final tienePromo = row['tiene_promo'] == true;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          PantallaVerEvento(evento: _mapeoParaNavegacion(row)),
                    ),
                  );
                },
                child: _CardMasOpcionesReal(
                  flyerUrl: flyer,
                  tienePromo: tienePromo,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Banner que indica que el usuario llegó por un QR de invitación de RRPP.
/// Al reservar, entra directo a la lista (aceptado al instante).
class _BannerInvitacionRrpp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final acento = ColoresApp.principalMarca;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [acento.withOpacity(0.22), acento.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: acento.withOpacity(0.45), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: acento.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.ticket_fill, size: 20, color: acento),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitación de RRPP',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Al reservar entrás directo a la lista, aceptado al instante.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ColoresApp.textoSecundario,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
