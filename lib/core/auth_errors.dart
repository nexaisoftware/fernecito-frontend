/// Helper para traducir errores de autenticación de Supabase
/// a mensajes claros con tono Fernecito.
///
/// Maneja tanto AuthException como errores genéricos,
/// sin prometer precisión imposible cuando Supabase es ambiguo.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class TraductorErroresAuth {
  /// Traduce errores de autenticación a mensajes user-friendly.
  ///
  /// Mensajes exactos sin chamuyo:
  /// - Credenciales incorrectas
  /// - Email no confirmado (con guía clara)
  /// - Demasiados intentos
  /// - Sin conexión
  /// - Errores genéricos claros
  static String traducir(dynamic error) {
    // Si es AuthException de Supabase
    if (error is AuthException) {
      return _traducirAuthException(error);
    }

    // Si es PostgrestException
    if (error is PostgrestException) {
      return _traducirPostgrestException(error);
    }

    // Si es String, analizarla
    if (error is String) {
      return _traducirStringError(error.toLowerCase());
    }

    // Error genérico
    final errorStr = error.toString().toLowerCase();
    return _traducirStringError(errorStr);
  }

  static String _traducirAuthException(AuthException error) {
    final message = error.message.toLowerCase();
    final statusCode = error.statusCode;

    print('🔍 AuthException: $message (status: $statusCode)');

    // Credenciales incorrectas
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials') ||
        message.contains('wrong password') ||
        message.contains('incorrect password')) {
      return 'Email o contraseña incorrectos.';
    }

    // Email no confirmado
    if (message.contains('email not confirmed') ||
        message.contains('confirm your email') ||
        message.contains('verification required') ||
        statusCode == '400' && message.contains('email')) {
      return 'Te falta confirmar tu email. 📩\n\n'
          'Revisá tu bandeja de entrada (y spam) y tocá el enlace de confirmación.\n\n'
          'Después volvé e iniciá sesión.';
    }

    // Usuario ya existe (signup)
    if (message.contains('user already registered') ||
        message.contains('already exists') ||
        message.contains('duplicate')) {
      return 'Ya existe una cuenta con ese email.\n\n'
          'Probá iniciar sesión o recuperá tu contraseña.';
    }

    // Email inválido
    if (message.contains('invalid email') ||
        message.contains('email format') ||
        message.contains('malformed email')) {
      return 'El formato del email no es válido.';
    }

    // Contraseña débil
    if (message.contains('password is too weak') ||
        message.contains('password should be at least') ||
        message.contains('weak password')) {
      return 'La contraseña es muy débil.\n\n'
          'Debe tener al menos 6 caracteres.';
    }

    // Demasiados intentos (rate limit) - muy común al pedir código varias veces
    if (message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('try again later') ||
        message.contains('email rate limit') ||
        statusCode == '429') {
      return 'Demasiados intentos.\n\n'
          'Esperá unos minutos y probá de nuevo.';
    }

    // Redirect URL no permitida (config en Supabase Dashboard)
    if (message.contains('redirect') && message.contains('url')) {
      return 'Error de configuración del enlace.\n\n'
          'Probá de nuevo en unos minutos.';
    }

    // Error interno típico al configurar SMTP custom en Supabase
    if (message.contains('unexpected_failure') ||
        message.contains('unexpected failure') ||
        message.contains('error sending email') ||
        message.contains('smtp') ||
        message.contains('mail provider')) {
      return 'No se pudo enviar el email de recuperación.\n\n'
          'Parece un problema de configuración del correo (SMTP). '
          'Revisá remitente, dominio y credenciales en Supabase.';
    }

    // Token inválido o expirado
    if (message.contains('invalid token') ||
        message.contains('expired') ||
        message.contains('jwt expired') ||
        message.contains('token has expired')) {
      return 'El enlace venció o es inválido.\n\n'
          'Solicitá uno nuevo.';
    }

    // Sin autorización
    if (message.contains('unauthorized') ||
        message.contains('not authorized') ||
        statusCode == '401') {
      return 'No tenés autorización para esta acción.';
    }

    // Usuario no encontrado
    if (message.contains('user not found') ||
        message.contains('no user found')) {
      return 'No encontramos una cuenta con ese email.';
    }

    // Error de OAuth
    if (message.contains('oauth') || message.contains('provider')) {
      return 'No se pudo conectar con el servicio.\n\n'
          'Probá de nuevo en unos segundos.';
    }

    // Error de red (por statusCode)
    if (statusCode == null || statusCode == '0' || statusCode == 'network') {
      return 'No hay conexión.\n\n'
          'Revisá tu internet y probá de nuevo.';
    }

    // Mensaje por defecto con el mensaje original si es claro
    if (message.isNotEmpty && message.length < 100) {
      return 'Error: $message';
    }

    return 'Ups… algo falló.\n\n'
        'Probá de nuevo en unos segundos.';
  }

  static String _traducirPostgrestException(PostgrestException error) {
    final message = error.message.toLowerCase();
    final code = error.code;

    print('🔍 PostgrestException: $message (code: $code)');

    // Username duplicado (unique constraint)
    if (code == '23505' ||
        message.contains('duplicate') ||
        message.contains('unique')) {
      if (message.contains('username')) {
        return 'Ese username ya está en uso.\n\n'
            'Elegí otro.';
      }
      if (message.contains('email')) {
        return 'Ya existe una cuenta con ese email.';
      }
      return 'Ese dato ya está en uso.\n\n'
          'Probá con otro.';
    }

    // Permisos insuficientes (RLS)
    if (code == '42501' ||
        code == 'PGRST301' ||
        message.contains('permission denied') ||
        message.contains('not allowed')) {
      return 'No tenés permisos para esta acción.';
    }

    // Registro no encontrado
    if (code == 'PGRST116' || message.contains('not found')) {
      return 'No encontramos ese registro.';
    }

    // Error de conexión
    if (message.contains('connection') || message.contains('network')) {
      return 'No hay conexión.\n\n'
          'Revisá tu internet y probá de nuevo.';
    }

    return 'Error en la base de datos.\n\n'
        'Probá de nuevo en unos segundos.';
  }

  static String _traducirStringError(String errorStr) {
    print('🔍 String error: $errorStr');

    // Errores de red comunes
    if (errorStr.contains('socket') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network') ||
        errorStr.contains('no route') ||
        errorStr.contains('host lookup failed') ||
        errorStr.contains('failed host lookup')) {
      return 'No hay conexión.\n\n'
          'Revisá tu internet y probá de nuevo.';
    }

    // Timeout
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'La conexión tardó mucho.\n\n'
          'Revisá tu internet y probá de nuevo.';
    }

    // Certificado SSL
    if (errorStr.contains('certificate') || errorStr.contains('ssl')) {
      return 'Error de seguridad en la conexión.\n\n'
          'Verificá que tu dispositivo tenga la hora correcta.';
    }

    // Error genérico corto
    if (errorStr.length < 100 && !errorStr.contains('exception')) {
      return 'Error: $errorStr';
    }

    return 'Ups… algo falló.\n\n'
        'Probá de nuevo en unos segundos.';
  }

  /// Mensajes específicos para signup (anti-enumeration)
  static String mensajeSignupExitoso(String email) {
    return '¡Cuenta creada! 🥃\n\n'
        'Te enviamos un email a $email.\n\n'
        'Abrí el enlace para confirmar tu cuenta y después iniciá sesión.';
  }

  static String mensajeSignupAmbiguo() {
    return 'Si el correo es nuevo, te va a llegar un email para confirmar.\n\n'
        'Si ya tenías cuenta, probá iniciar sesión o recuperá tu contraseña.';
  }

  /// Mensaje para recovery password
  static String mensajeRecoveryEnviado() {
    return 'Listo ✅\n\n'
        'Si el correo existe, te va a llegar un email para recuperar tu contraseña.';
  }

  /// Mensaje para reenvío de confirmación
  static String mensajeConfirmacionReenviada() {
    return 'Listo ✅\n\n'
        'Te reenviamos el email.\n\n'
        'Revisá inbox y spam.';
  }

  /// Mensaje para contraseña actualizada
  static String mensajePasswordActualizada() {
    return 'Contraseña actualizada ✅\n\n'
        'Ya podés entrar con tu nueva clave.';
  }
}
