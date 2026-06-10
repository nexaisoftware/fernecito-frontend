library;

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/rompehielo_navegacion.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/servicio_reportes.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/boton_rompehielo.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/icono_local.dart';
import '../widgets/social_ui.dart';
import 'pantalla_rompehielo.dart' show TipoContraparte;

enum EstadoRelacionUsuario {
  ninguno,
  solicitudEnviada,
  solicitudRecibida,
  amigo,
}

class PantallaPerfilUsuarios extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final EstadoRelacionUsuario estadoRelacion;
  final RompehieloOrigen rompehieloOrigen;
  final String? rompehieloIdEvento;
  final String? rompehieloNombreEvento;

  const PantallaPerfilUsuarios({
    super.key,
    required this.usuario,
    required this.estadoRelacion,
    this.rompehieloOrigen = RompehieloOrigen.perfil,
    this.rompehieloIdEvento,
    this.rompehieloNombreEvento,
  });

  @override
  State<PantallaPerfilUsuarios> createState() => _PantallaPerfilUsuariosState();
}

class _PantallaPerfilUsuariosState extends State<PantallaPerfilUsuarios> {
  late EstadoRelacionUsuario _estado;

  final ServicioAmigos _srv = ServicioAmigos();
  final ServicioPerfilUsuario _srvPerfil = ServicioPerfilUsuario();
  String? _idUsuario;
  String? _idRelacion;
  bool _procesando = false;
  bool _cargandoDetalle = true;
  Map<String, dynamic>? _detalle;
  String _instagramPersistido = '';
  String _tiktokPersistido = '';
  List<SquadResumen> _squadsDondeEsMiembro = const [];
  RompehieloEstado? _rompehieloEstado;

  static String _textoMiembroSquads(List<SquadResumen> squads) {
    if (squads.isEmpty) return '';
    final nombres = squads.map((s) => s.nombre).toList();
    if (nombres.length == 1) return 'Miembro de ${nombres.first}';
    if (nombres.length == 2) {
      return 'Miembro de ${nombres[0]} y ${nombres[1]}';
    }
    final todosMenosUltimo = nombres.sublist(0, nombres.length - 1).join(', ');
    return 'Miembro de $todosMenosUltimo y ${nombres.last}';
  }

  static String _arroba(String username) {
    final u = username.trim();
    if (u.isEmpty) return '@usuario';
    return u.startsWith('@') ? u : '@$u';
  }

  @override
  void initState() {
    super.initState();
    _estado = widget.estadoRelacion;
    _idUsuario = widget.usuario['id_usuario']?.toString();
    _idRelacion = widget.usuario['id_relacion']?.toString();
    _instagramPersistido =
        (widget.usuario['instagram_url'] as String?)?.trim() ?? '';
    _tiktokPersistido = (widget.usuario['tiktok_url'] as String?)?.trim() ?? '';
    _cargarDetalle();
  }

  String _urlRed(String key) {
    for (final src in [
      _detalle?[key],
      widget.usuario[key],
      key == 'instagram_url' ? _instagramPersistido : _tiktokPersistido,
    ]) {
      final s = src?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  Future<void> _cargarDetalle() async {
    final id = _idUsuario;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _cargandoDetalle = false);
      return;
    }
    final det = await _srvPerfil.detalle(id);
    if (!mounted) return;
    setState(() {
      _detalle = det;
      _cargandoDetalle = false;
      if (det != null) {
        final ea = det['estado_amistad'] as String?;
        if (ea != null && ea.isNotEmpty) {
          _estado = _estadoDesdeAmistad(ea);
        }
        final ir = det['id_relacion']?.toString();
        if (ir != null && ir.isNotEmpty) _idRelacion = ir;
      }
      final ig = det?['instagram_url']?.toString().trim() ?? '';
      final tt = det?['tiktok_url']?.toString().trim() ?? '';
      if (ig.isNotEmpty) _instagramPersistido = ig;
      if (tt.isNotEmpty) _tiktokPersistido = tt;
    });
    if (id.isNotEmpty) {
      final activos = await listarInvolucramientosRompehielo(
        otroTipo: 'usuario',
        otroId: id,
      );
      if (mounted) {
        setState(() {
          _rompehieloEstado = mejorInvolucramiento(activos)?.estado;
        });
      }
    }
    if (_estado == EstadoRelacionUsuario.amigo) {
      await _cargarSquadsMiembroAmigo();
    }
  }

