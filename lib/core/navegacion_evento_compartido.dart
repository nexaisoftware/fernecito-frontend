/// Carga un evento por id y navega a [PantallaVerEvento].
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../PANTALLAS/pantalla_ver_evento.dart';
import 'supabase_client.dart';

Future<void> abrirEventoCompartidoPorId(BuildContext context, String idEvento) async {
  final id = idEvento.trim();
  if (id.isEmpty || !context.mounted) return;

  final evento = await _cargarMapaEvento(id);
  if (evento == null || !context.mounted) return;

  await Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => PantallaVerEvento(evento: evento),
    ),
  );
}

Future<Map<String, dynamic>?> _cargarMapaEvento(String idEvento) async {
  try {
    final sb = ServicioSupabase().cliente;
    final row = await sb
        .from('eventos')
        .select(
          'id_evento, titulo_evento, descripcion_evento, url_flyer, fecha_inicio, '
          'fecha_fin, jerarquia, tipo_evento, tiene_promo, cupo_lista_max, '
          'cupo_lista_usados, modo_lista, id_local, ciudad_evento, provincia_evento, '
          'estado_publicacion, '
          'perfiles_locales!eventos_id_local_fkey(nombre_local, foto_perfil_url, local_verificado)',
        )
        .eq('id_evento', idEvento)
        .maybeSingle();

    if (row == null) return null;
    final map = Map<String, dynamic>.from(row as Map);
    if (map['estado_publicacion']?.toString() != 'publicado') return null;

    final perfil = map['perfiles_locales'];
    Map<String, dynamic>? local;
    if (perfil is Map) local = Map<String, dynamic>.from(perfil);

    final cupoMax = map['cupo_lista_max'] as int?;
    final cupoUsados = (map['cupo_lista_usados'] as int?) ?? 0;
    final cuposLibres = cupoMax != null ? (cupoMax - cupoUsados) : null;

    String avatarLocal = '';
    final avatarPath = local?['foto_perfil_url']?.toString().trim() ?? '';
    if (avatarPath.isNotEmpty) {
      avatarLocal = sb.storage.from('avatars_locales').getPublicUrl(avatarPath);
    }

    return {
      'id': map['id_evento']?.toString() ?? idEvento,
      'id_evento': map['id_evento']?.toString() ?? idEvento,
      'titulo': map['titulo_evento'] ?? '',
      'descripcion': map['descripcion_evento'] ?? '',
      'flyer': map['url_flyer'] ?? '',
      'nombreLocal': local?['nombre_local']?.toString() ?? 'Local',
      'avatarLocal': avatarLocal,
      'idLocal': map['id_local']?.toString(),
      'localVerificado': local?['local_verificado'] == true,
      'jerarquia': map['jerarquia'] ?? 'gratis',
      'tipoEvento': (map['tipo_evento']?.toString() ?? 'otro').toLowerCase(),
      'tienePromo': map['tiene_promo'] == true,
      'cupoMax': cupoMax,
      'cuposLibres': cuposLibres,
      'cupoLimitado': cupoMax != null,
      'modoLista': map['modo_lista'] ?? 'auto',
      'fechaInicio': map['fecha_inicio'],
      'fechaFin': map['fecha_fin'],
      'ciudadEvento': map['ciudad_evento']?.toString(),
      'provinciaEvento': map['provincia_evento']?.toString(),
    };
  } catch (e) {
    debugPrint('⚠️ abrirEventoCompartidoPorId: $e');
    return null;
  }
}
