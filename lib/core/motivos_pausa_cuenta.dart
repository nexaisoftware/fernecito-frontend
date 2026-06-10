/// Códigos de motivo público (visibles al usuario suspendido).
library;

class MotivoPausaCuenta {
  final String codigo;
  final String etiqueta;

  const MotivoPausaCuenta(this.codigo, this.etiqueta);
}

const List<MotivoPausaCuenta> motivosPausaPublicos = [
  MotivoPausaCuenta('infringe_politicas', 'Infringe nuestras políticas de uso'),
  MotivoPausaCuenta('uso_indebido', 'Uso indebido de la aplicación'),
  MotivoPausaCuenta('adulteracion_plataforma', 'Intento de adulteración de la plataforma'),
  MotivoPausaCuenta('movimientos_sospechosos', 'Movimientos sospechosos detectados'),
  MotivoPausaCuenta('sesion_no_autorizada', 'Inicio de sesión no autorizado'),
  MotivoPausaCuenta('verificacion_pendiente', 'Verificación de identidad pendiente'),
  MotivoPausaCuenta('incumplimiento_pagos', 'Incumplimiento en pagos o suscripción'),
  MotivoPausaCuenta('reportes_usuarios', 'Reportes reiterados de otros usuarios'),
];

String etiquetaMotivoPublico(String? codigo) {
  if (codigo == null || codigo.trim().isEmpty) {
    return 'Tu cuenta fue suspendida por el equipo de Fernecito';
  }
  for (final m in motivosPausaPublicos) {
    if (m.codigo == codigo) return m.etiqueta;
  }
  return 'Tu cuenta fue suspendida por el equipo de Fernecito';
}
