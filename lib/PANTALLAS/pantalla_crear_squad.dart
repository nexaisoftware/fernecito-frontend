library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/comprimir_imagen_storage.dart';
import '../core/constants.dart';
import '../core/privacidad_perfil.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_squads.dart';
import '../models/social.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/social_ui.dart';
import 'pantalla_perfil_usuarios.dart';

class _FilaInvitacion {
  final String id;
  final String nombre;
  final String username;
  final String? avatarUrl;
  final bool esAmigo;
  final bool perfilPublico;

  const _FilaInvitacion({
    required this.id,
    required this.nombre,
    required this.username,
    this.avatarUrl,
    this.esAmigo = false,
    this.perfilPublico = true,
  });

  factory _FilaInvitacion.desdeAmigo(Amigo a) => _FilaInvitacion(
        id: a.idUsuario,
        nombre: a.nombre,
        username: a.username,
        avatarUrl: a.avatarUrl,
        esAmigo: true,
        perfilPublico: a.perfilPublico,
      );

  factory _FilaInvitacion.desdeUsuario(UsuarioBusqueda u, {required bool esAmigo}) =>
      _FilaInvitacion(
        id: u.idUsuario,
        nombre: u.nombre,
        username: u.username,
        avatarUrl: u.avatarUrl,
        esAmigo: esAmigo,
        perfilPublico: u.perfilPublico,
      );
}

class PantallaCrearSquad extends StatefulWidget {
  const PantallaCrearSquad({super.key});

  @override
  State<PantallaCrearSquad> createState() => _PantallaCrearSquadState();
}

