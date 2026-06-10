/// Pantalla de creación/completado de perfil de usuario.
///
/// REGLAS ESTRICTAS:
/// - Una foto por usuario: usuarios/<uid>/avatar.webp (o avatar.jpg si fallback)
/// - Path fijo, siempre con upsert: true
/// - DB: foto_perfil_url guarda SOLO el path relativo (sin query params)
/// - Anti-cache: agregar ?v=timestamp al mostrar, no al guardar
/// - Obligatorio: username + nombre
/// - Opcional: edad, foto, perfil_publico, redes
/// - perfil_completo = true cuando username + nombre existen
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/comprimir_imagen_storage.dart';
import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../core/tema_fernecito.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import 'pantalla_home.dart';

class PantallaCrearPerfil extends StatefulWidget {
  const PantallaCrearPerfil({super.key});

  @override
  State<PantallaCrearPerfil> createState() => _PantallaCrearPerfilState();
}

class _PantallaCrearPerfilState extends State<PantallaCrearPerfil> {
  // Controladores
  final TextEditingController _controladorUsername = TextEditingController();
  final TextEditingController _controladorNombre = TextEditingController();
  final TextEditingController _controladorInstagram = TextEditingController();
  final TextEditingController _controladorTikTok = TextEditingController();

  // Estado
  int? _edadSeleccionada; // Opcional
  Uint8List? _imagenBytes;
  bool _perfilPublico = false;
  bool _validandoUsername = false;
  bool _usernameDisponible = false;
  bool _usernameValidado = false;
  bool _guardandoPerfil = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _controladorUsername.dispose();
    _controladorNombre.dispose();
    _controladorInstagram.dispose();
    _controladorTikTok.dispose();
    super.dispose();
  }

  // Validar si el username está disponible
  Future<void> _validarUsername() async {
    final username = _controladorUsername.text.trim();

    if (username.isEmpty) {
      _mostrarError('Por favor ingresa un username');
      return;
    }

    if (username.length < 3) {
      _mostrarError('El username debe tener al menos 3 caracteres');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      _mostrarError('Solo letras, números y guión bajo (_)');
      return;
    }

    setState(() {
      _validandoUsername = true;
      _usernameValidado = false;
    });

    try {
      final supabase = ServicioSupabase();

      final respuesta = await supabase.cliente
          .from('perfiles_usuarios')
          .select('username')
          .eq('username', username.toLowerCase())
          .maybeSingle();

      if (respuesta == null) {
        setState(() {
          _usernameDisponible = true;
          _usernameValidado = true;
        });
        _mostrarExito('¡Username disponible! 🎉');
      } else {
        setState(() {
          _usernameDisponible = false;
          _usernameValidado = true;
        });
        _mostrarError('Este username ya está en uso 😔');
      }
    } catch (error) {
      print('❌ Error validando username: $error');
      _mostrarError('Error al validar username. Intenta de nuevo.');
    } finally {
      setState(() {
        _validandoUsername = false;
      });
    }
  }

  // Seleccionar foto desde galería o cámara
  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (imagen != null) {
        final bytes = await imagen.readAsBytes();
        if (!mounted) return;
        setState(() => _imagenBytes = bytes);
      }
    } catch (error) {
      print('❌ Error seleccionando foto: $error');
      _mostrarError('Error al seleccionar foto');
    }
  }

  // SUBIR FOTO CON PATH FIJO Y UPSERT
  /// Sube la foto con path fijo: usuarios/<uid>/avatar.webp (o .jpg)
  /// Siempre usa upsert: true para reemplazar la anterior.
  /// Retorna el path relativo (sin URL) o null si falla.
  Future<String?> _subirFotoConPathFijo(String userId) async {
    if (_imagenBytes == null) {
      return null;
    }

    try {
      final supabase = ServicioSupabase();

      print('🔄 Comprimiendo imagen...');
      final comprimida = await comprimirImagenStorage(
        _imagenBytes!,
        perfil: PerfilImagenStorage.avatarUsuario,
      );

      final extension = comprimida.extension;
      final pathRelativo = 'usuarios/$userId/avatar.$extension';

      print('📤 Subiendo foto a Storage...');
      print('   Bucket: avatars');
      print('   Path: $pathRelativo');
      print('   Upsert: true');

      final contentType = comprimida.contentType;
      final bytes = comprimida.bytes;

      // Subir con upsert (reemplaza si ya existe)
      try {
        await supabase.cliente.storage.from('avatars').uploadBinary(
              pathRelativo,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: true, // CRÍTICO: reemplaza la foto anterior
              ),
            );

        print('✅ Foto subida exitosamente: $pathRelativo');
        return pathRelativo;
      } on StorageException catch (storageError) {
        // Manejo específico de errores de Storage
        print('❌ StorageException:');
        print('   statusCode: ${storageError.statusCode}');
        print('   message: ${storageError.message}');

        String mensajeError;
        switch (storageError.statusCode) {
          case '403':
            mensajeError =
                'Permisos insuficientes para subir la foto.\n\nVerifica las políticas de Storage en Supabase.';
            break;
          case '409':
            mensajeError =
                'Conflicto al subir la foto.\n\nIntenta de nuevo o contacta a soporte.';
            break;
          case '413':
            mensajeError = 'La foto es demasiado grande.\n\nElige una más pequeña.';
            break;
          default:
            mensajeError =
                'Error al subir la foto (${storageError.statusCode}).\n\n${storageError.message}';
        }

        throw Exception(mensajeError);
      }
    } catch (error) {
      print('❌ Error subiendo foto: $error');

      // Re-lanzar con mensaje claro si es un Exception
      if (error is Exception) {
        rethrow;
      }

      // Error de red u otro
      if (error.toString().toLowerCase().contains('network') ||
          error.toString().toLowerCase().contains('connection')) {
        throw Exception(
          'Error de conexión al subir la foto.\n\nVerifica tu internet e intenta de nuevo.',
        );
      }

      throw Exception('Error inesperado al subir la foto.\n\n$error');
    }
  }

  // CREAR PERFIL
  Future<void> _crearPerfil() async {
    // Validaciones obligatorias: username + nombre
    if (!_usernameValidado || !_usernameDisponible) {
      _mostrarError('Por favor valida tu username primero');
      return;
    }

    final nombreIngresado = _controladorNombre.text.trim();
    if (nombreIngresado.isEmpty) {
      _mostrarError('Por favor ingresa tu nombre o apodo');
      return;
    }

    // Si no hay foto, mostrar diálogo de confirmación
    if (_imagenBytes == null) {
      final continuar = await _mostrarDialogoSinFoto();
      if (continuar != true) {
        return; // Usuario canceló
      }
    }

    setState(() {
      _guardandoPerfil = true;
    });

    String? pathFotoRelativo;

    try {
      final supabase = ServicioSupabase();
      final usuario = supabase.usuarioActual;

      if (usuario == null) {
        throw Exception('No hay usuario autenticado');
      }

      // 1. Subir foto si fue seleccionada
      if (_imagenBytes != null) {
        print('📸 Procesando foto de perfil...');

        pathFotoRelativo = await _subirFotoConPathFijo(usuario.id);

        if (pathFotoRelativo == null) {
          throw Exception(
            'No se pudo subir la foto de perfil.\n\nIntenta de nuevo o continúa sin foto.',
          );
        }

        print('✅ Foto procesada: $pathFotoRelativo');
      } else {
        print('ℹ️ Continuando sin foto');
      }

      // 2. Preparar datos del perfil
      final datosPerfil = <String, dynamic>{
        'id': usuario.id,
        'username': _controladorUsername.text.trim().toLowerCase(),
        'nombre': nombreIngresado,
        // Opcionales
        'edad': _edadSeleccionada, // Puede ser null
        'foto_perfil_url': pathFotoRelativo, // Path relativo o null
        'perfil_publico': _perfilPublico,
        'instagram_url':
            _perfilPublico && _controladorInstagram.text.trim().isNotEmpty
                ? _controladorInstagram.text.trim()
                : null,
        'tiktok_url': _perfilPublico && _controladorTikTok.text.trim().isNotEmpty
            ? _controladorTikTok.text.trim()
            : null,
        // Regla: perfil_completo = true cuando username + nombre existen
        'perfil_completo': true,
        'creacion': DateTime.now().toIso8601String(),
      };

      print('💾 Guardando perfil en perfiles_usuarios...');
      print('📋 Datos: ${datosPerfil.keys.join(", ")}');

      // 3. Upsert en base de datos
      await supabase.cliente.from('perfiles_usuarios').upsert(datosPerfil);

      print('✅ Perfil creado exitosamente');

      if (mounted) {
        // Navegar inmediatamente a Home sin diálogos
        // (más rápido y evita conflictos)
        print('➡️ Navegando a Home...');
        
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (context) => const PantallaHome()),
        );
      }
    } on PostgrestException catch (errorPostgrest) {
      print('❌ Error PostgreSQL: ${errorPostgrest.message}');
      print('❌ Código: ${errorPostgrest.code}');

      if (mounted) {
        // Detectar username duplicado
        if (errorPostgrest.message.toLowerCase().contains('duplicate') ||
            errorPostgrest.message.toLowerCase().contains('unique') ||
            errorPostgrest.code == '23505') {
          _mostrarError(
            'El username ya está en uso, elige otro.\n\nPor favor valida nuevamente.',
          );
          setState(() {
            _usernameValidado = false;
            _usernameDisponible = false;
          });
        } else {
          _mostrarError(
            'Error al guardar en la base de datos.\n\n${errorPostgrest.message}',
          );
        }
      }
    } catch (error) {
      print('❌ Error general creando perfil: $error');
      print('❌ Tipo: ${error.runtimeType}');

      if (mounted) {
        String mensajeError = 'Error al crear perfil.';

        // Extraer mensaje de Exception
        if (error is Exception) {
          mensajeError = error.toString().replaceAll('Exception: ', '');
        } else if (error.toString().toLowerCase().contains('network') ||
            error.toString().toLowerCase().contains('connection')) {
          mensajeError = 'Error de conexión.\n\nVerifica tu internet.';
        } else {
          mensajeError = 'Error inesperado.\n\nIntenta de nuevo.';
        }

        _mostrarError(mensajeError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardandoPerfil = false;
        });
      }
    }
  }

  // Diálogo para continuar sin foto
  Future<bool?> _mostrarDialogoSinFoto() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            const Icon(CupertinoIcons.photo, color: ColoresApp.promoMarca),
            const SizedBox(width: 8),
            const Text('Foto de perfil'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Text(
            'Podés continuar sin foto y cargarla después desde tu perfil.',
            style: GoogleFonts.baloo2(fontSize: 15),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Agregar foto',
              style: GoogleFonts.baloo2(
                color: ColoresApp.principalMarca,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Seguir igual',
              style: GoogleFonts.baloo2(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Mostrar opciones de foto
  void _mostrarOpcionesFoto() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'Elige una foto',
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
                    fontSize: 16,
                    color: ColoresApp.principalMarca,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              _seleccionarFoto(ImageSource.camera);
            },
          ),
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
              _seleccionarFoto(ImageSource.gallery);
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

  // Mostrar error
  void _mostrarError(String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: ColoresApp.peligroMarca,
            ),
            const SizedBox(width: 8),
            const Text('Error'),
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
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(
              CupertinoIcons.check_mark_circled,
              color: ColoresApp.principalMarca,
            ),
            const SizedBox(width: 8),
            const Text('Éxito'),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(mensaje),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Continuar'),
            onPressed: () => Navigator.of(context).pop(),
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
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, padding.top + 24, 24, padding.bottom + 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(CupertinoIcons.back, color: ColoresApp.principalMarca),
                    ),
                    Expanded(
                      child: Text(
                        'Crear Perfil',
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.principalMarca,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 16),
                _construirSelectorTemaRapido(),
                const SizedBox(height: 16),
                // Título principal
                Center(
                  child: Text(
                    'Completá tu perfil',
                    style: GoogleFonts.baloo2(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ColoresApp.textoPrincipal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtítulo
                Center(
                  child: Text(
                    'Solo username y nombre son obligatorios\nLo demás es opcional',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      color: ColoresApp.textoSecundario,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // PASO 1: Usuario y Nombre (OBLIGATORIOS)
                _construirSeccionTitulo('1. Tu identidad ⭐'),

                const SizedBox(height: 16),

                _construirCampoUsername(),

                const SizedBox(height: 16),

                _construirCampoNombre(),

                const SizedBox(height: 32),

                // PASO 2: Edad y Foto (OPCIONALES)
                _construirSeccionTitulo('2. Edad y foto (opcional)'),

                const SizedBox(height: 16),

                _construirSelectorEdad(),

                const SizedBox(height: 16),

                _construirSelectorFoto(),

                const SizedBox(height: 32),

                // PASO 3: Perfil Público y Redes (OPCIONALES)
                _construirSeccionTitulo('3. Perfil público (opcional)'),

                const SizedBox(height: 16),

                _construirSwitchPerfilPublico(),

                // Campos de redes sociales (solo si perfil es público)
                if (_perfilPublico) ...[
                  const SizedBox(height: 16),
                  _construirCampoInstagram(),
                  const SizedBox(height: 16),
                  _construirCampoTikTok(),
                ],

                const SizedBox(height: 40),

                // Botón Crear Perfil
                _construirBotonCrearPerfil(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirSeccionTitulo(String titulo) {
    return Text(
      titulo,
      style: GoogleFonts.baloo2(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ColoresApp.principalMarca,
      ),
    );
  }

  Widget _construirSelectorTemaRapido() {
    final tema = TemaFernecito.instancia;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TemaFernecito.colores[i],
                  border: Border.all(
                    color: seleccionado ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _construirCampoUsername() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige un username único',
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSuperficie,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      '@',
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ColoresApp.principalMarca,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField(
                        controller: _controladorUsername,
                        placeholder: 'usuario',
                        placeholderStyle: TextStyle(
                          color: ColoresApp.textoSecundario,
                        ),
                        style: const TextStyle(
                          color: ColoresApp.textoPrincipal,
                          fontSize: 16,
                        ),
                        decoration: const BoxDecoration(),
                        onChanged: (_) {
                          setState(() {
                            _usernameValidado = false;
                            _usernameDisponible = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _validandoUsername ? null : _validarUsername,
              child: Container(
                width: 100,
                height: 50,
                decoration: BoxDecoration(
                  color: _validandoUsername
                      ? ColoresApp.principalMarca.withOpacity(0.5)
                      : ColoresApp.principalMarca,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: _validandoUsername
                      ? const CupertinoActivityIndicator(
                          color: ColoresApp.textoPrincipal,
                        )
                      : Text(
                          'Validar',
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColoresApp.textoPrincipal,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        if (_usernameValidado)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16),
            child: Row(
              children: [
                Icon(
                  _usernameDisponible
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.xmark_circle_fill,
                  color: _usernameDisponible
                      ? ColoresApp.principalMarca
                      : ColoresApp.peligroMarca,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _usernameDisponible ? '¡Disponible!' : 'Ya está en uso',
                  style: GoogleFonts.baloo2(
                    fontSize: 13,
                    color: _usernameDisponible
                        ? ColoresApp.principalMarca
                        : ColoresApp.peligroMarca,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _construirCampoNombre() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu nombre o apodo',
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(25),
          ),
          child: CupertinoTextField(
            controller: _controladorNombre,
            placeholder: 'Nombre',
            placeholderStyle: TextStyle(color: ColoresApp.textoSecundario),
            style: const TextStyle(
              color: ColoresApp.textoPrincipal,
              fontSize: 16,
            ),
            decoration: const BoxDecoration(),
          ),
        ),
      ],
    );
  }

  Widget _construirSelectorEdad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tu edad',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.textoSecundario,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ColoresApp.promoMarca.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'opcional',
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  color: ColoresApp.promoMarca,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _edadSeleccionada != null
                    ? '$_edadSeleccionada años'
                    : 'No especificada',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  color: _edadSeleccionada != null
                      ? ColoresApp.textoPrincipal
                      : ColoresApp.textoSecundario,
                  fontWeight: FontWeight.w600,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: ColoresApp.principalMarca,
                ),
                onPressed: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (_) => Container(
                      height: 250,
                      color: ColoresApp.fondoSuperficie,
                      child: Column(
                        children: [
                          Container(
                            height: 44,
                            color: ColoresApp.fondoPrincipal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                CupertinoButton(
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.baloo2(
                                      color: ColoresApp.principalMarca,
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                CupertinoButton(
                                  child: Text(
                                    'Listo',
                                    style: GoogleFonts.baloo2(
                                      color: ColoresApp.principalMarca,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: _edadSeleccionada != null
                                    ? _edadSeleccionada! - 1
                                    : 17,
                              ),
                              itemExtent: 32,
                              onSelectedItemChanged: (int index) {
                                setState(() {
                                  _edadSeleccionada = index + 1;
                                });
                              },
                              children: List<Widget>.generate(100, (int index) {
                                return Center(
                                  child: Text(
                                    '${index + 1} años',
                                    style: GoogleFonts.baloo2(
                                      color: ColoresApp.textoPrincipal,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirSelectorFoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Foto de perfil',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: ColoresApp.textoSecundario,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: ColoresApp.promoMarca.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'opcional',
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  color: ColoresApp.promoMarca,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _mostrarOpcionesFoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresApp.fondoSuperficie,
                border: Border.all(color: ColoresApp.principalMarca, width: 3),
              ),
              child: _imagenBytes != null
                  ? ClipOval(
                      child: Image.memory(
                        _imagenBytes!,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      ),
                    )
                  : Icon(
                      CupertinoIcons.camera,
                      size: 50,
                      color: ColoresApp.principalMarca,
                    ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              _imagenBytes == null
                  ? 'Toca para elegir una foto'
                  : 'Toca para cambiar',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirSwitchPerfilPublico() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Perfil público?',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              CupertinoSwitch(
                value: _perfilPublico,
                activeTrackColor: ColoresApp.principalMarca,
                onChanged: (valor) {
                  setState(() {
                    _perfilPublico = valor;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Explorá quiénes van a los lugares que visitás y conocé gente nueva.',
            style: GoogleFonts.baloo2(
              fontSize: 12,
              color: ColoresApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCampoInstagram() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instagram (opcional)',
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.instagram,
                color: ColoresApp.principalMarca,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField(
                  controller: _controladorInstagram,
                  placeholder: 'URL de perfil',
                  placeholderStyle: const TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 14,
                  ),
                  style: const TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 14,
                  ),
                  decoration: const BoxDecoration(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirCampoTikTok() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TikTok (opcional)',
          style: GoogleFonts.baloo2(
            fontSize: 14,
            color: ColoresApp.textoSecundario,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.tiktok,
                color: ColoresApp.principalMarca,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoTextField(
                  controller: _controladorTikTok,
                  placeholder: 'URL de perfil',
                  placeholderStyle: const TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 14,
                  ),
                  style: const TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 14,
                  ),
                  decoration: const BoxDecoration(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirBotonCrearPerfil() {
    return Center(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _guardandoPerfil ? null : _crearPerfil,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 56,
          decoration: BoxDecoration(
            color: _guardandoPerfil
                ? ColoresApp.principalMarca.withOpacity(0.5)
                : ColoresApp.principalMarca,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: _guardandoPerfil
                ? const CupertinoActivityIndicator(
                    color: ColoresApp.textoPrincipal,
                  )
                : Text(
                    'Crear Perfil',
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.textoPrincipal,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
