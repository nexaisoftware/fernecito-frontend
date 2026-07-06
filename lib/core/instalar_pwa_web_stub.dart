/// Stub: instalación PWA solo en web.
class InstalarPwaWeb {
  InstalarPwaWeb._();
  static final InstalarPwaWeb instancia = InstalarPwaWeb._();

  bool get soportado => false;
  bool get yaInstalada => false;
  bool get instalacionDisponible => false;

  void configurar() {}

  void alDisponible(void Function() callback) {}

  void alInstalada(void Function() callback) {}

  Future<bool> solicitarInstalacion() async => false;
}
