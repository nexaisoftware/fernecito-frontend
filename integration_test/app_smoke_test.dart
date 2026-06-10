import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fernecito_frontend/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fernecito Usuarios - Smoke Tests', () {
    testWidgets('La app de usuarios arranca correctamente', (tester) async {
      app.main();
      await tester.pump();

      // main() es async (dotenv + Supabase); avanzamos frames sin pumpAndSettle
      // (animaciones del skeleton pueden impedir que "settle" termine).
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final supabaseOk = find.byType(CupertinoApp).evaluate().isNotEmpty;
      final errorConfig =
          find.text('Error de configuración').evaluate().isNotEmpty;

      expect(
        supabaseOk || errorConfig,
        isTrue,
        reason:
            'Con .env válido debe aparecer CupertinoApp; sin Supabase, pantalla de error.',
      );
    });
  });
}
