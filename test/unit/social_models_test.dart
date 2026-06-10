// Tests para modelos del sistema social (social.dart).
// Nota: los getters avatarUrl / avataresResueltos / portadaUrl no se testean
// aquí porque dependen de Supabase.instance (requieren app inicializada).
// Esos getters se cubren en integration tests.
import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/social.dart';

void main() {
  group('MiembroSquad.fromMap', () {
    Map<String, dynamic> _map({String rol = 'miembro', bool perfilPublico = true}) => {
          'id_usuario': 'user-001',
          'username': 'testuser',
          'nombre': 'Test User',
          'foto_perfil_url': null,
          'rol_miembro': rol,
          'mi_estado': 'activo',
          'instagram_url': null,
          'tiktok_url': null,
          'perfil_publico': perfilPublico,
        };

    test('parsea campos básicos', () {
      final m = MiembroSquad.fromMap(_map());
      expect(m.idUsuario, 'user-001');
      expect(m.username, 'testuser');
      expect(m.nombre, 'Test User');
      expect(m.perfilPublico, isTrue);
    });

    test('rol default "miembro" si campo ausente', () {
      final map = _map()..remove('rol_miembro');
      expect(MiembroSquad.fromMap(map).rol, 'miembro');
    });

    test('esLider solo cuando rol == lider', () {
      expect(MiembroSquad.fromMap(_map(rol: 'lider')).esLider, isTrue);
      expect(MiembroSquad.fromMap(_map(rol: 'admin')).esLider, isFalse);
      expect(MiembroSquad.fromMap(_map(rol: 'miembro')).esLider, isFalse);
    });

    test('esAdmin para lider y admin, no para miembro', () {
      expect(MiembroSquad.fromMap(_map(rol: 'lider')).esAdmin, isTrue);
      expect(MiembroSquad.fromMap(_map(rol: 'admin')).esAdmin, isTrue);
      expect(MiembroSquad.fromMap(_map(rol: 'miembro')).esAdmin, isFalse);
    });
  });

  group('SquadExplorarItem.fromMap', () {
    Map<String, dynamic> _map({int cantidad = 0, List? avatares}) => {
          'id_grupo': 'squad-001',
          'nombre_grupo': 'Los Exploradores',
          'url_portada': null,
          'cantidad_miembros': cantidad,
          'mi_estado': 'ninguno',
          'avatares_miembros': avatares ?? [],
        };

    test('parsea campos básicos', () {
      final s = SquadExplorarItem.fromMap(_map(cantidad: 5));
      expect(s.idGrupo, 'squad-001');
      expect(s.nombre, 'Los Exploradores');
      expect(s.cantidadMiembros, 5);
      expect(s.miEstado, 'ninguno');
    });

    test('nombre fallback "Squad" si nombre_grupo es null', () {
      final map = _map()..['nombre_grupo'] = null;
      expect(SquadExplorarItem.fromMap(map).nombre, 'Squad');
    });

    test('miembrosExtra == 0 cuando cantidadMiembros <= 3', () {
      expect(SquadExplorarItem.fromMap(_map(cantidad: 0)).miembrosExtra, 0);
      expect(SquadExplorarItem.fromMap(_map(cantidad: 1)).miembrosExtra, 0);
      expect(SquadExplorarItem.fromMap(_map(cantidad: 3)).miembrosExtra, 0);
    });

    test('miembrosExtra == cantidad - 3 cuando > 3', () {
      expect(SquadExplorarItem.fromMap(_map(cantidad: 4)).miembrosExtra, 1);
      expect(SquadExplorarItem.fromMap(_map(cantidad: 10)).miembrosExtra, 7);
      expect(SquadExplorarItem.fromMap(_map(cantidad: 100)).miembrosExtra, 97);
    });

    test('fotosMiembros vacío si avatares_miembros no es List', () {
      final map = _map()..['avatares_miembros'] = null;
      expect(SquadExplorarItem.fromMap(map).fotosMiembros, isEmpty);
    });
  });

  group('SquadResumen.fromMap', () {
    test('parsea soyLider y esPublico', () {
      final map = {
        'id_grupo': 'sq-1',
        'nombre_grupo': 'Mi Squad',
        'soy_lider': true,
        'es_publico': false,
        'cantidad_miembros': 3,
      };
      final s = SquadResumen.fromMap(map);
      expect(s.soyLider, isTrue);
      expect(s.esPublico, isFalse);
      expect(s.cantidadMiembros, 3);
    });

    test('soyLider false por defecto si campo ausente', () {
      expect(SquadResumen.fromMap({'id_grupo': 'x', 'nombre_grupo': 'X'}).soyLider, isFalse);
    });

    test('cantidadMiembros 0 por defecto si campo ausente', () {
      expect(SquadResumen.fromMap({'id_grupo': 'x', 'nombre_grupo': 'X'}).cantidadMiembros, 0);
    });
  });

  group('SquadBusqueda.fromMap', () {
    test('miEstado default "ninguno" si campo ausente', () {
      final map = {
        'id_grupo': 'sq-3',
        'nombre_grupo': 'Búsqueda Squad',
        'es_publico': true,
        'cantidad_miembros': 2,
      };
      expect(SquadBusqueda.fromMap(map).miEstado, 'ninguno');
    });

    test('parsea esPublico correctamente', () {
      final mapPublico = {
        'id_grupo': 'sq-4',
        'nombre_grupo': 'Squad Público',
        'es_publico': true,
      };
      final mapPrivado = {
        'id_grupo': 'sq-5',
        'nombre_grupo': 'Squad Privado',
        'es_publico': false,
      };
      expect(SquadBusqueda.fromMap(mapPublico).esPublico, isTrue);
      expect(SquadBusqueda.fromMap(mapPrivado).esPublico, isFalse);
    });
  });

  group('SquadDetalle.fromMap', () {
    test('parsea lista de miembros embebidos', () {
      final map = {
        'id_grupo': 'sq-detalle-1',
        'nombre_grupo': 'Squad Detalle',
        'es_publico': true,
        'soy_lider': false,
        'mi_estado': 'aceptado',
        'miembros': [
          {
            'id_usuario': 'u10',
            'username': 'miembro10',
            'nombre': 'Miembro Diez',
            'rol_miembro': 'admin',
            'perfil_publico': false,
          }
        ],
      };
      final d = SquadDetalle.fromMap(map);
      expect(d.miembros.length, 1);
      expect(d.miembros.first.esAdmin, isTrue);
      expect(d.miEstado, 'aceptado');
      expect(d.soyLider, isFalse);
    });

    test('miembros vacío si campo miembros ausente', () {
      final map = {'id_grupo': 'sq-2', 'nombre_grupo': 'Sin miembros', 'es_publico': false};
      expect(SquadDetalle.fromMap(map).miembros, isEmpty);
    });

    test('miEstado default "ninguno" si campo ausente', () {
      final map = {'id_grupo': 'sq-3', 'nombre_grupo': 'Default', 'es_publico': false};
      expect(SquadDetalle.fromMap(map).miEstado, 'ninguno');
    });
  });

  group('AmistadesData.fromMap', () {
    test('parsea amigos, recibidas y enviadas', () {
      final data = AmistadesData.fromMap({
        'amigos': [
          {'id_usuario': 'u1', 'username': 'amigo1', 'nombre': 'Amigo Uno'}
        ],
        'recibidas': [],
        'enviadas': [
          {'id_usuario': 'u2', 'username': 'pendiente1', 'nombre': 'Solicitud'}
        ],
      });
      expect(data.amigos.length, 1);
      expect(data.amigos.first.username, 'amigo1');
      expect(data.recibidas, isEmpty);
      expect(data.enviadas.length, 1);
    });

    test('listas vacías si campos ausentes', () {
      final data = AmistadesData.fromMap({});
      expect(data.amigos, isEmpty);
      expect(data.recibidas, isEmpty);
      expect(data.enviadas, isEmpty);
    });

    test('listas vacías si campos no son List', () {
      final data = AmistadesData.fromMap({
        'amigos': 'no-una-lista',
        'recibidas': 42,
        'enviadas': null,
      });
      expect(data.amigos, isEmpty);
      expect(data.recibidas, isEmpty);
      expect(data.enviadas, isEmpty);
    });
  });

  group('Amigo.fromMap', () {
    test('parsea campos básicos', () {
      final a = Amigo.fromMap({
        'id_usuario': 'u-amigo',
        'username': 'amigo_user',
        'nombre': 'Nombre Amigo',
        'mi_estado': 'activo',
      });
      expect(a.idUsuario, 'u-amigo');
      expect(a.username, 'amigo_user');
      expect(a.nombre, 'Nombre Amigo');
    });

    test('username vacío si campo null', () {
      final a = Amigo.fromMap({'id_usuario': 'u1', 'username': null, 'nombre': null});
      expect(a.username, '');
      expect(a.nombre, '');
    });
  });

  group('UsuarioBusqueda.fromMap', () {
    test('estadoAmistad default "ninguno" si campo ausente', () {
      final u = UsuarioBusqueda.fromMap({
        'id_usuario': 'u-busqueda',
        'username': 'busqueda_user',
        'nombre': 'User Búsqueda',
      });
      expect(u.estadoAmistad, 'ninguno');
      expect(u.perfilPublico, isFalse);
    });

    test('perfilPublico true si campo es true', () {
      final u = UsuarioBusqueda.fromMap({
        'id_usuario': 'u2',
        'username': 'pub_user',
        'nombre': 'User Público',
        'perfil_publico': true,
        'estado_amistad': 'amigo',
      });
      expect(u.perfilPublico, isTrue);
      expect(u.estadoAmistad, 'amigo');
    });
  });
}
