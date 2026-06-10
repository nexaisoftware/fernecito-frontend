// Crítico: estos códigos son los que la DB manda cuando una cuenta es suspendida.
// Si la función no los reconoce, el usuario ve un mensaje genérico en vez del motivo real.
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/motivos_pausa_cuenta.dart';

void main() {
  group('motivosPausaPublicos — lista completa', () {
    test('hay exactamente 8 motivos definidos', () {
      expect(motivosPausaPublicos.length, 8);
    });

    test('ningún código está duplicado', () {
      final codigos = motivosPausaPublicos.map((m) => m.codigo).toSet();
      expect(codigos.length, motivosPausaPublicos.length);
    });

    test('todas las etiquetas son no vacías', () {
      for (final m in motivosPausaPublicos) {
        expect(m.etiqueta, isNotEmpty, reason: 'código "${m.codigo}" sin etiqueta');
      }
    });
  });

  group('etiquetaMotivoPublico — códigos conocidos', () {
    final casosEsperados = {
      'infringe_politicas': 'Infringe nuestras políticas de uso',
      'uso_indebido': 'Uso indebido de la aplicación',
      'adulteracion_plataforma': 'Intento de adulteración de la plataforma',
      'movimientos_sospechosos': 'Movimientos sospechosos detectados',
      'sesion_no_autorizada': 'Inicio de sesión no autorizado',
      'verificacion_pendiente': 'Verificación de identidad pendiente',
      'incumplimiento_pagos': 'Incumplimiento en pagos o suscripción',
      'reportes_usuarios': 'Reportes reiterados de otros usuarios',
    };

    for (final entry in casosEsperados.entries) {
      test('código "${entry.key}" → etiqueta correcta', () {
        expect(etiquetaMotivoPublico(entry.key), entry.value);
      });
    }
  });

  group('etiquetaMotivoPublico — fallbacks', () {
    const fallback = 'Tu cuenta fue suspendida por el equipo de Fernecito';

    test('null → mensaje fallback', () {
      expect(etiquetaMotivoPublico(null), fallback);
    });

    test('string vacío → mensaje fallback', () {
      expect(etiquetaMotivoPublico(''), fallback);
    });

    test('string solo espacios → mensaje fallback', () {
      expect(etiquetaMotivoPublico('   '), fallback);
    });

    test('código desconocido → mensaje fallback', () {
      expect(etiquetaMotivoPublico('codigo_inexistente'), fallback);
    });

    test('código con mayúsculas (no coincide) → mensaje fallback', () {
      // La función es case-sensitive — aseguramos que no haga match incorrecto
      expect(etiquetaMotivoPublico('INFRINGE_POLITICAS'), fallback);
    });
  });
}
