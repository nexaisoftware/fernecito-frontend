library;

class TramoHorarioLocal {
  const TramoHorarioLocal({required this.abre, required this.cierra});

  final String abre;
  final String cierra;

  Map<String, dynamic> toJson() => {'abre': abre, 'cierra': cierra};

  static TramoHorarioLocal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final abre = raw['abre']?.toString().trim() ?? '';
    final cierra = raw['cierra']?.toString().trim() ?? '';
    if (!_horaValida(abre) || !_horaValida(cierra)) return null;
    return TramoHorarioLocal(abre: abre, cierra: cierra);
  }
}

class EstadoHorarioLocal {
  const EstadoHorarioLocal({
    required this.tieneHorarios,
    required this.abierto,
    required this.titulo,
    required this.detalle,
  });

  final bool tieneHorarios;
  final bool abierto;
  final String titulo;
  final String detalle;
}

typedef HorariosLocal = Map<int, List<TramoHorarioLocal>>;

const nombresDiasHorarios = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

HorariosLocal parseHorariosLocal(Object? raw) {
  final out = <int, List<TramoHorarioLocal>>{};
  if (raw is! Map) return out;
  for (var dia = 0; dia < 7; dia++) {
    final value = raw['$dia'];
    if (value is! List) continue;
    final tramos = value
        .map(TramoHorarioLocal.fromJson)
        .whereType<TramoHorarioLocal>()
        .toList();
    if (tramos.isNotEmpty) out[dia] = tramos;
  }
  return out;
}

Map<String, dynamic> horariosLocalToJson(HorariosLocal horarios) {
  final out = <String, dynamic>{};
  for (var dia = 0; dia < 7; dia++) {
    final tramos = horarios[dia] ?? const <TramoHorarioLocal>[];
    if (tramos.isNotEmpty) {
      out['$dia'] = tramos.map((t) => t.toJson()).toList();
    }
  }
  return out;
}

EstadoHorarioLocal estadoHorarioLocal(
  HorariosLocal horarios, {
  DateTime? ahora,
}) {
  final now = ahora ?? DateTime.now();
  if (horarios.values.every((tramos) => tramos.isEmpty)) {
    return const EstadoHorarioLocal(
      tieneHorarios: false,
      abierto: false,
      titulo: 'Horarios no cargados',
      detalle: 'Este local todavía no informó sus horarios.',
    );
  }

  final minutoActual = now.hour * 60 + now.minute;
  final diaHoy = now.weekday - 1;
  final diaAyer = (diaHoy + 6) % 7;

  for (final tramo in horarios[diaHoy] ?? const <TramoHorarioLocal>[]) {
    final abre = _minutos(tramo.abre);
    final cierra = _minutos(tramo.cierra);
    if (abre == null || cierra == null) continue;
    if (abre == cierra) {
      return const EstadoHorarioLocal(
        tieneHorarios: true,
        abierto: true,
        titulo: 'Abierto ahora',
        detalle: 'Abierto las 24 hs',
      );
    }
    if (abre < cierra && minutoActual >= abre && minutoActual < cierra) {
      return EstadoHorarioLocal(
        tieneHorarios: true,
        abierto: true,
        titulo: 'Abierto ahora',
        detalle: 'Cierra a las ${tramo.cierra}',
      );
    }
    if (abre > cierra && minutoActual >= abre) {
      return EstadoHorarioLocal(
        tieneHorarios: true,
        abierto: true,
        titulo: 'Abierto ahora',
        detalle: 'Cierra a las ${tramo.cierra}',
      );
    }
  }

  for (final tramo in horarios[diaAyer] ?? const <TramoHorarioLocal>[]) {
    final abre = _minutos(tramo.abre);
    final cierra = _minutos(tramo.cierra);
    if (abre == null || cierra == null || abre <= cierra) continue;
    if (minutoActual < cierra) {
      return EstadoHorarioLocal(
        tieneHorarios: true,
        abierto: true,
        titulo: 'Abierto ahora',
        detalle: 'Cierra a las ${tramo.cierra}',
      );
    }
  }

  final proximo = _proximaApertura(horarios, now);
  if (proximo == null) {
    return const EstadoHorarioLocal(
      tieneHorarios: true,
      abierto: false,
      titulo: 'Cerrado',
      detalle: 'Sin próximas aperturas cargadas.',
    );
  }
  final (diasHasta, dia, tramo) = proximo;
  final cuando = diasHasta == 0
      ? 'hoy'
      : diasHasta == 1
      ? 'mañana'
      : nombresDiasHorarios[dia].toLowerCase();
  return EstadoHorarioLocal(
    tieneHorarios: true,
    abierto: false,
    titulo: 'Cerrado',
    detalle: 'Abre $cuando a las ${tramo.abre}',
  );
}

String resumenHorariosDia(List<TramoHorarioLocal> tramos) {
  if (tramos.isEmpty) return 'Cerrado';
  return tramos.map((t) => '${t.abre} - ${t.cierra}').join(' / ');
}

bool _horaValida(String h) =>
    RegExp(r'^\d{2}:\d{2}$').hasMatch(h) && _minutos(h) != null;

int? _minutos(String h) {
  final parts = h.split(':');
  if (parts.length != 2) return null;
  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);
  if (hh == null || mm == null || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
    return null;
  }
  return hh * 60 + mm;
}

(int, int, TramoHorarioLocal)? _proximaApertura(
  HorariosLocal horarios,
  DateTime now,
) {
  final minutoActual = now.hour * 60 + now.minute;
  final diaHoy = now.weekday - 1;
  for (var offset = 0; offset < 7; offset++) {
    final dia = (diaHoy + offset) % 7;
    final tramos = [...(horarios[dia] ?? const <TramoHorarioLocal>[])];
    tramos.sort(
      (a, b) => (_minutos(a.abre) ?? 0).compareTo(_minutos(b.abre) ?? 0),
    );
    for (final tramo in tramos) {
      final abre = _minutos(tramo.abre);
      if (abre == null) continue;
      if (offset == 0 && abre <= minutoActual) continue;
      return (offset, dia, tramo);
    }
  }
  return null;
}