class _PantallaCrearSquadState extends State<PantallaCrearSquad> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _estadoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _buscarController = TextEditingController();

  final Set<String> _miembrosSeleccionados = <String>{};
  bool _usernameValidado = false;
  bool _validandoUsername = false;
  String? _usernameMsg;
  String? _usernameNormalizado;
  bool _creando = false;
  bool _esPublico = false;
  Uint8List? _bannerPreviewBytes;

  final ImagePicker _picker = ImagePicker();
  final ServicioSquads _srvSquads = ServicioSquads();
  final ServicioAmigos _srvAmigos = ServicioAmigos();

  List<Amigo> _amigos = const [];
  bool _cargandoAmigos = true;

  Timer? _debounceBusqueda;
  List<UsuarioBusqueda> _resultadosBusqueda = const [];
  bool _buscandoUsuarios = false;
  final Map<String, String> _labelPorId = <String, String>{};

  Set<String> get _idsAmigos => _amigos.map((a) => a.idUsuario).toSet();

  @override
  void initState() {
    super.initState();
    _cargarAmigos();
  }

  Future<void> _cargarAmigos() async {
    final data = await _srvAmigos.listar();
    if (mounted) {
      setState(() {
        _amigos = data.amigos;
        _cargandoAmigos = false;
      });
    }
  }

  Amigo? _amigoPorId(String id) {
    for (final a in _amigos) {
      if (a.idUsuario == id) return a;
    }
    return null;
  }

  @override
  void dispose() {
    _debounceBusqueda?.cancel();
    _usernameController.dispose();
    _nombreController.dispose();
    _estadoController.dispose();
    _descripcionController.dispose();
    _buscarController.dispose();
    super.dispose();
  }

  void _onBuscarCambiado(String q) {
    setState(() {});
    _debounceBusqueda?.cancel();
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _resultadosBusqueda = const [];
        _buscandoUsuarios = false;
      });
      return;
    }
    _debounceBusqueda = Timer(const Duration(milliseconds: 350), () {
      _ejecutarBusqueda(query);
    });
  }

  Future<void> _ejecutarBusqueda(String query) async {
    setState(() => _buscandoUsuarios = true);
    final res = await _srvAmigos.buscar(query);
    if (!mounted) return;
    final q = query.toLowerCase();
    final idsAmigos = _idsAmigos;
    res.sort((a, b) {
      final aAmigo = idsAmigos.contains(a.idUsuario) || a.estadoAmistad == 'amigo';
      final bAmigo = idsAmigos.contains(b.idUsuario) || b.estadoAmistad == 'amigo';
      if (aAmigo != bAmigo) return aAmigo ? -1 : 1;
      return _puntajeUsuario(b, q).compareTo(_puntajeUsuario(a, q));
    });
    setState(() {
      _resultadosBusqueda = res;
      _buscandoUsuarios = false;
    });
  }

  void _toggleSeleccion(String id, String label) {
    setState(() {
      if (_miembrosSeleccionados.contains(id)) {
        _miembrosSeleccionados.remove(id);
      } else {
        _miembrosSeleccionados.add(id);
        _labelPorId[id] = label;
      }
    });
  }

  bool _coincideTexto(String username, String nombre, String q) {
    if (q.isEmpty) return true;
    final user = username.toLowerCase();
    final nom = nombre.toLowerCase();
    return user.contains(q) || nom.contains(q);
  }

  List<Amigo> _amigosFiltrados() {
    final q = _buscarController.text.trim().toLowerCase();
    if (q.isEmpty) return List.from(_amigos);
    return _amigos
        .where((a) => _coincideTexto(a.username, a.nombre, q))
        .toList();
  }

  List<Amigo> _amigosOrdenadosPorCoincidencia() {
    final lista = _amigosFiltrados();
    final q = _buscarController.text.trim().toLowerCase();
    if (q.isEmpty) return lista;
    lista.sort((a, b) {
      return _puntajeAmigo(b, q).compareTo(_puntajeAmigo(a, q));
    });
    return lista;
  }

  int _puntajeAmigo(Amigo a, String q) {
    final user = a.username.toLowerCase();
    final nom = a.nombre.toLowerCase();
    var s = 0;
    if (user.startsWith(q)) s += 10;
    if (nom.startsWith(q)) s += 10;
    if (user.contains(q)) s += 5;
    if (nom.contains(q)) s += 5;
    return s;
  }

  int _puntajeUsuario(UsuarioBusqueda u, String q) {
    return _puntajeAmigo(
      Amigo(idUsuario: u.idUsuario, username: u.username, nombre: u.nombre),
      q,
    );
  }

  int _puntajeFila(_FilaInvitacion f, String q) {
    return _puntajeAmigo(
      Amigo(idUsuario: f.id, username: f.username, nombre: f.nombre),
      q,
    );
  }

  List<_FilaInvitacion> _filasAmigosEnBusqueda(String q) {
    final qLower = q.toLowerCase();
    final map = <String, _FilaInvitacion>{};
    for (final a in _amigosOrdenadosPorCoincidencia()) {
      map[a.idUsuario] = _FilaInvitacion.desdeAmigo(a);
    }
    for (final u in _resultadosBusqueda) {
      final esAmigo = _idsAmigos.contains(u.idUsuario) || u.estadoAmistad == 'amigo';
      if (!esAmigo) continue;
      if (!_coincideTexto(u.username, u.nombre, qLower)) continue;
      map.putIfAbsent(
        u.idUsuario,
        () => _FilaInvitacion.desdeUsuario(u, esAmigo: true),
      );
    }
    final list = map.values.toList();
    list.sort((a, b) => _puntajeFila(b, qLower).compareTo(_puntajeFila(a, qLower)));
    return list;
  }

  List<_FilaInvitacion> _filasOtrosEnBusqueda(String q) {
    final qLower = q.toLowerCase();
    final list = <_FilaInvitacion>[];
    for (final u in _resultadosBusqueda) {
      if (_idsAmigos.contains(u.idUsuario) || u.estadoAmistad == 'amigo') {
        continue;
      }
      list.add(_FilaInvitacion.desdeUsuario(u, esAmigo: false));
    }
    list.sort((a, b) => _puntajeFila(b, qLower).compareTo(_puntajeFila(a, qLower)));
    return list;
  }

  Future<void> _validarUsername() async {
    final raw = _usernameController.text.trim();
    if (raw.isEmpty || _validandoUsername) return;
    setState(() {
      _validandoUsername = true;
      _usernameMsg = null;
    });
    final res = await _srvSquads.chequearUsername(raw);
    if (!mounted) return;
    setState(() {
      _validandoUsername = false;
      _usernameValidado = res.disponible;
      _usernameNormalizado = res.normalizado;
      _usernameMsg = res.mensaje;
    });
  }

  void _onUsernameCambiado(String _) {
    if (_usernameValidado || _usernameMsg != null) {
      setState(() {
        _usernameValidado = false;
        _usernameMsg = null;
        _usernameNormalizado = null;
      });
    }
  }

  Future<void> _seleccionarBanner(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 2000,
        imageQuality: 88,
      );
      if (xfile == null || !mounted) return;
      final bytes = await xfile.readAsBytes();
      if (mounted) setState(() => _bannerPreviewBytes = bytes);
    } catch (_) {}
  }

  void _mostrarOpcionesBanner() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          'Foto de portada',
          style: GoogleFonts.baloo2(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _seleccionarBanner(ImageSource.camera);
            },
            child: const Text('Tomar foto'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _seleccionarBanner(ImageSource.gallery);
            },
            child: const Text('Elegir de galería'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Future<void> _crearSquad() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      _mostrarError('Escribí el nombre del squad.');
      return;
    }
    if (!_usernameValidado) {
      _mostrarError('Validá el @username antes de crear el squad.');
      return;
    }
    setState(() => _creando = true);

    final descripcion = _descripcionController.text.trim();
    final vibe = _estadoController.text.trim();
    final idGrupo = await _srvSquads.crear(
      nombre: nombre,
      username: _usernameNormalizado ?? _usernameController.text.trim(),
      descripcion: descripcion.isEmpty ? null : descripcion,
      esPublico: _esPublico,
      vibe: vibe.isEmpty ? null : vibe,
    );

    if (idGrupo == null) {
      if (mounted) {
        setState(() => _creando = false);
        _mostrarError('No se pudo crear el squad. Intentá de nuevo.');
      }
      return;
    }

    if (_bannerPreviewBytes != null) {
      try {
        final comprimida = await comprimirImagenStorage(
          _bannerPreviewBytes!,
          perfil: PerfilImagenStorage.portadaSquad,
        );
        final path = await _srvSquads.subirPortada(
          idGrupo,
          comprimida.bytes,
          ext: comprimida.extension,
        );
        if (path != null) {
          await _srvSquads.editar(idGrupo, urlPortada: path);
        }
      } catch (_) {}
    }

    for (final idUsuario in _miembrosSeleccionados) {
      await _srvSquads.invitar(idGrupo, idUsuario);
    }

    if (!mounted) return;
    setState(() => _creando = false);
    Navigator.of(context).pop(true);
  }

  void _mostrarError(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ups'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, padding.top + 8, 20, padding.bottom + 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.back,
                      color: ColoresApp.principalMarca,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nuevo squad',
                      style: GoogleFonts.baloo2(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ColoresApp.textoPrincipal,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Definí tu grupo e invitá amigos o personas de la app.',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 20),

              const EncabezadoSeccionSocial(
                titulo: 'Identidad',
                subtitulo: 'Cómo te van a encontrar y qué transmite tu squad',
              ),
              CardSuperficieSocial(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiquetaCampo('@username', 'Único en Fernecito — validalo antes de crear'),
                    _input(
                      controller: _usernameController,
                      hint: 'mi_squad',
                      prefix: '@',
                      onChanged: _onUsernameCambiado,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: _usernameValidado
                            ? const Color(0xFF2E7D32)
                            : ColoresApp.principalMarca,
                        borderRadius: BorderRadius.circular(18),
                        onPressed: _validandoUsername ? null : _validarUsername,
                        child: _validandoUsername
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : Text(
                                _usernameValidado ? 'Disponible' : 'Comprobar @',
                                style: GoogleFonts.baloo2(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    if (_usernameMsg != null && !_validandoUsername) ...[
                      const SizedBox(height: 6),
                      Text(
                        _usernameMsg!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _usernameValidado
                              ? const Color(0xFF66BB6A)
                              : ColoresApp.peligroMarca,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _etiquetaCampo('Nombre', 'El título que verán todos'),
                    _input(
                      controller: _nombreController,
                      hint: 'Ej: Los del Centro',
                    ),
                    const SizedBox(height: 12),
                    _etiquetaCampo('Estado', 'Frase corta de vibe (opcional)'),
                    _input(
                      controller: _estadoController,
                      hint: 'Listos para la pista',
                      maxLength: 50,
                    ),
                    const SizedBox(height: 12),
                    _etiquetaCampo('Descripción', 'Opcional — máx. 150 caracteres'),
                    _input(
                      controller: _descripcionController,
                      hint: 'De qué va el squad...',
                      maxLines: 3,
                      maxLength: 150,
                      radius: 16,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Squad público',
                                style: GoogleFonts.baloo2(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: ColoresApp.textoPrincipal,
                                ),
                              ),
                              Text(
                                'Otros pueden encontrarlo y pedir unirse',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12,
                                  color: ColoresApp.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _esPublico,
                          activeTrackColor: ColoresApp.principalMarca,
                          onChanged: (v) => setState(() => _esPublico = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const EncabezadoSeccionSocial(
                titulo: 'Portada',
                subtitulo: 'Preferí fotos verticales — si no, se recorta al ancho',
              ),
              CardSuperficieSocial(
                padding: const EdgeInsets.all(14),
                child: GestureDetector(
                  onTap: _mostrarOpcionesBanner,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoPrincipal.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ColoresApp.principalMarca.withValues(alpha: 0.28),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _bannerPreviewBytes != null
                        ? Image.memory(
                            _bannerPreviewBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.photo_on_rectangle,
                                size: 32,
                                color: ColoresApp.principalMarca.withValues(alpha: 0.9),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tocá para subir foto vertical',
                                style: GoogleFonts.baloo2(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ColoresApp.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 18),
              const EncabezadoSeccionSocial(
                titulo: 'Invitados',
                subtitulo: 'Sumá gente ahora o invitalos después desde el squad',
              ),
              CardSuperficieSocial(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_miembrosSeleccionados.isNotEmpty) ...[
                      Text(
                        'Seleccionados (${_miembrosSeleccionados.length})',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _miembrosSeleccionados.map((id) {
                          final amigo = _amigoPorId(id);
                          final label = _labelPorId[id] ??
                              (amigo == null
                                  ? 'Usuario'
                                  : '@${amigo.username}');
                          return Container(
                            padding: const EdgeInsets.only(
                              left: 10,
                              right: 4,
                              top: 5,
                              bottom: 5,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.principalMarca.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: ColoresApp.principalMarca.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ColoresApp.principalMarca,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _miembrosSeleccionados.remove(id),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    size: 18,
                                    color: ColoresApp.peligroMarca,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _campoBusqueda(),
                    const SizedBox(height: 12),
                    _buildListaInvitados(),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: ColoresApp.principalMarca,
                borderRadius: BorderRadius.circular(18),
                onPressed: _creando ? null : _crearSquad,
                child: _creando
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        'Crear squad',
                        style: GoogleFonts.baloo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoBusqueda() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 17,
            color: ColoresApp.textoSecundario.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _buscarController,
              placeholder: 'Nombre o @username',
              placeholderStyle: GoogleFonts.baloo2(
                fontSize: 13,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.9),
              ),
              style: GoogleFonts.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ColoresApp.textoPrincipal,
              ),
              padding: EdgeInsets.zero,
              decoration: null,
              onChanged: _onBuscarCambiado,
            ),
          ),
          if (_buscarController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _buscarController.clear();
                _onBuscarCambiado('');
              },
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }

  Widget _etiquetaSeccionLista(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        titulo,
        style: GoogleFonts.baloo2(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: ColoresApp.textoSecundario,
        ),
      ),
    );
  }

  Widget _buildListaInvitados() {
    final query = _buscarController.text.trim();
    final modoBusqueda = query.length >= 2;

    if (modoBusqueda) {
      if (_buscandoUsuarios && _resultadosBusqueda.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CupertinoActivityIndicator()),
        );
      }
      final amigos = _filasAmigosEnBusqueda(query);
      final otros = _filasOtrosEnBusqueda(query);

      if (amigos.isEmpty && otros.isEmpty && !_buscandoUsuarios) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No encontramos a nadie con "$query".',
            textAlign: TextAlign.center,
            style: GoogleFonts.baloo2(
              fontSize: 13,
              color: ColoresApp.textoSecundario,
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (amigos.isNotEmpty) ...[
            _etiquetaSeccionLista('Tus amigos'),
            ...amigos.map((f) => _itemFila(f, enBusqueda: true)),
          ],
          if (otros.isNotEmpty) ...[
            if (amigos.isNotEmpty) const SizedBox(height: 8),
            _etiquetaSeccionLista('Más personas'),
            ...otros.map((f) => _itemFila(f, enBusqueda: true)),
          ],
          if (_buscandoUsuarios)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: CupertinoActivityIndicator(radius: 10),
              ),
            ),
        ],
      );
    }

    if (_cargandoAmigos) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_amigos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Todavía no tenés amigos. Escribí al menos 2 letras para buscar a cualquier persona.',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 13,
            color: ColoresApp.textoSecundario,
          ),
        ),
      );
    }

    final amigos = _amigosOrdenadosPorCoincidencia();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiquetaSeccionLista('Tus amigos'),
        ...amigos.map((a) => _itemFila(_FilaInvitacion.desdeAmigo(a))),
      ],
    );
  }

  void _abrirPerfilInvitacion(_FilaInvitacion f) {
    final user = f.username.startsWith('@') ? f.username : '@${f.username}';
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PantallaPerfilUsuarios(
          usuario: {
            'id_usuario': f.id,
            'nombre': f.nombre,
            'username': user,
            'avatar': f.avatarUrl ?? '',
            'perfil_publico': f.perfilPublico,
          },
          estadoRelacion: f.esAmigo
              ? EstadoRelacionUsuario.amigo
              : EstadoRelacionUsuario.ninguno,
        ),
      ),
    );
  }

  Widget _itemFila(_FilaInvitacion f, {bool enBusqueda = false}) {
    final seleccionado = _miembrosSeleccionados.contains(f.id);
    final user = f.username.isEmpty
        ? ''
        : (f.username.startsWith('@') ? f.username : '@${f.username}');
    final label = user.isEmpty ? f.nombre : user;
    final candado = enBusqueda
        ? PrivacidadPerfil.mostrarCandadoEnBusqueda(
            perfilPublico: f.perfilPublico,
          )
        : PrivacidadPerfil.mostrarCandadoPrivado(
            perfilPublico: f.perfilPublico,
            esAmigo: f.esAmigo,
          );
    final titulo = enBusqueda
        ? PrivacidadPerfil.nombreEnBusqueda(
            perfilPublico: f.perfilPublico,
            nombre: f.nombre,
          )
        : (candado ? PrivacidadPerfil.tituloPerfilPrivado : f.nombre);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _abrirPerfilInvitacion(f),
              child: AvatarSocialPrivacidad(
                url: f.avatarUrl ?? '',
                size: 40,
                mostrarCandado: candado,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _abrirPerfilInvitacion(f),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColoresApp.textoPrincipal,
                              ),
                            ),
                          ),
                          if (f.esAmigo) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ColoresApp.principalMarca
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Amigo',
                                style: GoogleFonts.baloo2(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: ColoresApp.principalMarca,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (user.isNotEmpty)
                        Text(
                          user,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            color: ColoresApp.principalMarca.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => _toggleSeleccion(f.id, label),
              child: Icon(
                seleccionado
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.plus_circle,
                color: seleccionado
                    ? ColoresApp.principalMarca
                    : ColoresApp.textoSecundario.withValues(alpha: 0.5),
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiquetaCampo(String titulo, String ayuda) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          Text(
            ayuda,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
    double radius = 18,
    String? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(
              prefix,
              style: GoogleFonts.baloo2(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ColoresApp.principalMarca,
              ),
            ),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: hint,
              placeholderStyle: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.textoSecundario.withValues(alpha: 0.85),
              ),
              style: GoogleFonts.baloo2(
                fontSize: 15,
                color: ColoresApp.textoPrincipal,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              maxLines: maxLines,
              maxLength: maxLength,
              onChanged: onChanged,
              decoration: null,
            ),
          ),
        ],
      ),
    );
  }
}
