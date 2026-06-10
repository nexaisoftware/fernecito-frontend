/// Pantalla Mi Perfil - Pulida y Moderna
///
/// Permite ver y editar el perfil del usuario con estilo iOS moderno:
/// - Foto de perfil con edición (tomar/galería/eliminar)
/// - Username, nombre, edad
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
import '../core/servicio_perfil_usuario.dart';
import '../core/supabase_client.dart';
import '../core/tema_fernecito.dart';
import '../core/ubicaciones_data.dart';
import 'pantalla_cambiar_contrasena.dart';
import 'pantalla_social.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/filtro_ubicaciones_sheet.dart';
import '../widgets/icono_local.dart';
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
  bool _perfilPublico = false;
  String? _instagramUrl;
  String? _tiktokUrl;
  String? _miEstado;
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;
  bool _editandoNombreInline = false;
  bool _editandoEstadoInline = false;

  String _ciudad = '';
  String _provincia = '';
  int _cantidadAmigos = 0;
  int _localesVisitados = 0;
  int _eventosAsistidos = 0;
  bool _cargandoMetricas = true;

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
          _edad = respuesta['edad'];
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
            _fotoPerfilUrl = '${supabase.cliente.storage
                    .from('avatars')
                    .getPublicUrl(path)}?v=$timestamp';
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
                Icon(CupertinoIcons.camera,
                    color: ColoresApp.principalMarca),
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
                Icon(CupertinoIcons.photo,
                    color: ColoresApp.principalMarca),
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
                  const Icon(CupertinoIcons.trash,
                      color: ColoresApp.peligroMarca),
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
                        child: Center(
                          child: CupertinoActivityIndicator(
                            color: ColoresApp.principalMarca,
                            radius: 20,
                          ),
                        ),
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (imagen == null) return;

      setState(() {
        _subiendoFoto = true;
      });

      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      final comprimida = await comprimirDesdeXFile(
        imagen,
        perfil: PerfilImagenStorage.avatarUsuario,
      );

      final extension = comprimida.extension;
      final pathRelativo = 'usuarios/${usuario.id}/avatar.$extension';
      final bytes = comprimida.bytes;
      final contentType = comprimida.contentType;

      print('📤 Subiendo foto actualizada...');

      // Subir con upsert

      await supabase.cliente.storage.from('avatars').uploadBinary(
            pathRelativo,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      print('✅ Foto actualizada: $pathRelativo');

      // Actualizar DB
      await supabase.cliente.from('perfiles_usuarios').update({
        'foto_perfil_url': pathRelativo,
      }).eq('id', usuario.id);

      // Recargar perfil
      await _cargarDatosPerfil();

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
      await supabase.cliente.from('perfiles_usuarios').update({
        'foto_perfil_url': null,
      }).eq('id', usuario.id);

      // Recargar perfil
      await _cargarDatosPerfil();

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
    setState(() => _cargandoMetricas = true);
    final detFuture = _srvPerfil.detalle(idUsuario);
    final amistadesFuture = ServicioAmigos().listar();
    final det = await detFuture;
    final amistades = await amistadesFuture;
    if (!mounted) return;
    setState(() {
      _cargandoMetricas = false;
      // Misma fuente que la pestaña Social (amistad_listar).
      _cantidadAmigos = amistades.amigos.length;
      if (det != null) {
        _localesVisitados =
            ServicioPerfilUsuario.enteroDeDetalle(det, 'locales_visitados');
        _eventosAsistidos =
            ServicioPerfilUsuario.enteroDeDetalle(det, 'eventos_asistidos');
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
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      await supabase.cliente.from('perfiles_usuarios').update({
        'provincia': res.provincia,
        'ciudad': res.ciudad,
      }).eq('id', usuario.id);

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

  // Actualizar edad
  Future<void> _actualizarEdad() async {
    final nuevaEdad = await _mostrarDialogoEditar(
      titulo: '¿Cuántos años tenés?',
      valorActual: _edad?.toString() ?? '',
      placeholder: 'Ej: 25',
      tipoTeclado: TextInputType.number,
    );

    if (nuevaEdad != null && nuevaEdad.trim().isNotEmpty) {
      final edadInt = int.tryParse(nuevaEdad.trim());
      if (edadInt != null && edadInt > 0 && edadInt <= 120) {
        await _actualizarCampo('edad', edadInt);
      } else {
        _mostrarError('Ingresa una edad válida');
      }
    }
  }

  // Actualizar perfil público (las redes pueden quedar guardadas; no se muestran si es privado).
  Future<void> _actualizarPerfilPublico(bool valor) async {
    setState(() => _guardando = true);
    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;
      if (usuario == null) throw Exception('No hay usuario autenticado');

      await supabase.cliente.from('perfiles_usuarios').update({
        'perfil_publico': valor,
      }).eq('id', usuario.id);

      await _cargarDatosPerfil();
      if (mounted) _mostrarExito('Cambios guardados correctamente');
    } catch (error) {
      debugPrint('❌ Error actualizando perfil_publico: $error');
      await _cargarDatosPerfil();
      if (mounted) _mostrarError('No se pudo cambiar la visibilidad del perfil');
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

      await supabase.cliente.from('perfiles_usuarios').update({
        campo: valor,
      }).eq('id', usuario.id);

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

  // Eliminar cuenta
  Future<void> _eliminarCuenta() async {
    final confirmado = await _mostrarDialogoConfirmacion(
      titulo: '¿Eliminar cuenta?',
      mensaje:
          'Esta acción no se puede deshacer. Se eliminarán todos tus datos de forma permanente.',
      textoConfirmar: 'Eliminar',
      esDestructivo: true,
    );

    if (confirmado != true) return;

    try {
      print('🗑️ Eliminando cuenta...');
      
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      // 1. Eliminar registro de perfiles_usuarios
      print('🗑️ Eliminando perfil de DB...');
      await supabase.cliente
          .from('perfiles_usuarios')
          .delete()
          .eq('id', usuario.id);

      print('✅ Perfil eliminado de DB');

      // 2. Cerrar sesión (esto también elimina la sesión de Auth)
      print('🔓 Cerrando sesión...');
      await supabase.cliente.auth.signOut();

      print('✅ Cuenta eliminada y sesión cerrada');
      print('⏳ AuthGate manejará la navegación a Login automáticamente');

      // NO navegar manualmente - AuthGate se encarga
      // El evento signedOut será detectado y navegará a PantallaLogin
    } catch (error) {
      print('❌ Error eliminando cuenta: $error');
      if (mounted) {
        _mostrarError('Error al eliminar cuenta.\n\nIntentá de nuevo.');
      }
    }
  }

  // Mostrar diálogo de edición
  Future<String?> _mostrarDialogoEditar({
    required String titulo,
    required String valorActual,
    required String placeholder,
    TextInputType tipoTeclado = TextInputType.text,
  }) {
    final controller = TextEditingController(text: valorActual);

    return showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(titulo),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            keyboardType: tipoTeclado,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
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
            Icon(CupertinoIcons.exclamationmark_circle,
                color: ColoresApp.peligroMarca),
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
            Icon(CupertinoIcons.check_mark_circled,
                color: ColoresApp.principalMarca),
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
        corto: false,
        child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, padding.top + 24, 24, padding.bottom + 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mi cuenta Fernecito',
                    style: GoogleFonts.baloo2(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.principalMarca,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nombre inline editable
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¿Cómo te llamamos?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 40,
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
                                              fontSize: 22,
                                              color: ColoresApp.textoSecundario.withOpacity(0.7),
                                            ),
                                            style: GoogleFonts.baloo2(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                              color: ColoresApp.textoPrincipal,
                                            ),
                                            decoration: null,
                                            padding: EdgeInsets.zero,
                                          )
                                        : GestureDetector(
                                            onTap: () {
                                              setState(() => _editandoNombreInline = true);
                                              Future.microtask(() => FocusScope.of(context).requestFocus(_focusNombre));
                                            },
                                            child: Text(
                                              _controladorNombre.text.trim().isEmpty
                                                  ? 'Tu nombre o apodo'
                                                  : _controladorNombre.text.trim(),
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.baloo2(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color: _controladorNombre.text.trim().isEmpty
                                                    ? ColoresApp.textoSecundario.withOpacity(0.7)
                                                    : ColoresApp.textoPrincipal,
                                              ),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      color: ColoresApp.principalMarca,
                                      borderRadius: BorderRadius.circular(20),
                                      onPressed: _guardando ? null : _guardarNombreInline,
                                      child: _guardando
                                          ? const CupertinoActivityIndicator(color: Colors.white)
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Avatar circular con botón de editar (debajo del nombre)
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _fotoPerfilUrl != null
                            ? () => _mostrarFotoFullscreen()
                            : null,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ColoresApp.principalMarca,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: _subiendoFoto
                                ? Center(
                                    child: CupertinoActivityIndicator(
                                      color: ColoresApp.principalMarca,
                                    ),
                                  )
                                : _fotoPerfilUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: _fotoPerfilUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: ColoresApp.fondoSuperficie,
                                          child: Center(
                                            child: CupertinoActivityIndicator(
                                              color: ColoresApp.principalMarca,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          CupertinoIcons.person_circle_fill,
                                          size: 80,
                                          color: ColoresApp.textoSecundario,
                                        ),
                                      )
                                    : const Icon(
                                        CupertinoIcons.person_circle_fill,
                                        size: 80,
                                        color: ColoresApp.textoSecundario,
                                      ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _mostrarOpcionesFoto,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ColoresApp.principalMarca,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ColoresApp.fondoPrincipal,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.pencil,
                              size: 18,
                              color: ColoresApp.textoPrincipal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Burbuja de estado (centrada) + acción pegada al borde derecho del contenedor
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      height: 54,
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
                                          border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.28)),
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
                                          Future.microtask(() => FocusScope.of(context).requestFocus(_focusEstado));
                                        },
                                        child: BurbujaEstado(
                                          texto: _controladorEstado.text.trim(),
                                          fontSize: 14,
                                          ajustarAnchoAlTexto: true,
                                          maxLines: 2,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  color: ColoresApp.principalMarca,
                                  borderRadius: BorderRadius.circular(18),
                                  onPressed: _guardando ? null : _guardarEstadoInline,
                                  child: _guardando
                                      ? const CupertinoActivityIndicator(color: Colors.white)
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _perfilPublico
                      ? 'Tu estado se muestra en Explorar, pools y tu perfil.'
                      : 'Con perfil privado tu estado no se muestra a otros.',
                  style: GoogleFonts.baloo2(
                    fontSize: 11,
                    color: ColoresApp.textoSecundario,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Chip username + acción copiar (debajo del estado)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: ColoresApp.fondoSuperficie.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: ColoresApp.principalMarca.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mi username: @$_username',
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _copiarUsername,
                          child: Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 16,
                            color: ColoresApp.principalMarca,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Sección: Información Personal + actividad informativa
                _construirSeccion(
                  titulo: 'Información personal',
                  icono: CupertinoIcons.person_circle,
                  children: [
                    _construirBloqueActividadInformativa(),
                    const SizedBox(height: 18),
                    _construirCampoEditable(
                      etiqueta: 'Ubicación',
                      valor: _textoUbicacion,
                      iconoLeading: CupertinoIcons.location_solid,
                      onEditar: _editarUbicacion,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Usamos tu ciudad para la cartelera y para que otros te encuentren.',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        color: ColoresApp.textoSecundario,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sección: Social (incluye perfil público, redes y mi estado)
                _construirSeccionSocial(),

                const SizedBox(height: 32),

                // Selector de tema
                _construirSelectorTema(),

                const SizedBox(height: 40),

                // Danger Zone
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ColoresApp.peligroMarca.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ColoresApp.peligroMarca.withOpacity(0.3),
                      width: 1,
                    ),
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
                      // Botón violeta: Cambiar contraseña
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
                      // Botón blanco de cerrar sesión
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
                      // Botón pequeño de eliminar cuenta
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
              ],
            ),
          ),
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
                      border: Border.all(
                        color: seleccionado ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: seleccionado
                          ? [
                              BoxShadow(
                                color: TemaFernecito.colores[i].withOpacity(0.5),
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

  Widget _construirSeccion({
    required String titulo,
    IconData? icono,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperficiesApp.card(radius: 20, temaTint: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, color: ColoresApp.textoPrincipal, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                titulo,
                style: GoogleFonts.baloo2(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.principalMarca,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
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
              color: (_perfilPublico
                      ? ColoresApp.principalMarca
                      : ColoresApp.textoSecundario)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_perfilPublico
                        ? ColoresApp.principalMarca
                        : ColoresApp.textoSecundario)
                    .withValues(alpha: 0.22),
              ),
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
                      _chipVisibilidad(
                        CupertinoIcons.compass,
                        'Explorar',
                      ),
                      _chipVisibilidad(
                        CupertinoIcons.person_2_fill,
                        'Pools',
                      ),
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
                      border: Border.all(
                        color: ColoresApp.principalMarca.withValues(alpha: 0.28),
                      ),
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
                    builder: (_) => const PantallaSocial(initialTabIndex: 1),
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

  static const double _alturaCeldaActividad = 88;

  Widget _construirBloqueActividadInformativa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final ancho = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: ancho,
                  height: _alturaCeldaActividad,
                  child: _celdaMetricaInformativa(
                    icono: CupertinoIcons.person_fill,
                    etiqueta: 'Edad',
                    valor: _edad != null ? '${_edad!} años' : '—',
                    onEditar: _actualizarEdad,
                  ),
                ),
                SizedBox(
                  width: ancho,
                  height: _alturaCeldaActividad,
                  child: _cargandoMetricas
                      ? _celdaMetricaCargando()
                      : _celdaMetricaInformativa(
                          icono: CupertinoIcons.person_2_fill,
                          etiqueta: 'Amigos',
                          valor: '$_cantidadAmigos',
                        ),
                ),
                SizedBox(
                  width: ancho,
                  height: _alturaCeldaActividad,
                  child: _cargandoMetricas
                      ? _celdaMetricaCargando()
                      : _celdaMetricaInformativa(
                          iconoWidget: IconoLocal(
                            size: 20,
                            color: ColoresApp.principalMarca,
                          ),
                          etiqueta: 'Locales visitados',
                          valor: '$_localesVisitados',
                        ),
                ),
                SizedBox(
                  width: ancho,
                  height: _alturaCeldaActividad,
                  child: _cargandoMetricas
                      ? _celdaMetricaCargando()
                      : _celdaMetricaInformativa(
                          icono: CupertinoIcons.ticket_fill,
                          etiqueta: 'Eventos vividos',
                          valor: '$_eventosAsistidos',
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _celdaMetricaCargando() {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.fondoPrincipal.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ColoresApp.principalMarca.withValues(alpha: 0.1),
        ),
      ),
      child: const Center(
        child: CupertinoActivityIndicator(radius: 10),
      ),
    );
  }

  Widget _celdaMetricaInformativa({
    IconData? icono,
    Widget? iconoWidget,
    required String etiqueta,
    required String valor,
    VoidCallback? onEditar,
  }) {
    final iconChild = iconoWidget ??
        Icon(icono, size: 20, color: ColoresApp.principalMarca);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: ColoresApp.fondoPrincipal.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ColoresApp.principalMarca.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconChild,
              const SizedBox(height: 6),
              Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                etiqueta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.textoSecundario,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        if (onEditar != null)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onEditar,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                CupertinoIcons.pencil,
                size: 16,
                color: ColoresApp.principalMarca,
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirCampoEditable({
    required String etiqueta,
    required String valor,
    required VoidCallback onEditar,
    IconData? iconoLeading,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (iconoLeading != null) ...[
                Icon(
                  iconoLeading,
                  size: 18,
                  color: ColoresApp.principalMarca.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 10),
              ],
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
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onEditar,
          child: Icon(
            CupertinoIcons.pencil,
            color: ColoresApp.principalMarca,
            size: 22,
          ),
        ),
      ],
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
    final String valorMostrado =
        tieneValor ? _truncarTexto(valor, 35) : 'No configurado';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              FaIcon(
                icono,
                size: 16,
                color: ColoresApp.principalMarca,
              ),
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
