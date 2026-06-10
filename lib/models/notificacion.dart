library;

import 'package:flutter/cupertino.dart';

/// Notificación in-app del usuario (tabla `notificaciones_usuarios`).
/// Espejo del modelo de la app de locales, adaptado al esquema de usuarios.
class Notificacion {
  final String id;
  final String idUsuario;
  final String tipo;
  final String prioridad; // 'alta' | 'media' | 'baja'
  final String titulo;
  final String descripcion;
  final String? iconoKey;
  final String? ctaTexto;
  final String? ctaRuta;
  final String? ctaIdRef;
  final Map<String, dynamic>? payload;
  final bool leida;
  final DateTime fechaCreacion;
  final DateTime? fechaLectura;

  const Notificacion({
    required this.id,
    required this.idUsuario,
    required this.tipo,
    required this.prioridad,
    required this.titulo,
    required this.descripcion,
    this.iconoKey,
    this.ctaTexto,
    this.ctaRuta,
    this.ctaIdRef,
    this.payload,
    required this.leida,
    required this.fechaCreacion,
    this.fechaLectura,
  });

  factory Notificacion.fromMap(Map<String, dynamic> m) {
    return Notificacion(
      id: m['id'].toString(),
      idUsuario: m['id_usuario'].toString(),
      tipo: (m['tipo'] as String?) ?? '',
      prioridad: (m['prioridad'] as String?) ?? 'media',
      titulo: (m['titulo'] as String?) ?? '',
      descripcion: (m['descripcion'] as String?) ?? '',
      iconoKey: m['icono_key'] as String?,
      ctaTexto: m['cta_texto'] as String?,
      ctaRuta: m['cta_ruta'] as String?,
      ctaIdRef: m['cta_id_ref']?.toString(),
      payload: m['payload'] is Map
          ? Map<String, dynamic>.from(m['payload'] as Map)
          : null,
      leida: m['leida'] == true,
      fechaCreacion: DateTime.tryParse(m['fecha_creacion']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      fechaLectura: m['fecha_lectura'] != null
          ? DateTime.tryParse(m['fecha_lectura'].toString())?.toUtc()
          : null,
    );
  }

  /// Mapea `icono_key` (string del backend) → IconData de Cupertino.
  /// Incluye iconos para tipos actuales y "cables sueltos" futuros
  /// (amistad / squad), para no tener que tocar esto al conectarlos.
  IconData get icono {
    switch (iconoKey) {
      // Listas / pases / eventos
      case 'checkmark_circle_fill':
        return CupertinoIcons.checkmark_circle_fill;
      case 'xmark_circle_fill':
        return CupertinoIcons.xmark_circle_fill;
      case 'ticket_fill':
        return CupertinoIcons.ticket_fill;
      case 'qrcode':
        return CupertinoIcons.qrcode;
      case 'tag_fill':
        return CupertinoIcons.tag_fill;
      case 'clock_fill':
        return CupertinoIcons.clock_fill;
      // Cuenta
      case 'exclamationmark_triangle_fill':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'checkmark_seal_fill':
        return CupertinoIcons.checkmark_seal_fill;
      // Futuro: social / squads
      case 'person_badge_plus_fill':
      case 'person_add_solid':
        return CupertinoIcons.person_add_solid;
      case 'person_2_fill':
        return CupertinoIcons.person_2_fill;
      case 'person_3_fill':
        return CupertinoIcons.person_3_fill;
      case 'heart_fill':
        return CupertinoIcons.heart_fill;
      case 'star_fill':
        return CupertinoIcons.star_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  /// Fecha relativa amigable: "Ahora", "Hace 5 min", "Ayer", "DD/MM".
  String get fechaRelativa {
    final ahora = DateTime.now().toUtc();
    final diff = ahora.difference(fechaCreacion);
    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    final l = fechaCreacion.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}';
  }

  Notificacion copyWith({bool? leida, DateTime? fechaLectura}) {
    return Notificacion(
      id: id,
      idUsuario: idUsuario,
      tipo: tipo,
      prioridad: prioridad,
      titulo: titulo,
      descripcion: descripcion,
      iconoKey: iconoKey,
      ctaTexto: ctaTexto,
      ctaRuta: ctaRuta,
      ctaIdRef: ctaIdRef,
      payload: payload,
      leida: leida ?? this.leida,
      fechaCreacion: fechaCreacion,
      fechaLectura: fechaLectura ?? this.fechaLectura,
    );
  }
}
