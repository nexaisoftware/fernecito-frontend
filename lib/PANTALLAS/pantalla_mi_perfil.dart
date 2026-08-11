/// Pantalla Mi Perfil - Pulida y Moderna
///
/// Permite ver y editar el perfil del usuario con estilo iOS moderno:
/// - Foto de perfil con edición (tomar/galería/eliminar)
/// - Username, nombre, cumpleaños
/// - Configuración de perfil público
/// - Redes sociales (Instagram, TikTok) con iconos SVG
/// - Estado personalizado (70 caracteres, 2 líneas)
/// - Cerrar sesión y eliminar cuenta
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/comprimir_imagen_storage.dart';
import '../core/constants.dart';
import '../core/servicio_amigos.dart';
import '../core/servicio_locales_megusta.dart';
import '../core/servicio_perfil_usuario.dart';
import '../core/servicio_ubicacion_global.dart';
import '../core/sexo_perfil.dart';
import '../core/supabase_client.dart';
import '../core/tema_fernecito.dart';
import '../core/ubicaciones_data.dart';
import 'pantalla_cambiar_contrasena.dart';
import 'pantalla_eliminar_todo.dart';
import 'pantalla_soporte.dart';
import 'pantalla_social.dart';
import '../widgets/carrusel_lugares_megusta.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/perfil_actividad_sheet.dart';
import '../core/lanzador_externo.dart';
import '../widgets/banner_perfil_usuario.dart';
import '../widgets/avatar_bordes.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/recortar_avatar_sheet.dart';
import '../widgets/skeleton_pantallas.dart';

class PantallaMiPerfil extends StatefulWidget {
  /// Incrementado desde [PantallaHome] al seleccionar el tab Perfil (IndexedStack).
  final int reloadTick;

  const PantallaMiPerfil({super.key, this.reloadTick = 0});

  @override
  State<PantallaMiPerfil> createState() => _PantallaMiPerfilState();
}

class _PantallaMiPerfilState extends State<PantallaMiPerfil> {
  // Controladores
  final TextEditingController _controladorNombre = TextEditingController();
  final TextEditingController _controladorEdad = TextEditingController();
  final TextEditingController _controladorInstagram = TextEditingController();
  final TextEditingController _controladorTikTok = TextEditingController();
  final TextEditingController _controladorEstado = TextEditingController();

  // FocusNode para el textfield del estado
  final FocusNode _focusNombre = FocusNode();
  final FocusNode _focusEstado = FocusNode();

  // Estado
  String? _fotoPerfilUrl;
  String _username = '';
  String _nombre = '';
  int? _edad;
  DateTime? _fechaNacimiento;
  String? _sexo;
  bool _perfilPublico = false;
  String? _instagramUrl;
  String? _tiktokUrl;
  String? _miEstado;
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;
  bool _subiendoBanner = false;
  bool _pedidoCumpleMostrado = false;
  bool _pedidoSexoMostrado = false;
  String? _bannerPath;
  String? _bannerPerfilUrl;
  bool _editandoNombreInline = false;
  bool _editandoEstadoInline = false;

  String _ciudad = '';
  String _provincia = '';
  int _cantidadAmigos = 0;
  int _cantidadSquads = 0;
  int _localesVisitados = 0;
  int _eventosAsistidos = 0;
  List<LocalMegustaItem> _lugaresMegusta = const [];

