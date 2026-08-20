library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Cantidad de mensajes por página en chats (inicial y "cargar más").
const int kChatMensajesPorPagina = 100;

typedef PaginaChatMensajes<T> = ({List<T> items, bool hayMas});

/// Convierte un batch DESC (más recientes primero) en lista ASC + flag hayMas.
PaginaChatMensajes<T> armarPaginaAsc<T>(List<T> desc, int limite) {
  final hayMas = desc.length > limite;
  final tomados = hayMas ? desc.sublist(0, limite) : desc;
  return (items: tomados.reversed.toList(), hayMas: hayMas);
}

/// Mantiene la vista al mismo mensaje visible tras prepend arriba.
void scrollTrasPrepend(
  ScrollController scroll,
  double prevMax,
  double prevOffset,
) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (!scroll.hasClients) return;
    scroll.jumpTo(prevOffset + (scroll.position.maxScrollExtent - prevMax));
  });
}
