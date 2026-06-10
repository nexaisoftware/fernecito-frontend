library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/comprimir_imagen_storage.dart';
import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/servicio_squads.dart';
import '../core/supabase_client.dart';
import '../models/social.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/perfil_squad_ui.dart';
import '../widgets/sheet_invitar_miembros_squad.dart';
import '../widgets/social_ui.dart';
import 'pantalla_perfil_usuarios.dart';

class PantallaMisSquads extends StatefulWidget {
  final Map<String, dynamic> squad;

  const PantallaMisSquads({
    super.key,
    required this.squad,
  });

  @override
  State<PantallaMisSquads> createState() => _PantallaMisSquadsState();
}

class _PantallaMisSquadsState extends State<PantallaMisSquads> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _vibeCtrl;

  bool _editNombre = false;
  bool _editDescripcion = false;
  bool _editVibe = false;
  bool _miembrosExpandidos = false;

  late String _idGrupo;
  String _username = '';
  List<MiembroSquad> _miembros = const [];
  Set<String> _idsAmigos = {};
  String? _bannerUrl;
  String? _bannerCacheKey;
  String _ubicacion = '';
  bool _puedeAdministrar = false;
  bool _soyMiembroAceptado = false;
  List<MiembroSquad> _pendientes = const [];
  bool _cargando = true;
  bool _subiendoBanner = false;

  final ImagePicker _picker = ImagePicker();
  final ServicioSquads _srv = ServicioSquads();
  final ServicioPerfilUsuario _srvPerfil = ServicioPerfilUsuario();

  @override
  void initState() {
    super.initState();
    _idGrupo = (widget.squad['id_grupo'] ?? widget.squad['id_squad'])
            ?.toString() ??
        '';
    _username = _conArroba(widget.squad['username'] as String? ?? '');

    _nombreCtrl = TextEditingController(
        text: (widget.squad['nombre'] ?? widget.squad['nombre_squad'])
                as String? ??
            '');
    _descripcionCtrl =
        TextEditingController(text: widget.squad['descripcion'] as String? ?? '');
    _vibeCtrl =
        TextEditingController(text: widget.squad['vibe'] as String? ?? '');

    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _vibeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────── DATA LOADING ────────────────────────────────

  Future<void> _cargarDatos() async {
    if (_idGrupo.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final detalleFuture = _srv.detalle(_idGrupo);
    final amistadesFuture = ServicioAmigos().listar();
    final detalle = await detalleFuture;
    final amistades = await amistadesFuture;
    if (!mounted) return;
    if (detalle == null) {
      setState(() => _cargando = false);
      _mostrarError('No se pudo cargar el squad.');
      return;
    }
    final pendientes = detalle.puedeAdministrar(ServicioSupabase().usuarioActual?.id)
        ? await _srv.listarPendientes(_idGrupo)
        : const <MiembroSquad>[];
    if (!mounted) return;

    var ubicacion = '';
    if (detalle.miembros.isNotEmpty) {
      final lider = detalle.miembros.where((m) => m.esLider).firstOrNull ??
          detalle.miembros.first;
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

    setState(() {
      _miembros = detalle.miembros;
      _idsAmigos = amistades.amigos.map((a) => a.idUsuario).toSet();
      _puedeAdministrar =
          detalle.puedeAdministrar(ServicioSupabase().usuarioActual?.id);
      _soyMiembroAceptado = detalle.soyMiembroAceptado;
      _pendientes = pendientes;
      _bannerUrl = detalle.portadaUrl;
      _bannerCacheKey = detalle.portadaCacheKey;
      _ubicacion = ubicacion;
      _nombreCtrl.text = detalle.nombre;
      _descripcionCtrl.text = detalle.descripcion ?? '';
      _vibeCtrl.text = detalle.vibe ?? '';
      final u = _conArroba(detalle.username ?? '');
      if (u.isNotEmpty) _username = u;
      _cargando = false;
    });
  }

  static String _conArroba(String username) {
    final u = username.trim();
    if (u.isEmpty) return '';
    return u.startsWith('@') ? u : '@$u';
  }

  Future<void> _recargarMiembros() async {
    final detalle = await _srv.detalle(_idGrupo);
    if (mounted && detalle != null) {
      setState(() => _miembros = detalle.miembros);
    }
  }

  // ─────────────────────────── WRITE OPERATIONS ────────────────────────────

  Future<void> _guardarNombre() async {
    final valor = _nombreCtrl.text.trim();
    if (valor.isEmpty) {
      _mostrarError('El nombre no puede estar vacío.');
      return;
    }
    final ok = await _srv.editar(_idGrupo, nombre: valor);
    if (ok) {
      _mostrarExito('Nombre actualizado.');
    } else {
      _mostrarError('No se pudo guardar el nombre.');
    }
  }

  Future<void> _guardarDescripcion() async {
    final valor = _descripcionCtrl.text.trim();
    final ok = await _srv.editar(_idGrupo, descripcion: valor);
    if (ok) {
      _mostrarExito('Descripción actualizada.');
    } else {
      _mostrarError('No se pudo guardar la descripción.');
    }
  }

  Future<void> _guardarVibe() async {
    final valor = _vibeCtrl.text.trim();
    final ok = await _srv.editar(_idGrupo, vibe: valor);
    if (ok) {
      _mostrarExito('Vibe actualizado.');
    } else {
      _mostrarError('No se pudo guardar el vibe.');
    }
  }

  Future<void> _subirBanner(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (xfile == null || !mounted) return;

      setState(() => _subiendoBanner = true);

      final comprimida = await comprimirDesdeXFile(
        xfile,
        perfil: PerfilImagenStorage.portadaSquad,
      );

      final path = await _srv.subirPortada(
        _idGrupo,
        comprimida.bytes,
        ext: comprimida.extension,
      );
      if (path == null) throw Exception('No se pudo subir el banner.');
      await _srv.editar(_idGrupo, urlPortada: path);

      if (mounted) {
        final token = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          _bannerUrl = ServicioSupabase().urlPortadaSquadDisplay(
            path,
            version: token,
          );
          _bannerCacheKey = _bannerUrl;
        });
      }

      await _cargarDatos();

      if (mounted) _mostrarExito('Banner actualizado.');
    } catch (e) {
      if (mounted) _mostrarError('Error al subir banner: $e');
    } finally {
      if (mounted) setState(() => _subiendoBanner = false);
    }
  }

  Future<void> _quitarMiembro(String idUsuario) async {
    final ok = await _srv.expulsar(_idGrupo, idUsuario);
    if (ok) {
      await _recargarMiembros();
    } else if (mounted) {
      _mostrarError('No se pudo quitar al miembro.');
    }
  }

  Future<void> _eliminarSquad() async {
    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Eliminar squad'),
        content: const Text(
            '¿Estás seguro? Esta acción no se puede deshacer y eliminará el squad para todos.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final ok = await _srv.eliminar(_idGrupo);
    if (ok) {
      if (mounted) Navigator.of(context).pop(true);
    } else if (mounted) {
      _mostrarError('No se pudo eliminar el squad.');
    }
  }

  // ─────────────────────────── UI HELPERS ──────────────────────────────────

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

  void _mostrarExito(String msg) {
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Listo'),
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

  void _mostrarOpcionesBanner() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          '¿Cómo querés cambiar el banner?',
          style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, color: ColoresApp.principalMarca),
                const SizedBox(width: 12),
                Text(
                  'Tomar foto',
                  style: GoogleFonts.baloo2(
                      fontSize: 16, color: ColoresApp.principalMarca),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _subirBanner(ImageSource.camera);
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: ColoresApp.principalMarca),
                const SizedBox(width: 12),
                Text(
                  'Subir desde galería',
                  style: GoogleFonts.baloo2(
                      fontSize: 16, color: ColoresApp.principalMarca),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _subirBanner(ImageSource.gallery);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancelar', style: GoogleFonts.baloo2(fontSize: 16)),
        ),
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
    final usuario = {
      'id_usuario': m.idUsuario,
      'avatar': m.avatarUrl ?? '',
      'nombre': m.nombre,
      'username': '@${m.username}',
      'estado': m.estado ?? '',
      'instagram_url': m.instagramUrl ?? '',
      'tiktok_url': m.tiktokUrl ?? '',
      'perfil_publico': m.perfilPublico,
    };
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: usuario,
          estadoRelacion: esAmigo
              ? EstadoRelacionUsuario.amigo
              : EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }

  Future<void> _confirmarQuitarMiembro(MiembroSquad m) async {
    final username = '@${m.username}';
    final nombreSquad =
        _nombreCtrl.text.trim().isEmpty ? 'Mi squad' : _nombreCtrl.text.trim();
    final confirmado = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Quitar miembro'),
        content:
            Text('¿Estás seguro que deseas eliminar a $username de $nombreSquad?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado == true && mounted) {
      await _quitarMiembro(m.idUsuario);
    }
  }

  Future<void> _agregarMiembros() async {
    if (!_puedeAdministrar) return;
    final yaEnSquad = {
      ..._miembros.map((m) => m.idUsuario),
      ..._pendientes.map((m) => m.idUsuario),
    };
    final seleccionados = await showInvitarMiembrosSquadSheet(
      context: context,
      idGrupo: _idGrupo,
      idsYaEnSquad: yaEnSquad,
    );
    if (seleccionados == null || seleccionados.isEmpty || !mounted) return;
    final fallos = await invitarIdsASquad(_idGrupo, seleccionados);
    if (!mounted) return;
    await _cargarDatos();
    if (fallos == 0) {
      _mostrarExito('Invitaciones enviadas.');
    } else {
      _mostrarError('No se pudieron enviar $fallos invitación(es).');
    }
  }

  Future<void> _aprobarPendiente(String idUsuario, {required bool aceptar}) async {
    final ok = await _srv.aprobarMiembro(_idGrupo, idUsuario, aceptar: aceptar);
    if (ok) {
      await _cargarDatos();
    } else if (mounted) {
      _mostrarError('No se pudo completar la acción.');
    }
  }

  Future<void> _cancelarInvitacion(String idUsuario) async {
    final ok = await _srv.expulsar(_idGrupo, idUsuario);
    if (ok) {
      await _cargarDatos();
      if (mounted) _mostrarExito('Invitación cancelada.');
    } else if (mounted) {
      _mostrarError('No se pudo cancelar la invitación.');
    }
  }

  Widget _filaPendiente(MiembroSquad p) {
    final esPedido = p.esPedidoUnion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardSuperficieSocial(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  Text(
                    '@${p.username}',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                  if (!esPedido) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Invitación enviada · esperando respuesta',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (esPedido) ...[
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: ColoresApp.principalMarca,
                borderRadius: BorderRadius.circular(50),
                onPressed: () => _aprobarPendiente(p.idUsuario, aceptar: true),
                child: Text(
                  'Aceptar',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: () => _aprobarPendiente(p.idUsuario, aceptar: false),
                child: Text(
                  'Rechazar',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ),
            ] else
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: () => _cancelarInvitacion(p.idUsuario),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoSecundario,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleMiembros() {
    setState(() => _miembrosExpandidos = !_miembrosExpandidos);
  }

  Widget _buildTituloHero() {
    if (_editNombre) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _nombreCtrl,
                textAlign: TextAlign.center,
                autofocus: true,
                style: SquadTituloHero.estiloHero,
                placeholder: 'Nombre del squad',
                placeholderStyle: GoogleFonts.baloo2(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white54,
                ),
                decoration: null,
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: ColoresApp.principalMarca,
              borderRadius: BorderRadius.circular(18),
              onPressed: () async {
                setState(() => _editNombre = false);
                await _guardarNombre();
              },
              child: Text(
                'OK',
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _soyMiembroAceptado ? () => setState(() => _editNombre = true) : null,
      child: SquadTituloHero(
        texto: _nombreCtrl.text.trim().isEmpty
            ? 'Nombre del squad'
            : _nombreCtrl.text.trim(),
      ),
    );
  }

  Widget _editorVibeBanner() {
    if (_editVibe) {
      return Column(
        children: [
          CupertinoTextField(
            controller: _vibeCtrl,
            autofocus: true,
            maxLength: 50,
            textAlign: TextAlign.center,
            placeholder: 'Ej: Previa los viernes',
            style: GoogleFonts.baloo2(fontSize: 13, color: Colors.white),
            placeholderStyle: GoogleFonts.baloo2(
              fontSize: 13,
              color: Colors.white54,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: ColoresApp.principalMarca,
            borderRadius: BorderRadius.circular(18),
            onPressed: () async {
              setState(() => _editVibe = false);
              await _guardarVibe();
            },
            child: Text(
              'Guardar vibe',
              style: GoogleFonts.baloo2(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    final vibe = _vibeCtrl.text.trim();
    if (vibe.isEmpty) {
      if (!_soyMiembroAceptado) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BurbujaEstado(
            texto: '',
            fontSize: 13,
            ajustarAnchoAlTexto: true,
            maxLines: 2,
          ),
        );
      }
      return GestureDetector(
        onTap: () => setState(() => _editVibe = true),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          child: BurbujaEstado(
            texto: '',
            fontSize: 13,
            ajustarAnchoAlTexto: true,
            maxLines: 2,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _soyMiembroAceptado ? () => setState(() => _editVibe = true) : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        child: BurbujaEstado(
          texto: vibe,
          fontSize: 13,
          ajustarAnchoAlTexto: true,
          maxLines: 2,
        ),
      ),
    );
  }

  Widget _editorDescripcion() {
    if (_editDescripcion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoTextField(
            controller: _descripcionCtrl,
            maxLines: 4,
            autofocus: true,
            placeholder: 'De qué va tu squad...',
            style: GoogleFonts.baloo2(
              fontSize: 13,
              color: ColoresApp.textoPrincipal,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresApp.fondoPrincipal.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColoresApp.principalMarca.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: ColoresApp.principalMarca,
            borderRadius: BorderRadius.circular(18),
            onPressed: () async {
              setState(() => _editDescripcion = false);
              await _guardarDescripcion();
            },
            child: Text(
              'Guardar',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    final txt = _descripcionCtrl.text.trim();
    return GestureDetector(
      onTap: _soyMiembroAceptado
          ? () => setState(() => _editDescripcion = true)
          : null,
      child: Text(
        txt.isEmpty
            ? 'Tocá para describir tu squad.'
            : txt,
        style: GoogleFonts.baloo2(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ColoresApp.textoSecundario,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _botonQuitarMiembro(MiembroSquad m) {
    return GestureDetector(
      onTap: () => _confirmarQuitarMiembro(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: ColoresApp.peligroMarca.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          'Quitar',
          style: GoogleFonts.baloo2(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColoresApp.peligroMarca,
          ),
        ),
      ),
    );
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
                imageUrl: _bannerUrl,
                imageCacheKey: _bannerCacheKey,
                subiendo: _subiendoBanner,
                onBannerTap: _soyMiembroAceptado ? _mostrarOpcionesBanner : null,
                topBar: SquadBotonVolver(
                  onTap: () => Navigator.of(context).pop(),
                  trailing: _soyMiembroAceptado
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: _mostrarOpcionesBanner,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.38),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.pencil,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        )
                      : null,
                ),
                usernameBadge: _username.isNotEmpty
                    ? SquadBadgeUsername(username: _username)
                    : null,
                title: _buildTituloHero(),
                miembros: _miembros,
                miembrosExpandidos: _miembrosExpandidos,
                onToggleMiembros: _toggleMiembros,
                onMiembroTap: _abrirPerfilMiembro,
                miembroMostrarCandado: _miembroMostrarCandado,
                trailingBuilder: (m) {
                  if (!_puedeAdministrar || m.esLider) return null;
                  return _botonQuitarMiembro(m);
                },
                vibe: !_miembrosExpandidos
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _editorVibeBanner(),
                      )
                    : null,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SquadCardDescripcion(
                    texto: _descripcionCtrl.text.trim(),
                    editor: _editorDescripcion(),
                    onEditar: _soyMiembroAceptado && !_editDescripcion
                        ? () => setState(() => _editDescripcion = true)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  SquadBadgeUbicacion(ubicacion: _ubicacion),
                  if (_puedeAdministrar && _pendientes.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Pendientes',
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._pendientes.map(_filaPendiente),
                  ],
                  const SizedBox(height: 20),
                  if (_puedeAdministrar)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: ColoresApp.fondoSuperficie.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                      onPressed: _agregarMiembros,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.person_add,
                            size: 18,
                            color: ColoresApp.principalMarca,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Invitar miembros',
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_puedeAdministrar) ...[
                    const SizedBox(height: 12),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      borderRadius: BorderRadius.circular(18),
                      onPressed: _eliminarSquad,
                      child: Text(
                        'Eliminar squad',
                        style: GoogleFonts.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.peligroMarca,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: bottomPad),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
