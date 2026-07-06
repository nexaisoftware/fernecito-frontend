/// Bottom sheet con listados de actividad del perfil (amigos / squads / eventos / locales).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../PANTALLAS/pantalla_local_perfil.dart';
import '../PANTALLAS/pantalla_perfil_squads.dart';
import '../PANTALLAS/pantalla_perfil_usuarios.dart';
import '../core/constants.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/supabase_client.dart';
import 'avatar_local.dart';
import 'avatar_usuario.dart';
import 'fernecito_loader.dart';

Future<void> mostrarPerfilActividadSheet(
  BuildContext context, {
  required String idUsuario,
  required PerfilActividadTipo tipo,
  required String titulo,
}) {
  // Navigator de la pantalla actual (tab / push). El sheet va en el root para
  // quedar por encima de la navbar glass del home.
  final navigatorPantalla = Navigator.of(context);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final altura = MediaQuery.sizeOf(ctx).height * 0.62;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: double.infinity,
            height: altura,
            child: _PerfilActividadSheet(
              idUsuario: idUsuario,
              tipo: tipo,
              titulo: titulo,
              navigatorPantalla: navigatorPantalla,
            ),
          ),
        ),
      );
    },
  );
}

class _PerfilActividadSheet extends StatefulWidget {
  const _PerfilActividadSheet({
    required this.idUsuario,
    required this.tipo,
    required this.titulo,
    required this.navigatorPantalla,
  });

  final String idUsuario;
  final PerfilActividadTipo tipo;
  final String titulo;
  final NavigatorState navigatorPantalla;

  @override
  State<_PerfilActividadSheet> createState() => _PerfilActividadSheetState();
}