  final ImagePicker _picker = ImagePicker();
  final ServicioPerfilUsuario _srvPerfil = ServicioPerfilUsuario();

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  @override
  void didUpdateWidget(PantallaMiPerfil oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadTick != widget.reloadTick && widget.reloadTick > 0) {
      final uid = ServicioSupabase().usuarioActual?.id;
      if (uid != null) _cargarMetricasPerfil(uid);
    }
  }

  @override
  void dispose() {
    _controladorNombre.dispose();
    _controladorEdad.dispose();
    _controladorInstagram.dispose();
    _controladorTikTok.dispose();
    _controladorEstado.dispose();
    _focusNombre.dispose();
    _focusEstado.dispose();
    super.dispose();
  }

  // Cargar datos del perfil desde Supabase
  Future<void> _cargarDatosPerfil() async {
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      final respuesta = await supabase.cliente
          .from('perfiles_usuarios')
          .select('*')
          .eq('id', usuario.id)
          .single();

      if (mounted) {
        setState(() {
          _username = respuesta['username'] ?? '';
          _nombre = respuesta['nombre'] ?? '';
          final fechaRaw = respuesta['fecha_nacimiento']?.toString() ?? '';
          _fechaNacimiento = fechaRaw.isEmpty
              ? null
              : DateTime.tryParse(fechaRaw);
          final edadRaw = respuesta['edad'];
          _edad = _fechaNacimiento != null
              ? _edadDesdeFecha(_fechaNacimiento!)
              : (edadRaw is int
                    ? edadRaw
                    : int.tryParse(edadRaw?.toString() ?? ''));
          _sexo = SexoPerfil.normalizar(respuesta['sexo']);
          _perfilPublico = respuesta['perfil_publico'] ?? false;
          _instagramUrl = respuesta['instagram_url'];
          _tiktokUrl = respuesta['tiktok_url'];
          _miEstado = respuesta['mi_estado'];
          _ciudad = (respuesta['ciudad'] as String?)?.trim() ?? '';
          _provincia = (respuesta['provincia'] as String?)?.trim() ?? '';

          // Construir URL de foto con timestamp anti-cache
          if (respuesta['foto_perfil_url'] != null) {
            final path = respuesta['foto_perfil_url'] as String;
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            _fotoPerfilUrl =
                '${supabase.cliente.storage.from('avatars').getPublicUrl(path)}?v=$timestamp';
          } else {
            _fotoPerfilUrl = null;
          }

          final bannerPath = respuesta['url_foto_banner'] as String?;
          _bannerPath = (bannerPath ?? '').trim().isEmpty
              ? null
              : bannerPath!.trim();
          if (_bannerPath != null) {
            final ts = DateTime.now().millisecondsSinceEpoch;
            final base = supabase.urlBannerUsuario(_bannerPath);
            _bannerPerfilUrl = base != null ? '$base?v=$ts' : null;
          } else {
            _bannerPerfilUrl = null;
          }

          // Llenar controladores
          _controladorNombre.text = _nombre;
          _controladorEdad.text = _edad?.toString() ?? '';
          _controladorInstagram.text = _instagramUrl ?? '';
          _controladorTikTok.text = _tiktokUrl ?? '';
          _controladorEstado.text = _miEstado ?? '';

          _cargando = false;
        });
        _cargarMetricasPerfil(usuario.id);
        if (_fechaNacimiento == null && !_pedidoCumpleMostrado) {
          _pedidoCumpleMostrado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mostrarPedidoCumple();
          });
        } else if (!SexoPerfil.esValido(_sexo) && !_pedidoSexoMostrado) {
          _pedidoSexoMostrado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mostrarPedidoSexo();
          });
        }
      }
    } catch (error) {
      print('❌ Error cargando perfil: $error');
      if (mounted) {
        setState(() {
          _cargando = false;
        });
        _mostrarError('Error al cargar tu perfil');
      }
    }
  }

  // Mostrar opciones de foto
  void _mostrarOpcionesFoto() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          '¿Qué querés hacer?',
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
                  'Tomar otra foto',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              _seleccionarYSubirFoto(ImageSource.camera);
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: ColoresApp.principalMarca),
                const SizedBox(width: 12),
                Text(
                  'Seleccionar de galería',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              _seleccionarYSubirFoto(ImageSource.gallery);
            },
          ),
          if (_fotoPerfilUrl != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.trash,
                    color: ColoresApp.peligroMarca,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Eliminar foto',
                    style: GoogleFonts.baloo2(fontSize: 16),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.pop(context);
                _eliminarFoto();
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: Text('Cancelar', style: GoogleFonts.baloo2(fontSize: 16)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // Mostrar foto en fullscreen con blur
  void _mostrarFotoFullscreen() {
    if (_fotoPerfilUrl == null) return;

    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // No cerrar al tocar la imagen
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: _fotoPerfilUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        width: 300,
                        height: 300,
                        color: ColoresApp.fondoSuperficie,
                        child: const FernecitoLoaderCentro(size: 34),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 300,
                        height: 300,
                        color: ColoresApp.fondoSuperficie,
                        child: const Icon(
                          CupertinoIcons.photo,
                          size: 100,
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
    );
  }

  // Seleccionar y subir foto
  Future<void> _seleccionarYSubirFoto(ImageSource source) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );

      if (imagen == null) return;

      final bytesOriginales = await imagen.readAsBytes();
      if (!mounted) return;

      final bytesRecortados = await mostrarRecorteAvatarSheet(
        context,
        bytesOriginales,
      );
      if (bytesRecortados == null || !mounted) return;

      setState(() {
        _subiendoFoto = true;
      });

      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      final comprimida = await comprimirImagenStorage(
        bytesRecortados,
        perfil: PerfilImagenStorage.avatarUsuario,
      );

      final extension = comprimida.extension;
      final pathRelativo = 'usuarios/${usuario.id}/avatar.$extension';
      final bytes = comprimida.bytes;
      final contentType = comprimida.contentType;

      print('📤 Subiendo foto actualizada...');

      // Limpiar extensiones viejas del mismo slot (jpg vs webp, etc.).
      try {
        final pathsViejos = <String>{
          'usuarios/${usuario.id}/avatar.jpg',
          'usuarios/${usuario.id}/avatar.jpeg',
          'usuarios/${usuario.id}/avatar.webp',
          'usuarios/${usuario.id}/avatar.png',
        }..remove(pathRelativo);
        if (pathsViejos.isNotEmpty) {
          await supabase.cliente.storage
              .from('avatars')
              .remove(pathsViejos.toList());
        }
      } catch (_) {}

      // Subir con upsert (mismo path base → reemplaza bytes del archivo actual)
      await supabase.cliente.storage
          .from('avatars')
          .uploadBinary(
            pathRelativo,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      print('✅ Foto actualizada: $pathRelativo');

      // Actualizar DB
      await supabase.cliente
          .from('perfiles_usuarios')
          .update({'foto_perfil_url': pathRelativo})
          .eq('id', usuario.id);

      // Recargar perfil
      await _cargarDatosPerfil();
      _srvPerfil.publicarAvatarNavbar(_fotoPerfilUrl);

      if (mounted) {
        _mostrarExito('Foto actualizada correctamente');
      }
    } catch (error) {
      print('❌ Error actualizando foto: $error');
      if (mounted) {
        _mostrarError('Error al actualizar la foto');
      }
    } finally {
      if (mounted) {
        setState(() {
          _subiendoFoto = false;
        });
      }
    }
  }

  void _mostrarOpcionesBanner() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'Banner del perfil',
          style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: ColoresApp.principalMarca),
                const SizedBox(width: 12),
                Text(
                  'Elegir de galería',
                  style: GoogleFonts.baloo2(
                    fontSize: 16,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              _seleccionarYSubirBanner();
            },
          ),
          if (_bannerPath != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.trash,
                    color: ColoresApp.peligroMarca,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quitar banner personalizado',
                    style: GoogleFonts.baloo2(fontSize: 16),
                  ),
                ],
              ),
              onPressed: () {
                Navigator.pop(context);
                _eliminarBanner();
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: Text('Cancelar', style: GoogleFonts.baloo2(fontSize: 16)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _seleccionarYSubirBanner() async {
    try {
      final imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (imagen == null) return;

      final bytesOriginales = await imagen.readAsBytes();
      if (!mounted) return;

      setState(() => _subiendoBanner = true);

      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      final comprimida = await comprimirImagenStorage(
        bytesOriginales,
        perfil: PerfilImagenStorage.bannerUsuario,
      );

      final pathRelativo = '${usuario.id}/foto_banner${comprimida.pathSuffix}';

      try {
        final pathsViejos = <String>{
          if (_bannerPath != null && !_bannerPath!.startsWith('http'))
            _bannerPath!,
          '${usuario.id}/foto_banner.jpg',
          '${usuario.id}/foto_banner.jpeg',
          '${usuario.id}/foto_banner.webp',
        }..remove(pathRelativo);
        if (pathsViejos.isNotEmpty) {
          await supabase.cliente.storage
              .from('banners-usuarios')
              .remove(pathsViejos.toList());
        }
      } catch (_) {}

      await supabase.cliente.storage
          .from('banners-usuarios')
          .uploadBinary(
            pathRelativo,
            comprimida.bytes,
            fileOptions: FileOptions(
              contentType: comprimida.contentType,
              upsert: true,
            ),
          );

      await supabase.cliente
          .from('perfiles_usuarios')
          .update({'url_foto_banner': pathRelativo})
          .eq('id', usuario.id);

      await _cargarDatosPerfil();

      if (mounted) {
        _mostrarExito('Banner actualizado');
      }
    } catch (error) {
      if (mounted) {
        _mostrarError('No se pudo actualizar el banner');
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoBanner = false);
      }
    }
  }

  Future<void> _eliminarBanner() async {
    final confirmado = await _mostrarDialogoConfirmacion(
      titulo: '¿Quitar banner?',
      mensaje: 'Se volverá a usar tu foto de perfil como fondo del banner.',
      textoConfirmar: 'Quitar',
      esDestructivo: true,
    );
    if (confirmado != true) return;

    try {
      setState(() => _subiendoBanner = true);

      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      await supabase.cliente
          .from('perfiles_usuarios')
          .update({'url_foto_banner': null})
          .eq('id', usuario.id);

      if (_bannerPath != null && !_bannerPath!.startsWith('http')) {
        try {
          await supabase.cliente.storage.from('banners-usuarios').remove([
            _bannerPath!,
          ]);
        } catch (_) {}
      }

      await _cargarDatosPerfil();

      if (mounted) {
        _mostrarExito('Banner restaurado a tu foto de perfil');
      }
    } catch (error) {
      if (mounted) {
        _mostrarError('No se pudo quitar el banner');
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoBanner = false);
      }
    }
  }

  Widget _botonCambiarBanner() {
    return GestureDetector(
      onTap: _subiendoBanner ? null : _mostrarOpcionesBanner,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_subiendoBanner)
              const SizedBox(
                width: 16,
                height: 16,
                child: FernecitoLoader.inline(size: 16, color: Colors.white),
              )
            else
              const Icon(CupertinoIcons.pencil, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Cambiar banner',
              style: GoogleFonts.baloo2(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Eliminar foto
  Future<void> _eliminarFoto() async {
    final confirmado = await _mostrarDialogoConfirmacion(
      titulo: '¿Eliminar foto?',
      mensaje: 'Tu foto de perfil será eliminada',
      textoConfirmar: 'Eliminar',
      esDestructivo: true,
    );

    if (confirmado != true) return;

    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      // Actualizar DB (poner null)
      await supabase.cliente
          .from('perfiles_usuarios')
          .update({'foto_perfil_url': null})
          .eq('id', usuario.id);

      // Recargar perfil
      await _cargarDatosPerfil();
      _srvPerfil.publicarAvatarNavbar(_fotoPerfilUrl);

      if (mounted) {
        _mostrarExito('Foto eliminada correctamente');
      }
    } catch (error) {
      print('❌ Error eliminando foto: $error');
      if (mounted) {
        _mostrarError('Error al eliminar la foto');
      }
    }
  }

  Future<void> _cargarMetricasPerfil(String idUsuario) async {
    final detFuture = _srvPerfil.detalle(idUsuario);
    final amistadesFuture = ServicioAmigos().listar();
    final lugaresFuture = ServicioLocalesMegusta.instancia.listar(
      idUsuario: idUsuario,
    );
    final det = await detFuture;
    final amistades = await amistadesFuture;
    final lugares = await lugaresFuture;
    if (!mounted) return;
    setState(() {
      // Misma fuente que la pestaña Social (amistad_listar).
      _cantidadAmigos = amistades.amigos.length;
      _lugaresMegusta = lugares;
      if (det != null) {
        _localesVisitados = ServicioPerfilUsuario.enteroDeDetalle(
          det,
          'locales_visitados',
        );
        _eventosAsistidos = ServicioPerfilUsuario.enteroDeDetalle(
          det,
          'eventos_asistidos',
        );
        _cantidadSquads = ServicioPerfilUsuario.enteroDeDetalle(
          det,
          'cantidad_squads',
        );
        final ciudadDet = (det['ciudad'] as String?)?.trim() ?? '';
        final provDet = (det['provincia'] as String?)?.trim() ?? '';
        if (ciudadDet.isNotEmpty) _ciudad = ciudadDet;
        if (provDet.isNotEmpty) _provincia = provDet;
      }
    });
  }

  String get _textoUbicacion {
    if (_ciudad.isNotEmpty && _provincia.isNotEmpty) {
      return '$_ciudad, $_provincia';
    }
    if (_ciudad.isNotEmpty) return _ciudad;
    if (_provincia.isNotEmpty) return _provincia;
    return 'Sin definir';
  }

  Future<void> _editarUbicacion() async {
    final res = await mostrarSelectorUbicacionPerfil(
      context,
      provinciaActual: _provincia.isNotEmpty
          ? _provincia
          : UbicacionesData.provinciaPorDefecto,
      ciudadActual: _ciudad,
    );
    if (res == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      await ServicioUbicacionGlobal.aplicarManual(
        provincia: res.provincia,
        ciudades: {res.ciudad},
        principal: res.ciudad,
      );

      if (mounted) {
        setState(() {
          _provincia = res.provincia;
          _ciudad = res.ciudad;
        });
        _mostrarExito('Ubicación actualizada');
      }
    } catch (error) {
      print('❌ Error actualizando ubicación: $error');
      if (mounted) _mostrarError('No se pudo guardar la ubicación');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  int _edadDesdeFecha(DateTime fecha) {
    final hoy = DateTime.now();
    var edad = hoy.year - fecha.year;
    final yaCumplio =
        hoy.month > fecha.month ||
        (hoy.month == fecha.month && hoy.day >= fecha.day);
    if (!yaCumplio) edad -= 1;
    return edad;
  }

  String _fechaIso(DateTime fecha) {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fechaCumpleTexto(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  String get _textoCumple {
    final fecha = _fechaNacimiento;
    if (fecha == null) return _edad != null ? '${_edad!} años' : 'Tu cumple';
    return '${_fechaCumpleTexto(fecha)} · ${_edadDesdeFecha(fecha)} años';
  }

  String get _textoSexo {
    final sexo = _sexo;
    if (!SexoPerfil.esValido(sexo)) return 'Tu género';
    return SexoPerfil.etiqueta(sexo!);
  }

  Future<void> _mostrarPedidoSexo() async {
    final elegido = await mostrarDialogoPedirSexo(context);
    if (!mounted || elegido == null) return;
    await _guardarSexo(elegido);
  }

  Future<void> _editarSexo() async {
    final elegido = await mostrarDialogoPedirSexo(
      context,
      titulo: 'Tu género',
      mensaje: 'Elegí la opción que mejor te represente.',
      permitirDespues: SexoPerfil.esValido(_sexo),
    );
    if (!mounted || elegido == null) return;
    await _guardarSexo(elegido);
  }

  Future<void> _guardarSexo(String valor) async {
    if (!SexoPerfil.esValido(valor)) return;
    setState(() => _guardando = true);
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      await supabase.cliente
          .from('perfiles_usuarios')
          .update({'sexo': valor})
          .eq('id', usuario.id);

      if (!mounted) return;
      setState(() => _sexo = valor);
      _mostrarExito('Género guardado correctamente');
    } catch (error) {
      debugPrint('❌ Error actualizando sexo: $error');
      if (mounted) _mostrarError('No se pudo guardar tu género');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarPedidoCumple() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Queremos saber cuándo es tu cumple'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Ahora usamos tu cumpleaños para calcular tu edad bien y recomendarte planes más acordes.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Después'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Completar'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _actualizarEdad();
            },
          ),
        ],
      ),
    );
  }

  // Actualizar cumpleaños
  Future<void> _actualizarEdad() async {
    final hoy = DateTime.now();
    final maxDate = DateTime(hoy.year - 13, hoy.month, hoy.day);
    final minDate = DateTime(1920, 1, 1);
    var seleccion =
        _fechaNacimiento ??
        (_edad != null
            ? DateTime(hoy.year - _edad!, hoy.month, hoy.day)
            : DateTime(hoy.year - 18, hoy.month, hoy.day));
    if (seleccion.isAfter(maxDate)) seleccion = maxDate;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 330,
        color: ColoresApp.fondoSuperficie,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.baloo2(
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                ),
                CupertinoButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _guardarFechaNacimiento(seleccion);
                  },
                  child: Text(
                    'Listo',
                    style: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Tu edad se actualiza sola cada año.',
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: seleccion,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (fecha) => seleccion = fecha,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarFechaNacimiento(DateTime fecha) async {
    setState(() => _guardando = true);
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      await supabase.cliente
          .from('perfiles_usuarios')
          .update({
            'fecha_nacimiento': _fechaIso(fecha),
            'edad': _edadDesdeFecha(fecha),
          })
          .eq('id', usuario.id);

      await _cargarDatosPerfil();
      if (mounted) _mostrarExito('Cumpleaños guardado correctamente');
    } catch (error) {
      debugPrint('❌ Error actualizando fecha_nacimiento: $error');
      if (mounted) _mostrarError('No se pudo guardar tu cumple');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // Actualizar perfil público (las redes pueden quedar guardadas; no se muestran si es privado).
  Future<void> _actualizarPerfilPublico(bool valor) async {
    setState(() => _guardando = true);
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      await supabase.cliente
          .from('perfiles_usuarios')
          .update({'perfil_publico': valor})
          .eq('id', usuario.id);

      await _cargarDatosPerfil();
      if (mounted) _mostrarExito('Cambios guardados correctamente');
    } catch (error) {
      debugPrint('❌ Error actualizando perfil_publico: $error');
      await _cargarDatosPerfil();
      if (mounted)
        _mostrarError('No se pudo cambiar la visibilidad del perfil');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // Actualizar Instagram
  Future<void> _actualizarInstagram() async {
    final valor = _controladorInstagram.text.trim();
    await _actualizarCampo('instagram_url', valor.isEmpty ? null : valor);
  }

  // Actualizar TikTok
  Future<void> _actualizarTikTok() async {
    final valor = _controladorTikTok.text.trim();
    await _actualizarCampo('tiktok_url', valor.isEmpty ? null : valor);
  }

  // Actualizar Mi Estado
  Future<void> _actualizarMiEstado() async {
    // Quitar el focus del textfield
    _focusEstado.unfocus();

    final estado = _controladorEstado.text.trim();
    if (estado.length > 50) {
      _mostrarError('El estado no puede tener más de 50 caracteres');
      return;
    }
    await _actualizarCampo('mi_estado', estado.isEmpty ? null : estado);
  }

  Future<void> _guardarNombreInline() async {
    final nuevoNombre = _controladorNombre.text.trim();
    if (nuevoNombre.isEmpty) {
      _mostrarError('Ingresa tu nombre o apodo');
      return;
    }
    await _actualizarCampo('nombre', nuevoNombre);
    if (mounted) {
      setState(() => _editandoNombreInline = false);
    }
  }

  Future<void> _guardarEstadoInline() async {
    await _actualizarMiEstado();
    if (mounted) {
      setState(() => _editandoEstadoInline = false);
    }
  }

  Future<void> _copiarUsername() async {
    final userTag = '@$_username';
    await Clipboard.setData(ClipboardData(text: userTag));
    if (mounted) {
      _mostrarExito('Username copiado');
    }
  }

  // Actualizar campo genérico en DB
  Future<void> _actualizarCampo(String campo, dynamic valor) async {
    setState(() {
      _guardando = true;
    });

    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      await supabase.cliente
          .from('perfiles_usuarios')
          .update({campo: valor})
          .eq('id', usuario.id);

      print('✅ Campo $campo actualizado: $valor');

      // Recargar datos
      await _cargarDatosPerfil();

      if (mounted) {
        _mostrarExito('Cambios guardados correctamente');
      }
    } catch (error) {
      print('❌ Error actualizando $campo: $error');
      if (mounted) {
        _mostrarError('Error al guardar cambios');
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // Cerrar sesión
  Future<void> _cerrarSesion() async {
    try {
      print('🔓 Cerrando sesión...');

      final supabase = ServicioSupabase();
      await supabase.cliente.auth.signOut();

      print('✅ Sesión cerrada exitosamente');
      print('⏳ AuthGate manejará la navegación a Login automáticamente');

      // NO navegar manualmente - AuthGate se encarga
      // El evento signedOut será detectado y navegará a PantallaLogin
    } catch (error) {
      print('❌ Error cerrando sesión: $error');
      if (mounted) {
        _mostrarError('Error al cerrar sesión.\n\nIntentá de nuevo.');
      }
    }
  }

  // Eliminar cuenta — el usuario elige el alcance.
  Future<void> _eliminarCuenta() async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Eliminar cuenta'),
        message: const Text(
          'Elegí qué querés eliminar. Esta acción no se puede deshacer.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmarSoloUsuario();
            },
            child: const Text('Eliminar solo mi cuenta de usuario'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const PantallaEliminarTodo(),
                ),
              );
            },
            child: const Text(
              'Eliminar TODO mi Fernecito (usuario + locales + staff)',
            ),
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

  // Opción 1: borra SOLO la cuenta de usuario. Mantiene el auth y, si tenés un
  // local o sos staff con el mismo email, eso sigue funcionando.
  Future<void> _confirmarSoloUsuario() async {
    final confirmado = await _mostrarDialogoConfirmacion(
      titulo: '¿Eliminar tu cuenta de usuario?',
      mensaje:
          'Se borrarán tu perfil, amigos, squads, reservas y rompehielos.\n\n'
          'Si también tenés un local o sos staff con este mismo email, esos '
          'seguirán funcionando (no se tocan).',
      textoConfirmar: 'Eliminar',
      esDestructivo: true,
    );
    if (confirmado != true) return;
    await _ejecutarEliminacion('solo_usuario');
  }

  // (El borrado TOTAL ahora vive en PantallaEliminarTodo — más robusto.)

  // Invoca el edge con service_role; al terminar, signOut → AuthGate va a Login.
  Future<void> _ejecutarEliminacion(String modo) async {
    // Overlay de carga (no descartable) para que NO parezca tildado.
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FernecitoLoaderCentro(size: 36),
    );
    try {
      final supabase = ServicioSupabase();
      final session = supabase.cliente.auth.currentSession;
      if (session == null) {
        throw Exception('No hay sesión activa');
      }
      print('🗑️ Invocando eliminar_cuenta_usuario (modo=$modo)...');
      final res = await supabase.cliente.functions
          .invoke(
            'eliminar_cuenta_usuario',
            body: {'modo': modo},
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 40));
      print('🗑️ Respuesta edge: status=${res.status} data=${res.data}');
      final data = res.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        throw Exception('Respuesta no OK (status ${res.status}): ${res.data}');
      }
      print('✅ Cuenta eliminada ($modo). Cerrando sesión...');
      if (mounted)
        Navigator.of(context, rootNavigator: true).pop(); // cierra loader
      await supabase.cliente.auth.signOut();
      // AuthGate detecta signedOut y navega a Login.
    } catch (error) {
      print('❌ Error eliminando cuenta ($modo): $error');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // cierra loader
        _mostrarError('No se pudo eliminar la cuenta.\n\nDetalle: $error');
      }
    }
  }

  // Mostrar diálogo de confirmación
  Future<bool?> _mostrarDialogoConfirmacion({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
    bool esDestructivo = false,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: esDestructivo,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    );
  }

  // Mostrar error
  void _mostrarError(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Row(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              color: ColoresApp.peligroMarca,
            ),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Mostrar éxito
  void _mostrarExito(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(
              CupertinoIcons.check_mark_circled,
              color: ColoresApp.principalMarca,
            ),
            SizedBox(width: 8),
            Text('Éxito'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Truncar texto largo
  String _truncarTexto(String texto, int maxLength) {
    if (texto.length <= maxLength) return texto;
    return '${texto.substring(0, maxLength)}...';
  }

  // ── Helpers para el layout "espejo del perfil público" ──

  /// Strip de stats (Amigos · Squads · Eventos · Locales), igual que ve otro usuario.
  Widget _statStripMiPerfil() {
    final idUsuario = ServicioSupabase().usuarioActual?.id ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statInlineMP(
              '$_cantidadAmigos',
              'Amigos',
              compacto: true,
              onTap: _cantidadAmigos > 0 && idUsuario.isNotEmpty
                  ? () => mostrarPerfilActividadSheet(
                      context,
                      idUsuario: idUsuario,
                      tipo: PerfilActividadTipo.amigos,
                      titulo: 'Mis amigos',
                    )
                  : null,
            ),
          ),
          _divisorStatMP(),
          Expanded(
            child: _statInlineMP(
              '$_cantidadSquads',
              'Squads',
              compacto: true,
              onTap: _cantidadSquads > 0 && idUsuario.isNotEmpty
                  ? () => mostrarPerfilActividadSheet(
                      context,
                      idUsuario: idUsuario,
                      tipo: PerfilActividadTipo.squads,
                      titulo: 'Mis squads',
                    )
                  : null,
            ),
          ),
          _divisorStatMP(),
          Expanded(
            child: _statInlineMP(
              '$_eventosAsistidos',
              'Eventos',
              compacto: true,
              onTap: _eventosAsistidos > 0 && idUsuario.isNotEmpty
                  ? () => mostrarPerfilActividadSheet(
                      context,
                      idUsuario: idUsuario,
                      tipo: PerfilActividadTipo.eventos,
                      titulo: 'Mis eventos',
                    )
                  : null,
            ),
          ),
          _divisorStatMP(),
          Expanded(
            child: _statInlineMP(
              '$_localesVisitados',
              'Locales',
              compacto: true,
              onTap: _localesVisitados > 0 && idUsuario.isNotEmpty
                  ? () => mostrarPerfilActividadSheet(
                      context,
                      idUsuario: idUsuario,
                      tipo: PerfilActividadTipo.locales,
                      titulo: 'Locales visitados',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statInlineMP(
    String valor,
    String etiqueta, {
    VoidCallback? onTap,
    bool compacto = false,
  }) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          style: GoogleFonts.baloo2(
            fontSize: compacto ? 20 : 22,
            fontWeight: FontWeight.w900,
            color: ColoresApp.textoPrincipal,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          etiqueta,
          style: GoogleFonts.baloo2(
            fontSize: compacto ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: ColoresApp.textoSecundario,
          ),
        ),
      ],
    );

    if (onTap == null) return contenido;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: contenido,
    );
  }

  Widget _divisorStatMP() {
    return Container(
      width: 1,
      height: 30,
      color: ColoresApp.textoSecundario.withValues(alpha: 0.18),
    );
  }

  /// Chip de info editable (edad / ubicación). Lápiz = editable; al tocar edita.
  Widget _chipEditableMP({
    required IconData icono,
    required String texto,
    required VoidCallback onEditar,
    bool editable = true,
  }) {
    return GestureDetector(
      onTap: editable ? onEditar : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ColoresApp.fondoSuperficie.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 13, color: ColoresApp.principalMarca),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              editable ? CupertinoIcons.pencil : CupertinoIcons.lock_fill,
              size: 12,
              color: editable
                  ? ColoresApp.principalMarca
                  : ColoresApp.textoPrincipal.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  /// Lápiz chico para señalizar que un elemento (nombre / estado) es editable.
  Widget _hintLapiz() {
    return Icon(
      CupertinoIcons.pencil,
      size: 15,
      color: ColoresApp.principalMarca,
    );
  }

  /// Card de Ayuda y soporte → navega a la pantalla de soporte.
  Widget _cardSoporte() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => const PantallaSoporte())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SuperficiesApp.card(radius: 18, temaTint: 0.16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColoresApp.principalMarca.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.question_circle_fill,
                size: 20,
                color: ColoresApp.principalMarca,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ayuda y soporte',
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contactanos si tenés un problema',
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
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
              color: ColoresApp.textoSecundario.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirUrlRed(String urlString) async {
    var normalizada = urlString.trim();
    if (normalizada.isEmpty) return;
    if (!normalizada.startsWith('http://') &&
        !normalizada.startsWith('https://')) {
      normalizada = 'https://$normalizada';
    }
    final url = Uri.tryParse(normalizada);
    if (url == null) return;
    try {
      await lanzarExternoConFallback(url);
    } catch (_) {
      // Link externo opcional: si Android no tiene app/navegador disponible,
      // evitamos romper la pantalla de perfil.
    }
  }

  Widget _buildAvatarBannerMiPerfil(double size) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _fotoPerfilUrl != null ? () => _mostrarFotoFullscreen() : null,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AvatarBordes.blanco,
                width: AvatarBordes.ancho(preferido: 2.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _subiendoFoto
                ? ColoredBox(
                    color: ColoresApp.fondoSuperficie,
                    child: Center(
                      child: FernecitoLoader.inline(
                        size: 16,
                        color: ColoresApp.principalMarca,
                      ),
                    ),
                  )
                : _fotoPerfilUrl != null
                ? CachedNetworkImage(
                    imageUrl: _fotoPerfilUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ColoredBox(
                      color: ColoresApp.fondoSuperficie,
                      child: Center(
                        child: FernecitoLoader.inline(
                          size: 16,
                          color: ColoresApp.principalMarca,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      CupertinoIcons.person_circle_fill,
                      size: size * 0.7,
                      color: ColoresApp.textoSecundario,
                    ),
                  )
                : Icon(
                    CupertinoIcons.person_circle_fill,
                    size: size * 0.7,
                    color: ColoresApp.textoSecundario,
                  ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _mostrarOpcionesFoto,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ColoresApp.principalMarca,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.pencil,
                size: 16,
                color: ColoresApp.textoPrincipal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNombreBannerMiPerfil() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SizedBox(
        height: 34,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(right: _editandoNombreInline ? 92 : 0),
                child: Center(
                  child: _editandoNombreInline
                      ? CupertinoTextField(
                          controller: _controladorNombre,
                          focusNode: _focusNombre,
                          enabled: true,
                          textAlign: TextAlign.center,
                          placeholder: 'Tu nombre o apodo',
                          placeholderStyle: GoogleFonts.baloo2(
                            fontSize: 20,
                            color: ColoresApp.textoSecundario.withOpacity(0.7),
                          ),
                          style: GoogleFonts.baloo2(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: ColoresApp.textoPrincipal,
                          ),
                          decoration: null,
                          padding: EdgeInsets.zero,
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() => _editandoNombreInline = true);
                            Future.microtask(
                              () => FocusScope.of(
                                context,
                              ).requestFocus(_focusNombre),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _controladorNombre.text.trim().isEmpty
                                      ? 'Tu nombre o apodo'
                                      : _controladorNombre.text.trim(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        _controladorNombre.text.trim().isEmpty
                                        ? ColoresApp.textoSecundario
                                              .withOpacity(0.7)
                                        : ColoresApp.textoPrincipal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              _hintLapiz(),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            if (_editandoNombreInline)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(20),
                    onPressed: _guardando ? null : _guardarNombreInline,
                    child: _guardando
                        ? const FernecitoLoader.inline(
                            size: 16,
                            color: Colors.white,
                          )
                        : Text(
                            'Guardar',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoBannerMiPerfil(double maxWidth) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(right: _editandoEstadoInline ? 88 : 0),
                child: Center(
                  child: _editandoEstadoInline
                      ? Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          decoration: BoxDecoration(
                            color: ColoresApp.fondoSuperficie,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: CupertinoTextField(
                            controller: _controladorEstado,
                            focusNode: _focusEstado,
                            enabled: true,
                            placeholder: 'Escribe un estado divertido.',
                            maxLength: 50,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.baloo2(
                              color: ColoresApp.textoPrincipal,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: null,
                            padding: EdgeInsets.zero,
                          ),
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() => _editandoEstadoInline = true);
                            Future.microtask(
                              () => FocusScope.of(
                                context,
                              ).requestFocus(_focusEstado),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: BurbujaEstado(
                                  texto: _controladorEstado.text.trim(),
                                  fontSize: 13,
                                  compacta: true,
                                  ajustarAnchoAlTexto: true,
                                  maxLines: 2,
                                  centrar: false,
                                ),
                              ),
                              const SizedBox(width: 7),
                              _hintLapiz(),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            if (_editandoEstadoInline)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    color: ColoresApp.principalMarca,
                    borderRadius: BorderRadius.circular(18),
                    onPressed: _guardando ? null : _guardarEstadoInline,
                    child: _guardando
                        ? const FernecitoLoader.inline(
                            size: 16,
                            color: Colors.white,
                          )
                        : Text(
                            'Guardar',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerMiPerfil() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isNarrow = screenWidth < 400;
    final avatarSize = isNarrow ? 82.0 : (screenHeight < 700 ? 91.0 : 101.0);
    final ig = (_instagramUrl ?? '').trim();
    final tt = (_tiktokUrl ?? '').trim();
    final fondoBanner = _bannerPerfilUrl ?? _fotoPerfilUrl ?? '';

    return BannerPerfilUsuario(
      imagenFondo: fondoBanner,
      conRedesSociales: _perfilPublico,
      accionBanner: _botonCambiarBanner(),
      avatar: _buildAvatarBannerMiPerfil(avatarSize),
      nombre: _buildNombreBannerMiPerfil(),
      estado: _buildEstadoBannerMiPerfil(screenWidth * 0.88),
      redesSociales: _perfilPublico
          ? RedesSocialesBannerPerfil(
              instagramUrl: ig,
              tiktokUrl: tt,
              onInstagram: ig.isNotEmpty ? () => _abrirUrlRed(ig) : null,
              onTikTok: tt.isNotEmpty ? () => _abrirUrlRed(tt) : null,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return CupertinoPageScaffold(
        backgroundColor: ColoresApp.fondoPrincipal,
        child: SkeletonPantallaMiPerfil(),
      );
    }

    final padding = MediaQuery.of(context).padding;
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildBannerMiPerfil()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 18, 24, padding.bottom + 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Center(
                    child: Text(
                      'Mi cuenta Fernecito',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.principalMarca,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _copiarUsername,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@$_username',
                            style: GoogleFonts.baloo2(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.textoSecundario,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 14,
                            color: ColoresApp.principalMarca,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _statStripMiPerfil(),
                  const SizedBox(height: 12),
                  CarruselLugaresMegusta(
                    items: _lugaresMegusta,
                    vacioTexto: 'Todavía no marcaste lugares con me gusta',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _chipEditableMP(
                        icono: CupertinoIcons.gift_fill,
                        texto: _textoCumple,
                        // El cumple queda fijo una vez cargado (como el username).
                        editable: _fechaNacimiento == null,
                        onEditar: _actualizarEdad,
                      ),
                      _chipEditableMP(
                        icono: CupertinoIcons.person_2_fill,
                        texto: _textoSexo,
                        editable: true,
                        onEditar: _editarSexo,
                      ),
                      _chipEditableMP(
                        icono: CupertinoIcons.location_solid,
                        texto: _textoUbicacion.isEmpty
                            ? 'Tu ubicación'
                            : _textoUbicacion,
                        // Read-only: la ubicación se edita solo desde la cartelera.
                        editable: false,
                        onEditar: _editarUbicacion,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _construirSeccionSocial(),
                  const SizedBox(height: 24),
                  _construirSelectorTema(),
                  const SizedBox(height: 24),
                  _cardSoporte(),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ColoresApp.peligroMarca.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Zona de peligro',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.peligroMarca,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: const Color(0xFF5A2EFF),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PantallaCambiarContrasena(),
                            ),
                          ),
                          child: Text(
                            'Cambiar contraseña',
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: ColoresApp.textoPrincipal,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _cerrarSesion,
                          child: Text(
                            'Cerrar sesión',
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.fondoPrincipal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _eliminarCuenta,
                          child: Text(
                            'Eliminar cuenta',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              color: ColoresApp.peligroMarca.withOpacity(0.7),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSelectorTema() {
    final tema = TemaFernecito.instancia;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18),
      child: Column(
        children: [
          Text(
            'Elegí tu tema Fernecito',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColoresApp.textoPrincipal,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final seleccionado = tema.indiceActual == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () async {
                    await tema.establecerIndice(i);
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TemaFernecito.colores[i],
                      boxShadow: seleccionado
                          ? [
                              BoxShadow(
                                color: TemaFernecito.colores[i].withOpacity(
                                  0.5,
                                ),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionSocial() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _perfilPublico
                    ? CupertinoIcons.eye_fill
                    : CupertinoIcons.lock_fill,
                color: ColoresApp.textoPrincipal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _perfilPublico ? 'Visibilidad en Explorar' : 'Perfil privado',
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  (_perfilPublico
                          ? ColoresApp.principalMarca
                          : ColoresApp.textoSecundario)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _perfilPublico ? 'Perfil público' : 'Perfil privado',
                        style: GoogleFonts.baloo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: _perfilPublico,
                      activeTrackColor: ColoresApp.principalMarca,
                      onChanged: _guardando
                          ? null
                          : (valor) {
                              setState(() => _perfilPublico = valor);
                              _actualizarPerfilPublico(valor);
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_perfilPublico) ...[
                  Text(
                    'Aparecés con nombre, estado y foto en Explorar de tu ciudad y en las pools de eventos. Tus amigos siempre ven tu perfil completo.',
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
                      height: 1.35,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chipVisibilidad(CupertinoIcons.compass, 'Explorar'),
                      _chipVisibilidad(CupertinoIcons.person_2_fill, 'Pools'),
                      _chipVisibilidad(
                        CupertinoIcons.chat_bubble_text_fill,
                        'Tu estado',
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'No se muestran datos personales, redes sociales ni actividad. En Explorar y pools solo ven tu @username y tu avatar.',
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
                      height: 1.35,
                      color: ColoresApp.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.principalMarca.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.sparkles,
                          size: 16,
                          color: ColoresApp.principalMarca,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Activalo para aparecer en Explorar, en pools y conocer gente.',
                            style: GoogleFonts.baloo2(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: ColoresApp.principalMarca,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: ColoresApp.fondoPrincipal.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const PantallaSocial(
                      vista: SocialVista.squads,
                      mostrarVolver: true,
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.person_3_fill,
                    color: ColoresApp.principalMarca,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ver mis squads',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_perfilPublico) ...[
            const SizedBox(height: 24),
            Text(
              'Redes en tu perfil',
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColoresApp.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Opcional. Solo visibles si tu perfil es público o sos amigo.',
              style: GoogleFonts.baloo2(
                fontSize: 12,
                color: ColoresApp.textoSecundario,
              ),
            ),
            const SizedBox(height: 16),
            _construirCampoRedModerno(
              icono: FontAwesomeIcons.instagram,
              etiqueta: 'Tu Instagram',
              valor: _instagramUrl,
              controlador: _controladorInstagram,
              onGuardar: _actualizarInstagram,
            ),
            const SizedBox(height: 16),
            _construirCampoRedModerno(
              icono: FontAwesomeIcons.tiktok,
              etiqueta: 'Tu TikTok',
              valor: _tiktokUrl,
              controlador: _controladorTikTok,
              onGuardar: _actualizarTikTok,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipVisibilidad(IconData icono, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColoresApp.principalMarca.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: ColoresApp.principalMarca),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: ColoresApp.principalMarca,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCampoRedModerno({
    required IconData icono,
    required String etiqueta,
    required String? valor,
    required TextEditingController controlador,
    required VoidCallback onGuardar,
  }) {
    final bool tieneValor = valor != null && valor.isNotEmpty;
    final String valorMostrado = tieneValor
        ? _truncarTexto(valor, 35)
        : 'No configurado';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              FaIcon(icono, size: 16, color: ColoresApp.principalMarca),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valorMostrado,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tieneValor
                            ? ColoresApp.textoPrincipal
                            : ColoresApp.textoSecundario,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Check icon (verde si tiene valor, blanco si no)
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _mostrarDialogoEditarRed(
            etiqueta: etiqueta,
            controlador: controlador,
            onGuardar: onGuardar,
          ),
          child: Icon(
            tieneValor
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            color: tieneValor
                ? ColoresApp.principalMarca
                : ColoresApp.textoPrincipal.withOpacity(0.3),
            size: 24,
          ),
        ),
      ],
    );
  }

  // Diálogo para editar red social
  Future<void> _mostrarDialogoEditarRed({
    required String etiqueta,
    required TextEditingController controlador,
    required VoidCallback onGuardar,
  }) async {
    final tempController = TextEditingController(text: controlador.text);

    // Placeholder específico según la red
    final placeholder = etiqueta.contains('Instagram')
        ? 'https://instagram.com/tu_usuario'
        : 'https://tiktok.com/@tu_usuario';

    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(etiqueta),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: tempController,
            placeholder: placeholder,
            autofocus: true,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              controlador.text = tempController.text;
              Navigator.of(context).pop();
              onGuardar();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
