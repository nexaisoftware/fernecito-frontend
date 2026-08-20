/// Pantalla de creación/completado de perfil de usuario.
///
/// REGLAS ESTRICTAS:
/// - Una foto por usuario: usuarios/<uid>/avatar.webp (o avatar.jpg si fallback)
/// - Path fijo, siempre con upsert: true
/// - DB: foto_perfil_url guarda SOLO el path relativo (sin query params)
/// - Anti-cache: agregar ?v=timestamp al mostrar, no al guardar
/// - Obligatorio: username + nombre + fecha_nacimiento + sexo
/// - Opcional: foto, redes, mi_estado (perfil nace público; privado se elige en Mi perfil)
/// - perfil_completo = true cuando username + nombre existen
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/comprimir_imagen_storage.dart';
import '../core/constants.dart';
import '../core/sexo_perfil.dart';
import '../core/supabase_client.dart';
import '../core/tema_fernecito.dart';
import '../widgets/fondo_gradiente_fernecito.dart';
import '../widgets/burbuja_estado.dart';
import '../widgets/recortar_avatar_sheet.dart';
import 'pantalla_home.dart';
import '../widgets/fernecito_loader.dart';
import '../widgets/dialogo_fernecito.dart';

// Textos legales mostrados en el modal de "Términos y Privacidad".
// BORRADOR de partida — revisar con criterio legal antes de producción.
const String _kTextoTerminos =
    'Al crear tu perfil aceptás usar Fernecito de forma responsable.\n\n'
    'Fernecito solo difunde eventos de terceros: no los organizamos ni nos '
    'responsabilizamos por ellos, por las decisiones del local (como el '
    'ingreso) ni por lo que ocurra en ellos.\n\n'
    '• Debés brindar información veraz y tener la edad mínima requerida para usar '
    'la app y para asistir a los eventos que reserves.\n\n'
    '• Te comprometés a respetar a los demás usuarios y a no usar la app para '
    'acoso, spam, estafas, suplantación de identidad ni contenido ilegal o que '
    'infrinja derechos de terceros.\n\n'
    '• Podemos suspender o eliminar cuentas que incumplan estas normas o que '
    'reciban reportes fundados.\n\n'
    '• El servicio se ofrece "tal cual", sin garantías de disponibilidad '
    'ininterrumpida.\n\n'
    '• Podemos actualizar estos términos; te avisaremos de los cambios '
    'importantes dentro de la app.';