class _PerfilActividadSheetState extends State<_PerfilActividadSheet> {
  final ServicioPerfilUsuario _srv = ServicioPerfilUsuario();
  List<Map<String, dynamic>> _items = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await _srv.listarActividad(
      idUsuario: widget.idUsuario,
      tipo: widget.tipo,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _cargando = false;
    });
  }

  void _cerrarSheet() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  String _avatarUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http')) return path;
    return ServicioSupabase().urlAvatar(path) ?? '';
  }

  String _avatarLocalUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http')) return path;
    return ServicioSupabase().cliente.storage
        .from('avatars_locales')
        .getPublicUrl(path);
  }

  String _arroba(String username) {
    final u = username.trim();
    if (u.isEmpty) return '@usuario';
    return u.startsWith('@') ? u : '@$u';
  }

  EstadoRelacionUsuario _estadoDesdeAmistad(String? estado) {
    switch (estado) {
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

  void _abrirPerfilAmigo(Map<String, dynamic> item) {
    final id = item['id_usuario']?.toString() ?? '';
    if (id.isEmpty) return;
    final username = item['username']?.toString() ?? '';
    final nombre = item['nombre']?.toString().trim();
    _cerrarSheet();
    widget.navigatorPantalla.push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': id,
            'username': _arroba(username),
            'nombre': (nombre != null && nombre.isNotEmpty) ? nombre : username,
            'avatar': _avatarUrl(item['foto_perfil_url']?.toString()),
            'estado_amistad': item['estado_amistad']?.toString() ?? 'ninguno',
          },
          estadoRelacion: _estadoDesdeAmistad(
            item['estado_amistad']?.toString(),
          ),
        ),
      ),
    );
  }

  void _abrirPerfilLocal(Map<String, dynamic> item) {
    final id = item['id_local']?.toString() ?? '';
    if (id.isEmpty) return;
    _cerrarSheet();
    widget.navigatorPantalla.push(
      CupertinoPageRoute(
        builder: (_) => PantallaLocalPerfil(
          idLocal: id,
          nombreLocal: item['nombre_local']?.toString() ?? 'Local',
          avatarUrl: _avatarLocalUrl(item['foto_perfil_url']?.toString()),
        ),
      ),
    );
  }

  EstadoRelacionSquad _estadoSquadDesde(String? miEstado) {
    switch (miEstado) {
      case 'aceptado':
        return EstadoRelacionSquad.miembro;
      case 'pendiente':
        return EstadoRelacionSquad.solicitudPendiente;
      default:
        return EstadoRelacionSquad.ninguno;
    }
  }

  void _abrirPerfilSquad(Map<String, dynamic> item) {
    final id = item['id_grupo']?.toString() ?? '';
    if (id.isEmpty) return;
    final nombre = item['nombre_grupo']?.toString().trim();
    final username = item['username']?.toString() ?? '';
    final portada = ServicioSupabase().urlPortadaSquadDisplay(
      item['url_portada']?.toString(),
      fallbackSeed: id,
    );
    _cerrarSheet();
    widget.navigatorPantalla.push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilSquads(
          squad: {
            'id_grupo': id,
            'id_squad': id,
            'nombre': nombre?.isNotEmpty == true ? nombre : 'Squad',
            'nombre_squad': nombre,
            'username': _arroba(username),
            'avatar': portada ?? '',
            'banner_url': portada,
            'vibe': item['vibe_grupo']?.toString() ?? '',
            'estado': item['vibe_grupo']?.toString() ?? '',
            'es_publico': item['es_publico'] == true,
            'mi_estado': item['mi_estado']?.toString() ?? 'ninguno',
            'miembros': item['cantidad_miembros'] ?? 0,
          },
          estadoRelacion: _estadoSquadDesde(item['mi_estado']?.toString()),
        ),
      ),
    );
  }

  String get _vacioTexto {
    switch (widget.tipo) {
      case PerfilActividadTipo.amigos:
        return 'Todavía no tiene amigos para mostrar';
      case PerfilActividadTipo.squads:
        return 'Todavía no es miembro de squads';
      case PerfilActividadTipo.eventos:
        return 'Todavía no asistió a eventos';
      case PerfilActividadTipo.locales:
        return 'Todavía no visitó locales';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: SuperficiesApp.bottomSheet(topRadius: 20),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ColoresApp.textoSecundario.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _cerrarSheet,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 24,
                      color: ColoresApp.textoSecundario.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _cargando
                  ? const FernecitoLoaderCentro(size: 28)
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _vacioTexto,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: ColoresApp.textoSecundario
                                .withValues(alpha: 0.12),
                          ),
                          itemBuilder: (context, index) {
                            return _filaItem(_items[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaItem(Map<String, dynamic> item) {
    switch (widget.tipo) {
      case PerfilActividadTipo.amigos:
        final nombre =
            item['nombre']?.toString().trim().isNotEmpty == true
                ? item['nombre'].toString()
                : item['username']?.toString() ?? 'Usuario';
        final avatar = _avatarUrl(item['foto_perfil_url']?.toString());
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          onPressed: () => _abrirPerfilAmigo(item),
          child: Row(
            children: [
              AvatarUsuario(avatar: avatar, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.55),
              ),
            ],
          ),
        );
      case PerfilActividadTipo.squads:
        final nombre = item['nombre_grupo']?.toString().trim().isNotEmpty == true
            ? item['nombre_grupo'].toString()
            : 'Squad';
        final portada = ServicioSupabase().urlPortadaSquadDisplay(
          item['url_portada']?.toString(),
          fallbackSeed: item['id_grupo']?.toString(),
        );
        final miembros = item['cantidad_miembros'];
        final cantidadMiembros =
            miembros is num ? miembros.toInt() : int.tryParse('$miembros') ?? 0;
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          onPressed: () => _abrirPerfilSquad(item),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: portada != null && portada.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: portada,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _placeholderSquad(),
                          placeholder: (_, _) => _placeholderSquad(),
                        )
                      : _placeholderSquad(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                    if (cantidadMiembros > 0)
                      Text(
                        '$cantidadMiembros miembro${cantidadMiembros == 1 ? '' : 's'}',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.55),
              ),
            ],
          ),
        );
      case PerfilActividadTipo.eventos:
        final titulo = item['titulo']?.toString().trim().isNotEmpty == true
            ? item['titulo'].toString()
            : 'Evento';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.ticket_fill,
                size: 16,
                color: ColoresApp.principalMarca.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
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
      case PerfilActividadTipo.locales:
        final nombre = item['nombre_local']?.toString().trim().isNotEmpty == true
            ? item['nombre_local'].toString()
            : 'Local';
        final avatarLocal = _avatarLocalUrl(item['foto_perfil_url']?.toString());
        final esPionero = item['es_pionero'] == true;
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          onPressed: () => _abrirPerfilLocal(item),
          child: Row(
            children: [
              AvatarLocal(
                imageUrl: avatarLocal,
                size: 40,
                esPionero: esPionero,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.55),
              ),
            ],
          ),
        );
    }
  }

  Widget _placeholderSquad() {
    return ColoredBox(
      color: ColoresApp.fondoSuperficie,
      child: Icon(
        CupertinoIcons.person_3_fill,
        size: 18,
        color: ColoresApp.principalMarca.withValues(alpha: 0.75),
      ),
    );
  }
}
