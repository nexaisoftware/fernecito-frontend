library;

import '../core/supabase_client.dart';

class LocalTendenciaSocial {
  const LocalTendenciaSocial({
    required this.idLocal,
    required this.nombre,
    required this.score,
    this.fotoPath,
    this.ciudad,
    this.provincia,
    this.reservas = 0,
    this.visitas = 0,
    this.clicks = 0,
    this.resenas = 0,
    this.megusta = 0,
    this.vistasFlyers = 0,
    this.flyersActivos = 0,
    this.puntosBase = 0,
    this.puntosSemana = 0,
  });

  final String idLocal;
  final String nombre;
  final String? fotoPath;
  final String? ciudad;
  final String? provincia;
  final int score;
  final int reservas;
  final int visitas;
  final int clicks;
  final int resenas;
  final int megusta;
  final int vistasFlyers;
  final int flyersActivos;
  final int puntosBase;
  final int puntosSemana;

  String? get fotoUrl => ServicioSupabase().urlAvatar(fotoPath);

  factory LocalTendenciaSocial.fromMap(Map<String, dynamic> map) {
    int entero(dynamic value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    return LocalTendenciaSocial(
      idLocal: map['id_local']?.toString() ?? '',
      nombre: map['nombre_local']?.toString().trim().isNotEmpty == true
          ? map['nombre_local'].toString().trim()
          : 'Local',
      fotoPath: map['foto_perfil_url']?.toString(),
      ciudad: map['ciudad']?.toString(),
      provincia: map['provincia']?.toString(),
      score: entero(map['score']),
      reservas: entero(map['reservas']),
      visitas: entero(map['visitas']),
      clicks: entero(map['clicks']),
      resenas: entero(map['resenas']),
      megusta: entero(map['megusta']),
      vistasFlyers: entero(map['vistas_flyers']),
      flyersActivos: entero(map['flyers_activos']),
      puntosBase: entero(map['puntos_base']),
      puntosSemana: entero(map['puntos_semana']),
    );
  }
}