const String _kTextoPrivacidad =
    'Tu privacidad nos importa.\n\n'
    '• Datos que usamos: nombre o apodo, edad, género, ciudad y provincia, foto '
    'de perfil, email de tu cuenta y, solo si lo permitís, tus redes sociales y '
    'una ubicación aproximada.\n\n'
    '• Para qué los usamos: mostrar tu perfil, armar la cartelera de tu zona, '
    'gestionar tus reservas y conectarte con otras personas y eventos.\n\n'
    '• No vendemos tus datos a terceros. Usamos proveedores de infraestructura '
    '(como Supabase) únicamente para operar el servicio.\n\n'
    '• Tu perfil público muestra solo lo que elegís; podés ponerlo privado '
    'cuando quieras.\n\n'
    '• Podés editar tus datos o eliminar tu cuenta en cualquier momento desde '
    '"Mi Perfil".\n\n'
    '• Por dudas o para ejercer tus derechos sobre tus datos, escribinos desde '
    '"Ayuda y soporte".';

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
  final TextEditingController _controladorEstado = TextEditingController();
  final FocusNode _focusEstado = FocusNode();
  bool _editandoEstado = false;

  // Estado
  DateTime? _fechaNacimientoSeleccionada; // Obligatorio
  String? _sexoSeleccionado; // Obligatorio — hombre | mujer | otro
  Uint8List? _imagenBytes;
  bool _validandoUsername = false;
  bool _usernameDisponible = false;
  bool _usernameValidado = false;
  bool _guardandoPerfil = false;
  bool _aceptoPoliticas = false; // obligatorio para crear el perfil

  // Auto-validación de username (debounce + estado inline, sin diálogos).
  Timer? _debounceUsername;
  String? _usernameMsg;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _debounceUsername?.cancel();
    _controladorUsername.dispose();
    _controladorNombre.dispose();
    _controladorInstagram.dispose();
    _controladorTikTok.dispose();
    _controladorEstado.dispose();
    _focusEstado.dispose();
    super.dispose();
  }

  // Se llama en cada cambio del campo username. Debounce 450ms → chequeo inline.
  void _onUsernameChanged(String _) {
    _debounceUsername?.cancel();
    setState(() {
      _usernameValidado = false;
      _usernameDisponible = false;
      _usernameMsg = null;
    });
    final u = _controladorUsername.text.trim();
    if (u.isEmpty) return;
    _debounceUsername = Timer(
      const Duration(milliseconds: 450),
      _chequearUsernameInline,
    );
  }

  // Valida formato + disponibilidad, mostrando el estado inline (sin diálogos).
  Future<void> _chequearUsernameInline() async {
    final username = _controladorUsername.text.trim();
    if (username.length < 3) {
      setState(() {
        _usernameValidado = true;
        _usernameDisponible = false;
        _usernameMsg = 'Mínimo 3 caracteres';
      });
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameValidado = true;
        _usernameDisponible = false;
        _usernameMsg = 'Solo letras, números y _';
      });
      return;
    }
    setState(() {
      _validandoUsername = true;
      _usernameMsg = null;
    });
    try {
      final supabase = ServicioSupabase();
      final existe = await supabase.cliente
          .from('perfiles_usuarios')
          .select('username')
          .eq('username', username.toLowerCase())
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _validandoUsername = false;
        _usernameValidado = true;
        _usernameDisponible = existe == null;
        _usernameMsg = existe == null ? '¡Disponible!' : 'Ya está en uso';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _validandoUsername = false;
        _usernameValidado = false;
        _usernameMsg = 'No se pudo verificar, reintentá';
      });
    }
  }

  // Seleccionar foto desde galería o cámara
  Future<void> _seleccionarFoto(ImageSource source) async {
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

      setState(() => _imagenBytes = bytesRecortados);
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
        await supabase.cliente.storage
            .from('avatars')
            .uploadBinary(
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
            mensajeError =
                'La foto es demasiado grande.\n\nElige una más pequeña.';
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

    if (_fechaNacimientoSeleccionada == null) {
      _mostrarError('Contanos cuándo es tu cumple para continuar');
      return;
    }

    if (!SexoPerfil.esValido(_sexoSeleccionado)) {
      _mostrarError('Elegí tu género para continuar');
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
        // Cumpleaños real. La DB mantiene edad derivada para compatibilidad.
        'fecha_nacimiento': _fechaIso(_fechaNacimientoSeleccionada!),
        'edad': _edadDesdeFecha(_fechaNacimientoSeleccionada!),
        'sexo': _sexoSeleccionado,
        'foto_perfil_url': pathFotoRelativo, // Path relativo o null
        'mi_estado': _controladorEstado.text.trim().isEmpty
            ? null
            : _controladorEstado.text.trim(),
        'perfil_publico': true,
        'instagram_url':
            _controladorInstagram.text.trim().isNotEmpty
            ? _controladorInstagram.text.trim()
            : null,
        'tiktok_url':
            _controladorTikTok.text.trim().isNotEmpty
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
    return showFernecitoDialog<bool>(
      context: context,
      builder: (context) => DialogoFernecito(
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
          AccionDialogoFernecito(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Agregar foto',
              style: GoogleFonts.baloo2(
                color: ColoresApp.principalMarca,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AccionDialogoFernecito(
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
    showFernecitoDialog(
      context: context,
      builder: (context) => DialogoFernecito(
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
          AccionDialogoFernecito(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;
    final avatarSize = (size.width * 0.30).clamp(100.0, 132.0).toDouble();
    final marca = ColoresApp.principalMarca;
    final nombreOk = _controladorNombre.text.trim().isNotEmpty;
    final puedeGuardar =
        _usernameValidado &&
        _usernameDisponible &&
        nombreOk &&
        _fechaNacimientoSeleccionada != null &&
        SexoPerfil.esValido(_sexoSeleccionado) &&
        _aceptoPoliticas &&
        !_guardandoPerfil;

    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: FondoGradienteFernecito(
        corto: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Icon(CupertinoIcons.back, color: marca),
                    ),
                    Expanded(
                      child: Text(
                        'Tu perfil',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ColoresApp.textoPrincipal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _avatar(avatarSize)),
                      const SizedBox(height: 6),
                      Center(child: _burbujaEstadoCrear()),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _imagenBytes == null
                              ? 'Tocá para agregar tu foto'
                              : 'Tocá para cambiar la foto',
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            color: ColoresApp.textoSecundario,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _seccionTema(),
                      const SizedBox(height: 22),
                      _label('Tu identidad'),
                      const SizedBox(height: 8),
                      _card([
                        _campoUsername(),
                        _hairline(),
                        _campoTexto(
                          controller: _controladorNombre,
                          placeholder: 'Tu nombre o apodo',
                          icono: Icon(
                            CupertinoIcons.person_fill,
                            size: 18,
                            color: marca,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      _label('Tu cumple'),
                      const SizedBox(height: 8),
                      _card([_filaEdad()]),
                      const SizedBox(height: 18),
                      _label('Tu género'),
                      const SizedBox(height: 8),
                      _card([_filaSexo()]),
                      const SizedBox(height: 18),
                      _label('Tus redes (opcional)'),
                      const SizedBox(height: 8),
                      _card([
                        _campoTexto(
                          controller: _controladorInstagram,
                          placeholder: 'Instagram (link o usuario)',
                          icono: const FaIcon(
                            FontAwesomeIcons.instagram,
                            size: 18,
                            color: Color(0xFFE1306C),
                          ),
                        ),
                        _hairline(),
                        _campoTexto(
                          controller: _controladorTikTok,
                          placeholder: 'TikTok (link o usuario)',
                          icono: const FaIcon(
                            FontAwesomeIcons.tiktok,
                            size: 18,
                            color: Color(0xFF00F2EA),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              // ── Barra inferior con el botón (siempre visible) ──
              Container(
                padding: EdgeInsets.fromLTRB(20, 10, 20, padding.bottom + 12),
                decoration: BoxDecoration(color: ColoresApp.fondoPrincipal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filaPoliticas(),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        color: marca,
                        disabledColor: marca.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(50),
                        onPressed: puedeGuardar ? _crearPerfil : null,
                        child: _guardandoPerfil
                            ? const FernecitoLoader.inline(
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                'Crear mi perfil',
                                style: GoogleFonts.baloo2(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
    );
  }

  // ── Checkbox de aceptación de políticas ──
  Widget _filaPoliticas() {
    final marca = ColoresApp.principalMarca;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _aceptoPoliticas = !_aceptoPoliticas),
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              // Desactivado: relleno sutil + borde gris visible (antes era
              // transparente sin borde y no se veía). Activado: color de marca.
              color: _aceptoPoliticas
                  ? marca
                  : ColoresApp.textoSecundario.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _aceptoPoliticas ? Colors.white : Colors.white,
                width: _aceptoPoliticas ? 2 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _aceptoPoliticas
                ? const Icon(
                    CupertinoIcons.checkmark,
                    size: 15,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Acepto los ',
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              GestureDetector(
                onTap: _mostrarPoliticas,
                child: Text(
                  'Términos y la Política de Privacidad',
                  style: GoogleFonts.baloo2(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: marca,
                    decoration: TextDecoration.underline,
                    decorationColor: marca,
                  ),
                ),
              ),
              Text(
                ' de Fernecito.',
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  color: ColoresApp.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarPoliticas() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final marca = ColoresApp.principalMarca;
        Widget seccion(String titulo, String cuerpo) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ColoresApp.textoPrincipal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cuerpo,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  height: 1.5,
                  color: ColoresApp.textoSecundario,
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        }

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
          decoration: BoxDecoration(
            color: ColoresApp.fondoPrincipal,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ColoresApp.textoSecundario.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Términos y Privacidad',
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ColoresApp.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        seccion('Términos y Condiciones', _kTextoTerminos),
                        seccion('Política de Privacidad', _kTextoPrivacidad),
                        Text(
                          'Última actualización: junio 2026.',
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            color: ColoresApp.textoSecundario.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: marca,
                      borderRadius: BorderRadius.circular(50),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Entendido',
                        style: GoogleFonts.baloo2(
                          fontSize: 15,
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
        );
      },
    );
  }

  /// Burbuja de estado bajo el avatar (mismo estilo que mi perfil), con
  /// placeholder gris "escribe algo divertido". Al tocar, edita inline.
  Widget _burbujaEstadoCrear() {
    final estado = _controladorEstado.text.trim();
    if (_editandoEstado) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: ColoresApp.fondoSuperficie,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: CupertinoTextField(
                  controller: _controladorEstado,
                  focusNode: _focusEstado,
                  placeholder: 'Escribí algo divertido',
                  maxLength: 50,
                  maxLines: 2,
                  minLines: 1,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: null,
                  padding: EdgeInsets.zero,
                  onSubmitted: (_) => setState(() => _editandoEstado = false),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _editandoEstado = false),
                child: Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 22,
                  color: ColoresApp.principalMarca,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() => _editandoEstado = true);
        Future.microtask(
          () => FocusScope.of(context).requestFocus(_focusEstado),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: BurbujaEstado(
              texto: estado.isEmpty ? 'escribe algo divertido' : estado,
              colorTexto: estado.isEmpty
                  ? ColoresApp.textoSecundario.withValues(alpha: 0.75)
                  : null,
              mostrarPuntosSiVacio: false,
              fontSize: 13,
              compacta: true,
              ajustarAnchoAlTexto: true,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 7),
          Icon(
            CupertinoIcons.pencil,
            size: 15,
            color: ColoresApp.principalMarca,
          ),
        ],
      ),
    );
  }

  // ── Avatar editable ──
  Widget _avatar(double size) {
    final marca = ColoresApp.principalMarca;
    return GestureDetector(
      onTap: _mostrarOpcionesFoto,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColoresApp.fondoSuperficie,
            ),
            clipBehavior: Clip.antiAlias,
            child: _imagenBytes != null
                ? Image.memory(_imagenBytes!, fit: BoxFit.cover)
                : Icon(
                    CupertinoIcons.person_fill,
                    size: size * 0.5,
                    color: ColoresApp.textoSecundario.withValues(alpha: 0.7),
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(shape: BoxShape.circle, color: marca),
              child: Icon(
                CupertinoIcons.camera_fill,
                size: size * 0.15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── "Elegí tu color" ──
  Widget _seccionTema() {
    final tema = TemaFernecito.instancia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Elegí tu color'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(TemaFernecito.colores.length, (i) {
            final color = TemaFernecito.colores[i];
            final sel = tema.indiceActual == i;
            return GestureDetector(
              onTap: () async {
                await tema.establecerIndice(i);
                if (mounted) setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: sel ? 40 : 34,
                height: sel ? 40 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: sel
                    ? const Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Helpers de layout ──
  Widget _label(String texto) {
    return Text(
      texto,
      style: GoogleFonts.baloo2(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ColoresApp.textoSecundario,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.fondoSuperficie.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }

  Widget _hairline() => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 48),
    color: Colors.white.withValues(alpha: 0.06),
  );

  // ── Campo de texto genérico (una fila dentro de la card) ──
  Widget _campoTexto({
    required TextEditingController controller,
    required String placeholder,
    required Widget icono,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: icono)),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              onChanged: onChanged,
              placeholderStyle: TextStyle(
                color: ColoresApp.textoSecundario,
                fontSize: 15,
              ),
              style: GoogleFonts.baloo2(
                fontSize: 15,
                color: ColoresApp.textoPrincipal,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Campo username con auto-validación inline ──
  Widget _campoUsername() {
    final marca = ColoresApp.principalMarca;
    Widget? trailing;
    if (_validandoUsername) {
      trailing = const FernecitoLoader.inline(size: 18);
    } else if (_usernameValidado) {
      trailing = Icon(
        _usernameDisponible
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.xmark_circle_fill,
        color: _usernameDisponible ? marca : ColoresApp.peligroMarca,
        size: 20,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(
                  child: Text(
                    '@',
                    style: GoogleFonts.baloo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: marca,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoTextField(
                  controller: _controladorUsername,
                  placeholder: 'username',
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: _onUsernameChanged,
                  placeholderStyle: TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 15,
                  ),
                  style: GoogleFonts.baloo2(
                    fontSize: 15,
                    color: ColoresApp.textoPrincipal,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          if (_usernameMsg != null)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 6),
              child: Text(
                _usernameMsg!,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _usernameDisponible ? marca : ColoresApp.peligroMarca,
                ),
              ),
            ),
        ],
      ),
    );
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

  // ── Fila de género (obligatoria) ──
  Widget _filaSexo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Para mejores recomendaciones',
            style: GoogleFonts.baloo2(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ColoresApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < SexoPerfil.opciones.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _chipSexo(SexoPerfil.opciones[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipSexo(String valor) {
    final sel = _sexoSeleccionado == valor;
    final marca = ColoresApp.principalMarca;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _sexoSeleccionado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? marca.withValues(alpha: 0.18) : ColoresApp.fondoPrincipal,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? marca : ColoresApp.textoSecundario.withValues(alpha: 0.22),
            width: sel ? 1.6 : 1,
          ),
        ),
        child: Text(
          SexoPerfil.etiqueta(valor),
          style: GoogleFonts.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: sel ? marca : ColoresApp.textoPrincipal,
          ),
        ),
      ),
    );
  }

  // ── Fila de cumpleaños (obligatoria) ──
  Widget _filaEdad() {
    final fecha = _fechaNacimientoSeleccionada;
    final puesta = fecha != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _abrirSelectorEdad,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.cakeCandles,
                  size: 16,
                  color: ColoresApp.principalMarca,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                puesta
                    ? '${_fechaCumpleTexto(fecha)} · ${_edadDesdeFecha(fecha)} años'
                    : '¿Cuándo es tu cumple?',
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: puesta ? FontWeight.w700 : FontWeight.w500,
                  color: puesta
                      ? ColoresApp.textoPrincipal
                      : ColoresApp.textoSecundario,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: ColoresApp.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSelectorEdad() {
    final hoy = DateTime.now();
    final maxDate = DateTime(hoy.year - 13, hoy.month, hoy.day);
    final minDate = DateTime(1920, 1, 1);
    var seleccion =
        _fechaNacimientoSeleccionada ??
        DateTime(hoy.year - 18, hoy.month, hoy.day);
    if (seleccion.isAfter(maxDate)) seleccion = maxDate;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
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
                  onPressed: () {
                    setState(() => _fechaNacimientoSeleccionada = seleccion);
                    Navigator.pop(ctx);
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
}