  Future<void> _cargarSquadsMiembroAmigo() async {
    final id = _idUsuario;
    if (id == null || id.isEmpty) return;
    final srv = ServicioSquads();
    final mios = await srv.misSquads();
    final invitables = mios.where((s) => s.puedeInvitar).toList();
    final miembros = <SquadResumen>[];
    await Future.wait(
      invitables.map((s) async {
        final det = await srv.detalle(s.idGrupo);
        if (det?.miembros.any((m) => m.idUsuario == id) == true) {
          miembros.add(s);
        }
      }),
    );
    if (mounted) setState(() => _squadsDondeEsMiembro = miembros);
  }

  EstadoRelacionUsuario _estadoDesdeAmistad(String estadoAmistad) {
    switch (estadoAmistad) {
      case 'amigo':
        return EstadoRelacionUsuario.amigo;
      case 'enviada':
        return EstadoRelacionUsuario.solicitudEnviada;
      case 'recibida':
        return EstadoRelacionUsuario.solicitudRecibida;
      default:
        return EstadoRelacionUsuario.ninguno;
    }
  }

  Future<void> _recargarTrasAmistad() async {
    if (!mounted) return;
    setState(() => _cargandoDetalle = true);
    await _cargarDetalle();
  }

  Future<void> _reportarUsuario() async {
    final id = _idUsuario;
    if (id == null || id.isEmpty || _procesando) return;
    final motivo = await _elegirMotivoReporte();
    if (motivo == null) return;
    setState(() => _procesando = true);
    try {
      final res = await ServicioReportes().reportarCuenta(
        reportanteTipo: 'usuario',
        targetTipo: 'usuario',
        targetId: id,
        motivo: motivo.codigo,
      );
      if (!mounted) return;
      _mostrarAvisoReporte(
        res['ok'] == true
            ? 'Gracias. Vamos a revisar este perfil.'
            : (res['error']?.toString() ?? 'No se pudo enviar el reporte.'),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<MotivoReporte?> _elegirMotivoReporte() {
    return showCupertinoModalPopup<MotivoReporte>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Reportar perfil'),
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
  }

  void _mostrarAvisoReporte(String mensaje) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reporte enviado'),
        content: Text(mensaje),
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

  Future<void> _onAccionAmistad() async {
    final idUsuario = _idUsuario;
    if (_procesando || idUsuario == null || idUsuario.isEmpty) return;
    setState(() => _procesando = true);
    bool ok = false;
    var recargarPerfil = false;
    switch (_estado) {
      case EstadoRelacionUsuario.ninguno:
        final estado = await _srv.solicitar(idUsuario);
        ok = estado != null;
        if (ok && mounted) {
          final esAmigo = estado == 'aceptada' || estado == 'aceptado';
          if (esAmigo) {
            recargarPerfil = true;
          } else {
            setState(() => _estado = EstadoRelacionUsuario.solicitudEnviada);
          }
        }
        break;
      case EstadoRelacionUsuario.solicitudRecibida:
        if (_idRelacion != null && _idRelacion!.isNotEmpty) {
          ok = await _srv.responder(_idRelacion!, aceptar: true);
        } else {
          // Fallback: solicitar al emisor acepta recíprocamente en el backend.
          final estado = await _srv.solicitar(idUsuario);
          ok = estado == 'aceptada' || estado == 'aceptado';
        }
        if (ok && mounted) recargarPerfil = true;
        break;
      case EstadoRelacionUsuario.solicitudEnviada:
      case EstadoRelacionUsuario.amigo:
        ok = await _srv.eliminar(idUsuario);
        if (ok && mounted) {
          setState(() => _estado = EstadoRelacionUsuario.ninguno);
        }
        break;
    }
    if (mounted) {
      if (recargarPerfil && ok) {
        await _recargarTrasAmistad();
      }
      setState(() => _procesando = false);
      if (!ok) {
        _mostrarError('No se pudo completar la acción. Intentá de nuevo.');
      }
    }
  }

  Future<void> _abrirUrl(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _mostrarError('El enlace no es válido.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _mostrarError('No se pudo abrir el enlace.');
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
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

  String get _avatarUrl {
    final fromDetalle = ServicioSupabase().urlAvatar(
      _detalle?['foto_perfil_url']?.toString(),
    );
    if (fromDetalle != null && fromDetalle.isNotEmpty) return fromDetalle;
    return widget.usuario['avatar'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final usuario = widget.usuario;
    final avatar = _avatarUrl;
    final username = _arroba(
      (_detalle?['username'] ?? usuario['username'])?.toString() ?? '',
    );
    final puedeVer =
        !_cargandoDetalle && (_detalle?['puede_ver'] as bool? ?? false);
    final bloqueada =
        !_cargandoDetalle && (_detalle?['bloqueada'] as bool? ?? false);
    final esAmigoDetalle = _detalle?['es_amigo'] == true ||
        _estado == EstadoRelacionUsuario.amigo;
    final nombreVisible = puedeVer
        ? ((_detalle?['nombre'] ?? usuario['nombre'])?.toString() ?? 'Usuario')
        : PrivacidadPerfil.tituloPerfilPrivado;
    final estado = puedeVer
        ? ((_detalle?['mi_estado'] ?? usuario['estado']) as String?)?.trim() ??
              ''
        : '';
    final instagramUrl = _urlRed('instagram_url');
    final tiktokUrl = _urlRed('tiktok_url');
    final locales = ServicioPerfilUsuario.enteroDeDetalle(
      _detalle,
      'locales_visitados',
    );
    final eventos = ServicioPerfilUsuario.enteroDeDetalle(
      _detalle,
      'eventos_asistidos',
    );
    final cantidadAmigos = ServicioPerfilUsuario.enteroDeDetalle(
      _detalle,
      'cantidad_amigos',
    );
    final sinActividad =
        !_cargandoDetalle &&
        puedeVer &&
        locales == 0 &&
        eventos == 0 &&
        cantidadAmigos == 0;

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            padding.top + 8,
            20,
            padding.bottom + 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    minimumSize: Size.zero,
                    child: Icon(
                      CupertinoIcons.back,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      puedeVer ? 'Ver perfil de $username' : username,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (_idUsuario != null && _idUsuario!.isNotEmpty)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 30),
                      onPressed: _procesando ? null : _reportarUsuario,
                      child: Text(
                        'Reportar',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (_cargandoDetalle)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else if (bloqueada) ...[
                _buildPerfilBloqueado(
                  username: username,
                  esAmigo: esAmigoDetalle,
                ),
              ] else if (!puedeVer) ...[
                _buildCabeceraPerfilPrivado(
                  context: context,
                  username: username,
                  avatar: avatar,
                ),
                const SizedBox(height: 28),
                _buildActionButtonTitulo(),
                const SizedBox(height: 10),
                _buildActionButton(),
                // Rompehielo disponible también en perfiles privados.
                if (_idUsuario != null) ...[
                  const SizedBox(height: 12),
                  _botonRompehielo(usuario: usuario, nombre: username),
                ],
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Text(
                        nombreVisible,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: ColoresApp.textoPrincipal,
                          height: 1.1,
                        ),
                      ),
                      if (_estado == EstadoRelacionUsuario.amigo) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ColoresApp.principalMarca.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            'Amigos',
                            style: GoogleFonts.baloo2(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                        ),
                      ] else if (sinActividad) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Nuevo en Fernecito',
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AvatarUsuario(
                        avatar: avatar,
                        size: 112,
                        onTap: () => _abrirVisualizadorAvatar(context, avatar),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
                        ),
                        child: BurbujaEstado(
                          texto: estado,
                          fontSize: 14,
                          ajustarAnchoAlTexto: true,
                          maxLines: 3,
                        ),
                      ),
                      if (_idUsuario != null) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _botonRompehielo(
                            usuario: usuario,
                            nombre: nombreVisible,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildRedesSociales(
                  instagramUrl: instagramUrl,
                  tiktokUrl: tiktokUrl,
                ),
                const SizedBox(height: 22),
                _buildSeccionActividad(
                  nombre: nombreVisible,
                  puedeVer: puedeVer,
                  sinActividad: sinActividad,
                ),
                const SizedBox(height: 24),
                _buildActionButtonTitulo(),
                const SizedBox(height: 10),
                _buildActionButton(),
              ],
              if (puedeVer && _estado == EstadoRelacionUsuario.amigo) ...[
                const SizedBox(height: 18),
                if (_squadsDondeEsMiembro.isNotEmpty)
                  Text(
                    _textoMiembroSquads(_squadsDondeEsMiembro),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.principalMarca,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () =>
                      _abrirAgregarASquad(context, nombreVisible, username),
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: ColoresApp.principalMarca.withValues(
                          alpha: 0.32,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.person_3_fill,
                          size: 17,
                          color: ColoresApp.principalMarca,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _squadsDondeEsMiembro.isEmpty
                              ? 'Agregar a un squad'
                              : 'Añadir a otro squad',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: ColoresApp.textoPrincipal,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _procesando ? null : _onAccionAmistad,
                    child: Text(
                      'Eliminar amigo',
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.peligroMarca.withValues(alpha: 0.85),
                        decoration: TextDecoration.underline,
                        decorationColor: ColoresApp.peligroMarca.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Botón de rompehielo. Disponible en cualquier perfil (público o privado):
  /// romper el hielo no depende de la visibilidad del perfil.
  Widget _botonRompehielo({
    required Map<String, dynamic> usuario,
    required String nombre,
  }) {
    return BotonRompehielo(
      nombre: nombre,
      esEmisor: _rompehieloEstado?.debeResponder == true,
      esSecundario: _rompehieloEstado?.jerarquiaAlta == false,
      onTap: () async {
        await abrirRompehielo(
          context,
          tipoContraparte: TipoContraparte.usuario,
          contraparte: usuario,
          origen: widget.rompehieloOrigen,
          idEvento: widget.rompehieloIdEvento,
          nombreEvento: widget.rompehieloNombreEvento,
        );
        final id = _idUsuario;
        if (id != null && mounted) {
          final activos = await listarInvolucramientosRompehielo(
            otroTipo: 'usuario',
            otroId: id,
          );
          if (mounted) {
            setState(() {
              _rompehieloEstado = mejorInvolucramiento(activos)?.estado;
            });
          }
        }
      },
    );
  }

  /// Elimina la amistad sin importar el switch de estado (para perfil bloqueado).
  Future<void> _eliminarAmigoDirecto() async {
    final idUsuario = _idUsuario;
    if (_procesando || idUsuario == null || idUsuario.isEmpty) return;
    setState(() => _procesando = true);
    final ok = await _srv.eliminar(idUsuario);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      if (ok) {
        _estado = EstadoRelacionUsuario.ninguno;
        if (_detalle != null) _detalle!['es_amigo'] = false;
      }
    });
    if (!ok) _mostrarError('No se pudo eliminar la amistad. Intentá de nuevo.');
  }

  /// Cuenta bloqueada por moderación: solo username + ícono redondo + cartel.
  /// Si era amigo, único acción disponible: eliminar amistad.
  Widget _buildPerfilBloqueado({
    required String username,
    required bool esAmigo,
  }) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColoresApp.fondoSuperficie,
              border: Border.all(
                color: ColoresApp.textoSecundario.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              CupertinoIcons.person_fill,
              size: 54,
              color: ColoresApp.textoSecundario.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            username,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: ColoresApp.fondoSuperficie.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ColoresApp.textoSecundario.withValues(alpha: 0.18),
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
                  'Cuenta bloqueada temporalmente por el equipo de '
                  'moderación de Fernecito.',
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
          if (esAmigo) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 13),
                color: ColoresApp.fondoSuperficie,
                borderRadius: BorderRadius.circular(50),
                onPressed: _procesando ? null : _eliminarAmigoDirecto,
                child: _procesando
                    ? const CupertinoActivityIndicator()
                    : Text(
                        'Eliminar amigo',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.peligroMarca,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCabeceraPerfilPrivado({
    required BuildContext context,
    required String username,
    required String avatar,
  }) {
    return Center(
      child: Column(
        children: [
          Text(
            PrivacidadPerfil.tituloPerfilPrivado,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            username,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ColoresApp.principalMarca,
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AvatarUsuario(avatar: avatar, size: 112),
              const InsigniaCandadoPrivado(avatarSize: 112),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedesSociales({
    required String instagramUrl,
    required String tiktokUrl,
  }) {
    final igActivo = instagramUrl.isNotEmpty;
    final ttActivo = tiktokUrl.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _EnlaceRedMinimal(
          icono: FontAwesomeIcons.instagram,
          etiqueta: 'Instagram',
          habilitado: igActivo,
          onTap: igActivo ? () => _abrirUrl(instagramUrl) : null,
        ),
        const SizedBox(width: 28),
        _EnlaceRedMinimal(
          icono: FontAwesomeIcons.tiktok,
          etiqueta: 'TikTok',
          habilitado: ttActivo,
          onTap: ttActivo ? () => _abrirUrl(tiktokUrl) : null,
        ),
      ],
    );
  }

  static const double _alturaCeldaActividad = 92;

  Widget _celdaMetricaGrilla({
    IconData? icono,
    Widget? iconoWidget,
    required String etiqueta,
    required String valor,
  }) {
    final iconChild =
        iconoWidget ?? Icon(icono, size: 20, color: ColoresApp.principalMarca);

    return SizedBox(
      height: _alturaCeldaActividad,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconChild,
          const SizedBox(height: 8),
          Text(
            valor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoSecundario,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeUbicacion(String ubicacion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.location_solid,
            size: 12,
            color: ColoresApp.textoSecundario.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 5),
          Text(
            ubicacion,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionActividad({
    required String nombre,
    required bool puedeVer,
    required bool sinActividad,
  }) {
    if (_cargandoDetalle) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (!puedeVer) {
      return const SizedBox.shrink();
    }

    final ciudad = (_detalle?['ciudad'] as String?)?.trim() ?? '';
    final provincia = (_detalle?['provincia'] as String?)?.trim() ?? '';
    final edad = _detalle?['edad'];
    final edadInt = edad is int ? edad : int.tryParse(edad?.toString() ?? '');
    final locales = ServicioPerfilUsuario.enteroDeDetalle(
      _detalle,
      'locales_visitados',
    );
    final eventos = ServicioPerfilUsuario.enteroDeDetalle(
      _detalle,
      'eventos_asistidos',
    );
    final cantidadAmigos = ServicioPerfilUsuario.enteroDeDetalle(
      _detalle,
      'cantidad_amigos',
    );

    String ubicacion = '';
    if (ciudad.isNotEmpty && provincia.isNotEmpty) {
      ubicacion = '$ciudad, $provincia';
    } else if (ciudad.isNotEmpty) {
      ubicacion = ciudad;
    } else if (provincia.isNotEmpty) {
      ubicacion = provincia;
    }

    final celdas = <Widget>[
      _celdaMetricaGrilla(
        icono: CupertinoIcons.person_2_fill,
        etiqueta: 'Amigos',
        valor: '$cantidadAmigos',
      ),
    ];
    if (edadInt != null && edadInt > 0) {
      celdas.add(
        _celdaMetricaGrilla(
          icono: CupertinoIcons.person_fill,
          etiqueta: 'Edad',
          valor: '$edadInt años',
        ),
      );
    }
    if (locales > 0) {
      celdas.add(
        _celdaMetricaGrilla(
          iconoWidget: IconoLocal(size: 20, color: ColoresApp.principalMarca),
          etiqueta: 'Locales visitados',
          valor: '$locales',
        ),
      );
    }
    if (eventos > 0) {
      celdas.add(
        _celdaMetricaGrilla(
          icono: CupertinoIcons.ticket_fill,
          etiqueta: 'Eventos vividos',
          valor: '$eventos',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final anchoCelda = (constraints.maxWidth - gap) / 2;
        return Column(
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: celdas
                  .map(
                    (c) => SizedBox(
                      width: anchoCelda,
                      height: _alturaCeldaActividad,
                      child: c,
                    ),
                  )
                  .toList(),
            ),
            if (ubicacion.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(child: _badgeUbicacion(ubicacion)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionButtonTitulo() {
    final nombre =
        (_detalle?['nombre'] ?? widget.usuario['nombre'])?.toString() ??
        'Usuario';
    final username = _arroba(
      (_detalle?['username'] ?? widget.usuario['username'])?.toString() ?? '',
    );
    final puedeVer =
        !_cargandoDetalle && (_detalle?['puede_ver'] as bool? ?? false);

    if (!puedeVer) {
      if (_estado == EstadoRelacionUsuario.solicitudRecibida) {
        return Text(
          '$username quiere ser tu amigo',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
            height: 1.35,
          ),
        );
      }
      if (_estado == EstadoRelacionUsuario.solicitudEnviada) {
        return Text(
          'Solicitud enviada',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          PrivacidadPerfil.tituloSolicitudAmistadPrivado(username),
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
            height: 1.35,
          ),
        ),
      );
    }

    switch (_estado) {
      case EstadoRelacionUsuario.amigo:
        return Text(
          'Tú y $nombre son amigos',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
        );
      case EstadoRelacionUsuario.solicitudEnviada:
        return Text(
          'Solicitud enviada',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
        );
      case EstadoRelacionUsuario.ninguno:
        return Text(
          '¿Querés ser amigo de $username?',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
        );
      case EstadoRelacionUsuario.solicitudRecibida:
        return Text(
          '$username quiere ser tu amigo',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColoresApp.textoSecundario,
          ),
        );
    }
  }

  void _abrirAgregarASquad(
    BuildContext context,
    String nombreUsuario,
    String username,
  ) {
    final idUsuario = _idUsuario;
    if (idUsuario == null || idUsuario.isEmpty) {
      _mostrarError('No se pudo identificar al usuario.');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _BottomSheetAgregarASquad(
          nombreUsuario: nombreUsuario,
          idUsuario: idUsuario,
        ),
      ),
    );
  }

  void _abrirVisualizadorAvatar(BuildContext context, String avatar) {
    showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _VisualizadorAvatar(url: avatar),
    );
  }

  Widget _buildActionButton() {
    if (_estado == EstadoRelacionUsuario.amigo) {
      return const SizedBox.shrink();
    }

    late final String texto;
    late final IconData icono;
    late final bool esSolido;
    Color bordeColor = ColoresApp.principalMarca;
    Color textColor = Colors.white;
    Color? fillColor = ColoresApp.principalMarca;

    switch (_estado) {
      case EstadoRelacionUsuario.ninguno:
        texto = 'Agregar amigo';
        icono = CupertinoIcons.person_add;
        esSolido = true;
        break;
      case EstadoRelacionUsuario.solicitudRecibida:
        texto = 'Aceptar solicitud';
        icono = CupertinoIcons.checkmark_circle_fill;
        esSolido = true;
        break;
      case EstadoRelacionUsuario.solicitudEnviada:
        texto = 'Cancelar solicitud';
        icono = CupertinoIcons.xmark_circle;
        esSolido = false;
        textColor = ColoresApp.principalMarca;
        fillColor = Colors.transparent;
        break;
      case EstadoRelacionUsuario.amigo:
        return const SizedBox.shrink();
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      color: esSolido ? fillColor : null,
      borderRadius: BorderRadius.circular(50),
      onPressed: _procesando ? null : _onAccionAmistad,
      minimumSize: Size(0, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: bordeColor, width: 2),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: _procesando
            ? Center(child: CupertinoActivityIndicator(color: textColor))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 20, color: textColor),
                  const SizedBox(width: 8),
                  Text(
                    texto,
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EnlaceRedMinimal extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool habilitado;
  final VoidCallback? onTap;

  const _EnlaceRedMinimal({
    required this.icono,
    required this.etiqueta,
    this.habilitado = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorIcono = habilitado
        ? ColoresApp.principalMarca
        : ColoresApp.textoSecundario.withValues(alpha: 0.35);
    final colorTexto = habilitado
        ? ColoresApp.textoSecundario
        : ColoresApp.textoSecundario.withValues(alpha: 0.35);

    return Opacity(
      opacity: habilitado ? 1 : 0.55,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: habilitado ? onTap : null,
        child: Column(
          children: [
            FaIcon(icono, color: colorIcono, size: 22),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetAgregarASquad extends StatefulWidget {
  final String nombreUsuario;
  final String idUsuario;

  const _BottomSheetAgregarASquad({
    required this.nombreUsuario,
    required this.idUsuario,
  });

  @override
  State<_BottomSheetAgregarASquad> createState() =>
      _BottomSheetAgregarASquadState();
}

enum _EstadoFilaSquadInvitacion { miembro, pendiente, disponible }

class _FilaSquadInvitacion {
  final SquadResumen squad;
  final _EstadoFilaSquadInvitacion estado;

  const _FilaSquadInvitacion(this.squad, this.estado);
}

class _BottomSheetAgregarASquadState extends State<_BottomSheetAgregarASquad> {
  final ServicioSquads _srv = ServicioSquads();
  List<_FilaSquadInvitacion> _filas = const [];
  bool _cargando = true;
  final Set<String> _invitando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final mios = await _srv.misSquads();
    final invitables = mios.where((s) => s.puedeInvitar).toList();
    final filas = <_FilaSquadInvitacion>[];
    for (final s in invitables) {
      final det = await _srv.detalle(s.idGrupo);
      final esMiembro =
          det?.miembros.any((m) => m.idUsuario == widget.idUsuario) ?? false;
      if (esMiembro) {
        filas.add(_FilaSquadInvitacion(s, _EstadoFilaSquadInvitacion.miembro));
        continue;
      }
      final pend = await _srv.listarPendientes(s.idGrupo);
      if (pend.any((m) => m.idUsuario == widget.idUsuario)) {
        filas.add(
          _FilaSquadInvitacion(s, _EstadoFilaSquadInvitacion.pendiente),
        );
      } else {
        filas.add(
          _FilaSquadInvitacion(s, _EstadoFilaSquadInvitacion.disponible),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _filas = filas;
      _cargando = false;
    });
  }

  Future<void> _invitar(SquadResumen s) async {
    setState(() => _invitando.add(s.idGrupo));
    final ok = await _srv.invitar(s.idGrupo, widget.idUsuario);
    if (!mounted) return;
    setState(() => _invitando.remove(s.idGrupo));
    if (ok) {
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Agregar a ${widget.nombreUsuario} a un squad',
            style: GoogleFonts.baloo2(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 20),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_filas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No tenés squads donde puedas invitar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            )
          else
            ..._filas.map((fila) {
              final s = fila.squad;
              final invitando = _invitando.contains(s.idGrupo);
              late final String etiquetaBoton;
              late final bool botonActivo;
              switch (fila.estado) {
                case _EstadoFilaSquadInvitacion.miembro:
                  etiquetaBoton = 'Miembro';
                  botonActivo = false;
                  break;
                case _EstadoFilaSquadInvitacion.pendiente:
                  etiquetaBoton = 'Invitación enviada';
                  botonActivo = false;
                  break;
                case _EstadoFilaSquadInvitacion.disponible:
                  etiquetaBoton = 'Invitar';
                  botonActivo = true;
                  break;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fila.estado == _EstadoFilaSquadInvitacion.miembro
                                ? 'Miembro de tu squad · ${s.nombre}'
                                : s.nombre,
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  fila.estado ==
                                      _EstadoFilaSquadInvitacion.miembro
                                  ? ColoresApp.principalMarca
                                  : ColoresApp.textoPrincipal,
                            ),
                          ),
                          if (fila.estado != _EstadoFilaSquadInvitacion.miembro)
                            Text(
                              '${s.cantidadMiembros} miembro${s.cantidadMiembros == 1 ? '' : 's'}',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: botonActivo
                          ? ColoresApp.principalMarca
                          : ColoresApp.fondoSuperficie,
                      borderRadius: BorderRadius.circular(50),
                      minimumSize: Size.zero,
                      onPressed: (invitando || !botonActivo)
                          ? null
                          : () => _invitar(s),
                      child: invitando
                          ? const CupertinoActivityIndicator()
                          : Text(
                              etiquetaBoton,
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: botonActivo
                                    ? Colors.white
                                    : ColoresApp.textoSecundario,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _VisualizadorAvatar extends StatelessWidget {
  final String url;

  const _VisualizadorAvatar({required this.url});

  bool _esAsset(String u) => u.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.88,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                child: _esAsset(url)
                    ? Image.asset(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _errorWidget(),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => _errorWidget(),
                      ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget() => Container(
    color: ColoresApp.fondoSuperficie,
    alignment: Alignment.center,
    child: Icon(
      CupertinoIcons.person_fill,
      size: 70,
      color: ColoresApp.textoSecundario,
    ),
  );
}
