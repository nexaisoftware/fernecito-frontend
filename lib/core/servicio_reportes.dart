import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class MotivoReporte {
  const MotivoReporte(this.codigo, this.label);
  final String codigo;
  final String label;
}

const motivosReporteCuenta = <MotivoReporte>[
  MotivoReporte('contenido_inapropiado', 'Contenido inapropiado'),
  MotivoReporte('acoso', 'Acoso o maltrato'),
  MotivoReporte('violencia_amenazas', 'Violencia o amenazas'),
  MotivoReporte('spam_estafa', 'Spam, estafa o fraude'),
  MotivoReporte('suplantacion', 'Suplantacion de identidad'),
  MotivoReporte('discriminacion_odio', 'Discriminacion u odio'),
  MotivoReporte('desnudez_sexual', 'Desnudez o contenido sexual'),
  MotivoReporte('menor_riesgo', 'Riesgo para menores'),
  MotivoReporte('informacion_falsa', 'Informacion falsa'),
  MotivoReporte('otro', 'Otro'),
];

class ServicioReportes {
  SupabaseClient get _sb => ServicioSupabase().cliente;

  Future<Map<String, dynamic>> reportarCuenta({
    required String reportanteTipo,
    required String targetTipo,
    required String targetId,
    required String motivo,
  }) async {
    final res = await _sb.functions.invoke(
      'reportar_cuenta',
      body: {
        'reportante_tipo': reportanteTipo,
        'target_tipo': targetTipo,
        'target_id': targetId,
        'motivo': motivo,
      },
    );
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return {'ok': false, 'error': 'Respuesta invalida'};
  }
}
