library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/rompehielo_navegacion.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../models/rompehielo.dart';
import '../models/social.dart';
import '../widgets/boton_rompehielo.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/perfil_squad_ui.dart';
import 'pantalla_perfil_usuarios.dart';
import 'pantalla_rompehielo.dart' show TipoContraparte;

enum EstadoRelacionSquad {
  ninguno,
  solicitudEnviada,
  solicitudPendiente,
  miembro,
}

class PantallaPerfilSquads extends StatefulWidget {
  final Map<String, dynamic> squad;
  final EstadoRelacionSquad estadoRelacion;
  final RompehieloOrigen rompehieloOrigen;
  final String? rompehieloIdEvento;
  final String? rompehieloNombreEvento;

  const PantallaPerfilSquads({
    super.key,
    required this.squad,
    required this.estadoRelacion,
    this.rompehieloOrigen = RompehieloOrigen.perfil,
    this.rompehieloIdEvento,
    this.rompehieloNombreEvento,
  });

  @override
  State<PantallaPerfilSquads> createState() => _PantallaPerfilSquadsState();
}

class _PantallaPerfilSquadsState extends State<PantallaPerfilSquads> {
  late EstadoRelacionSquad _estado;
  bool _miembrosExpandidos = false;

  final ServicioSquads _srv = ServicioSquads();
  final ServicioPerfilUsuario _srvPerfil = ServicioPerfilUsuario();
  RompehieloEstado? _rompehieloEstado;
  late String _idGrupo;
  SquadDetalle? _detalle;
  List<MiembroSquad> _miembros = const [];
  Set<String> _idsAmigos = {};
  String _ubicacion = '';
  bool _cargando = true;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _estado = widget.estadoRelacion;
    _idGrupo = (widget.squad['id_grupo'] ?? widget.squad['id_squad'])
            ?.toString() ??
        '';
    _cargar();
  }

  Future<void> _cargar() async {
    if (_idGrupo.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final detFuture = _srv.detalle(_idGrupo);
    final amistadesFuture = ServicioAmigos().listar();
    final det = await detFuture;
    final amistades = await amistadesFuture;
    if (!mounted) return;

    var ubicacion = '';
    if (det != null && det.miembros.isNotEmpty) {
      final lider = det.miembros.where((m) => m.esLider).firstOrNull ??
          det.miembros.first;
      final perf = await _srvPerfil.detalle(lider.idUsuario);
      if (perf != null) {
        final ciudad = (perf['ciudad'] as String?)?.trim() ?? '';
        final prov = (perf['provincia'] as String?)?.trim() ?? '';
        if (ciudad.isNotEmpty && prov.isNotEmpty) {
          ubicacion = '$ciudad, $prov';
        } else if (ciudad.isNotEmpty) {
          ubicacion = ciudad;
        } else if (prov.isNotEmpty) {
          ubicacion = prov;
        }
      }
    }

    final activos = await listarInvolucramientosRompehielo(
      otroTipo: 'squad',
      otroId: _idGrupo,
    );
    if (!mounted) return;
    setState(() {
      _detalle = det;
      _miembros = det?.miembros ?? const [];
      _idsAmigos = amistades.amigos.map((a) => a.idUsuario).toSet();
      _ubicacion = ubicacion;
      if (det != null) _estado = _estadoDesde(det.miEstado);
      _rompehieloEstado = mejorInvolucramiento(activos)?.estado;
      _cargando = false;
    });
  }

  EstadoRelacionSquad _estadoDesde(String miEstado) {
    switch (miEstado) {
      case 'aceptado':
        return EstadoRelacionSquad.miembro;
      case 'pendiente':
        return widget.estadoRelacion == EstadoRelacionSquad.solicitudPendiente
            ? EstadoRelacionSquad.solicitudPendiente
            : EstadoRelacionSquad.solicitudEnviada;
      default:
        return EstadoRelacionSquad.ninguno;
    }
  }

  Future<void> _onAccionPrincipal() async {
    if (_procesando || _idGrupo.isEmpty) return;
    setState(() => _procesando = true);
    var ok = false;
    switch (_estado) {
      case EstadoRelacionSquad.ninguno:
        final estado = await _srv.solicitarUnirse(_idGrupo);
        ok = estado != null;
        if (ok && mounted) {
          setState(() => _estado = estado == 'aceptado'
              ? EstadoRelacionSquad.miembro
              : EstadoRelacionSquad.solicitudEnviada);
        }
        break;
      case EstadoRelacionSquad.solicitudEnviada:
        ok = await _srv.salir(_idGrupo);
        if (ok && mounted) setState(() => _estado = EstadoRelacionSquad.ninguno);
        break;
      case EstadoRelacionSquad.solicitudPendiente:
        ok = await _srv.responderInvitacion(_idGrupo, aceptar: true);
        if (ok && mounted) setState(() => _estado = EstadoRelacionSquad.miembro);
        break;
      case EstadoRelacionSquad.miembro:
        ok = await _srv.salir(_idGrupo);
        if (ok && mounted) setState(() => _estado = EstadoRelacionSquad.ninguno);
        break;
    }
    if (mounted) {
      setState(() => _procesando = false);
      if (ok) {
        await _cargar();
      } else {
        _mostrarError('No se pudo completar la acción. Intentá de nuevo.');
      }
    }
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

  bool _miembroMostrarCandado(MiembroSquad m) =>
      PrivacidadPerfil.mostrarCandadoMiembroSquad(
        m,
        idsAmigos: _idsAmigos,
        miUid: ServicioSupabase().usuarioActual?.id,
      );

  void _abrirPerfilMiembro(MiembroSquad m) {
    final esAmigo = _idsAmigos.contains(m.idUsuario);
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': m.idUsuario,
            'username': '@${m.username}',
            'nombre': m.nombre,
            'avatar': m.avatarUrl ?? '',
            'estado': m.estado ?? '',
            'instagram_url': m.instagramUrl ?? '',
            'tiktok_url': m.tiktokUrl ?? '',
            'perfil_publico': m.perfilPublico,
          },
          estadoRelacion: esAmigo
              ? EstadoRelacionUsuario.amigo
              : EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }

  void _toggleMiembros() {
    setState(() => _miembrosExpandidos = !_miembrosExpandidos);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = squadPaddingInferior(context);
    final heroH = squadHeroAltura(context);

    if (_cargando) {
      return CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: Center(
          child: CupertinoActivityIndicator(
            color: ColoresApp.principalMarca,
            radius: 18,
          ),
        ),
      );
    }

    final squad = widget.squad;
    final nombre = _detalle?.nombre ?? (squad['nombre'] as String? ?? 'Squad');
    final descripcion = (_detalle?.descripcion?.trim().isNotEmpty ?? false)
        ? _detalle!.descripcion!.trim()
        : (squad['descripcion'] as String?)?.trim().isNotEmpty == true
            ? (squad['descripcion'] as String).trim()
            : 'Este squad todavía no tiene descripción.';
    final banner = _detalle?.portadaUrl ??
        ServicioSupabase().urlPortadaSquad(squad['avatar'] as String?) ??
        (squad['avatar'] as String? ?? '');
    final bannerCacheKey = _detalle?.portadaCacheKey;
    final vibe = (_detalle?.vibe?.trim().isNotEmpty ?? false)
        ? _detalle!.vibe!.trim()
        : ((squad['vibe'] as String?)?.trim() ?? '');

    final username = _detalle?.username?.trim() ?? '';

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SquadHeroZona(
                height: heroH,
                imageUrl: banner,
                imageCacheKey: bannerCacheKey,
                topBar: SquadBotonVolver(
                  onTap: () => Navigator.of(context).pop(),
                ),
                usernameBadge: username.isNotEmpty
                    ? SquadBadgeUsername(username: username)
                    : null,
                title: SquadTituloHero(texto: nombre),
                miembros: _miembros,
                miembrosExpandidos: _miembrosExpandidos,
                onToggleMiembros: _toggleMiembros,
                onMiembroTap: _abrirPerfilMiembro,
                miembroMostrarCandado: _miembroMostrarCandado,
                vibe: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: BurbujaEstado(
                    texto: vibe,
                    fontSize: 13,
                    ajustarAnchoAlTexto: true,
                    maxLines: 2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SquadCardDescripcion(texto: descripcion),
                  const SizedBox(height: 10),
                  SquadBadgeUbicacion(ubicacion: _ubicacion),
                  if (_estado != EstadoRelacionSquad.miembro) ...[
                    const SizedBox(height: 18),
                    BotonRompehielo(
                      nombre: nombre,
                      esEmisor: _rompehieloEstado?.debeResponder == true,
                      esSecundario:
                          _rompehieloEstado?.jerarquiaAlta == false,
                      onTap: () async {
                        final squadMap = Map<String, dynamic>.from(squad)
                          ..['nombre'] = nombre
                          ..['id_grupo'] = _idGrupo;
                        await abrirRompehielo(
                          context,
                          tipoContraparte: TipoContraparte.squad,
                          contraparte: squadMap,
                          origen: widget.rompehieloOrigen,
                          idEvento: widget.rompehieloIdEvento,
                          nombreEvento: widget.rompehieloNombreEvento,
                        );
                        if (mounted) {
                          final activos =
                              await listarInvolucramientosRompehielo(
                            otroTipo: 'squad',
                            otroId: _idGrupo,
                          );
                          if (mounted) {
                            setState(() {
                              _rompehieloEstado =
                                  mejorInvolucramiento(activos)?.estado;
                            });
                          }
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildActionButton(),
                  SizedBox(height: bottomPad),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    late final String texto;
    late final IconData icono;
    late final bool esSolido;
    var bordeColor = ColoresApp.principalMarca;
    var textColor = Colors.white;

    switch (_estado) {
      case EstadoRelacionSquad.ninguno:
        texto = 'Solicitar unirse';
        icono = CupertinoIcons.person_add;
        esSolido = true;
        break;
      case EstadoRelacionSquad.solicitudEnviada:
        texto = 'Cancelar solicitud';
        icono = CupertinoIcons.xmark_circle;
        esSolido = false;
        textColor = ColoresApp.principalMarca;
        break;
      case EstadoRelacionSquad.solicitudPendiente:
        texto = 'Aceptar invitación';
        icono = CupertinoIcons.checkmark_alt_circle_fill;
        esSolido = true;
        break;
      case EstadoRelacionSquad.miembro:
        texto = 'Abandonar squad';
        icono = CupertinoIcons.escape;
        esSolido = false;
        textColor = ColoresApp.peligroMarca;
        bordeColor = ColoresApp.peligroMarca;
        break;
    }

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14),
      color: esSolido ? bordeColor : ColoresApp.fondoSuperficie.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      onPressed: _procesando ? null : _onAccionPrincipal,
      child: _procesando
          ? CupertinoActivityIndicator(color: textColor)
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
    );
  }
}
