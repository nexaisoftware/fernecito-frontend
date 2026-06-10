/// Sheet para invitar personas a un squad (amigos + búsqueda global).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_squads.dart';
import '../models/social.dart';
import '../PANTALLAS/pantalla_perfil_usuarios.dart';
import 'social_ui.dart';

/// Devuelve los ids invitados si el usuario confirmó.
Future<Set<String>?> showInvitarMiembrosSquadSheet({
  required BuildContext context,
  required String idGrupo,
  required Set<String> idsYaEnSquad,
}) async {
  return showCupertinoModalPopup<Set<String>>(
    context: context,
    builder: (ctx) => _InvitarMiembrosSquadSheet(
      idGrupo: idGrupo,
      idsYaEnSquad: idsYaEnSquad,
    ),
  );
}

class _InvitarMiembrosSquadSheet extends StatefulWidget {
  final String idGrupo;
  final Set<String> idsYaEnSquad;

  const _InvitarMiembrosSquadSheet({
    required this.idGrupo,
    required this.idsYaEnSquad,
  });

  @override
  State<_InvitarMiembrosSquadSheet> createState() =>
      _InvitarMiembrosSquadSheetState();
}

class _InvitarMiembrosSquadSheetState extends State<_InvitarMiembrosSquadSheet> {
  final ServicioAmigos _srvAmigos = ServicioAmigos();
  final TextEditingController _busquedaCtrl = TextEditingController();

  List<Amigo> _amigos = const [];
  List<UsuarioBusqueda> _resultadosBusqueda = const [];
  final Set<String> _seleccionados = {};
  bool _cargandoAmigos = true;
  bool _buscando = false;
  String _ultimaQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarAmigos();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAmigos() async {
    final data = await _srvAmigos.listar();
    if (!mounted) return;
    setState(() {
      _amigos = data.amigos
          .where((a) => !widget.idsYaEnSquad.contains(a.idUsuario))
          .toList();
      _cargandoAmigos = false;
    });
  }

  Future<void> _buscar(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _resultadosBusqueda = const [];
        _ultimaQuery = '';
        _buscando = false;
      });
      return;
    }
    if (query == _ultimaQuery && _resultadosBusqueda.isNotEmpty) return;
    setState(() {
      _buscando = true;
      _ultimaQuery = query;
    });
    final res = await _srvAmigos.buscar(query);
    if (!mounted || _ultimaQuery != query) return;
    setState(() {
      _resultadosBusqueda = res
          .where((u) => !widget.idsYaEnSquad.contains(u.idUsuario))
          .toList();
      _buscando = false;
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mostrarBusqueda = _ultimaQuery.length >= 2;
    final candidatosBusqueda = _resultadosBusqueda;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Invitar al squad',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CupertinoSearchTextField(
              controller: _busquedaCtrl,
              placeholder: 'Buscar por @ o nombre',
              onChanged: _buscar,
              style: GoogleFonts.baloo2(fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _cargandoAmigos && !mostrarBusqueda
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CupertinoActivityIndicator(),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (_buscando)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CupertinoActivityIndicator()),
                        ),
                      if (mostrarBusqueda) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Text(
                            'Resultados',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ),
                        if (candidatosBusqueda.isEmpty && !_buscando)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Sin coincidencias',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                          ),
                        ...candidatosBusqueda.map(
                          (u) => _filaUsuario(
                            id: u.idUsuario,
                            nombre: u.nombre,
                            username: u.username,
                            avatarUrl: u.avatarUrl,
                            perfilPublico: u.perfilPublico,
                            esAmigo: u.estadoAmistad == 'amigo',
                            enBusqueda: true,
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Text(
                            'Tus amigos',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                        ),
                        if (_amigos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No tenés amigos para invitar o ya están en el squad.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                color: ColoresApp.textoSecundario,
                              ),
                            ),
                          ),
                        ..._amigos.map(
                          (a) => _filaUsuario(
                            id: a.idUsuario,
                            nombre: a.nombre,
                            username: a.username,
                            avatarUrl: a.avatarUrl,
                            perfilPublico: a.perfilPublico,
                            esAmigo: true,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: ColoresApp.principalMarca,
                borderRadius: BorderRadius.circular(50),
                onPressed: _seleccionados.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_seleccionados),
                child: Text(
                  _seleccionados.isEmpty
                      ? 'Seleccioná personas'
                      : 'Invitar (${_seleccionados.length})',
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirPerfil({
    required String id,
    required String nombre,
    required String username,
    required String? avatarUrl,
    required bool perfilPublico,
    required bool esAmigo,
  }) {
    final user = username.startsWith('@') ? username : '@$username';
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': id,
            'nombre': nombre,
            'username': user,
            'avatar': avatarUrl ?? '',
            'perfil_publico': perfilPublico,
          },
          estadoRelacion: esAmigo
              ? EstadoRelacionUsuario.amigo
              : EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }

  Widget _filaUsuario({
    required String id,
    required String nombre,
    required String username,
    required String? avatarUrl,
    required bool perfilPublico,
    required bool esAmigo,
    bool enBusqueda = false,
  }) {
    final marcado = _seleccionados.contains(id);
    final candado = enBusqueda
        ? PrivacidadPerfil.mostrarCandadoEnBusqueda(
            perfilPublico: perfilPublico,
          )
        : PrivacidadPerfil.mostrarCandadoPrivado(
            perfilPublico: perfilPublico,
            esAmigo: esAmigo,
          );
    final titulo = enBusqueda
        ? PrivacidadPerfil.nombreEnBusqueda(
            perfilPublico: perfilPublico,
            nombre: nombre,
          )
        : (candado ? PrivacidadPerfil.tituloPerfilPrivado : nombre);
    final user = username.startsWith('@') ? username : '@$username';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _abrirPerfil(
              id: id,
              nombre: nombre,
              username: username,
              avatarUrl: avatarUrl,
              perfilPublico: perfilPublico,
              esAmigo: esAmigo,
            ),
            child: AvatarSocialPrivacidad(
              url: avatarUrl ?? '',
              size: 44,
              mostrarCandado: candado,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _abrirPerfil(
                id: id,
                nombre: nombre,
                username: username,
                avatarUrl: avatarUrl,
                perfilPublico: perfilPublico,
                esAmigo: esAmigo,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  Text(
                    user,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => _toggle(id),
            child: Icon(
              marcado
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: marcado
                  ? ColoresApp.principalMarca
                  : ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Invita ids seleccionados; devuelve cantidad de fallos.
Future<int> invitarIdsASquad(String idGrupo, Iterable<String> ids) async {
  final srv = ServicioSquads();
  var fallos = 0;
  for (final id in ids) {
    final ok = await srv.invitar(idGrupo, id);
    if (!ok) fallos++;
  }
  return fallos;
}
